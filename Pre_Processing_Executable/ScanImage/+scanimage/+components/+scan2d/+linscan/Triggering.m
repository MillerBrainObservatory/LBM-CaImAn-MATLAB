classdef Triggering < scanimage.interfaces.Class
    
    properties (Hidden, SetAccess = immutable)
        hLinScan;                             % handle of Scan2D, handle gracefully if empty
        enabled = false;                        % true if auxialiary DAQ device is specified
    end
    
    properties (SetAccess = private)
        hRouteRegistry;                         % Handle to DAQmx route registry
        
        hSampleClockAcq;                        % handle to counter task that generates the Acq sample clock
        hSampleClockAcqChan;                    % handle to counter channel in hSampleClockAcq
        sampleClockAcqTermInt;                  % internal output terminal of the acquisition sample clock task
       
        hFrameClock;                            % handle to counter task that generates the frame clock
        hFrameClockChan;                        % handle to counter channel in hFrameClockChan
        frameClockTermInt;                      % internal output terminal of the frame clock task
        
        hRefClock;                            % handle to counter task that generates the frame clock
        
        referenceClockTermInt;                  % internal output terminal of the reference clock
        referenceClockRateInt;                  % this reference is only to be used for tasks on the aux board!!
        
        referenceClockTermExt;                  % external output terminal of the reference clock
        referenceClockRateExt;                  % this reference is <= 10MHz so can be routed between boards

        hDITriggerTimes;                        % digital input task that continuously samples the trigger inputs to generate timestamps
        
        triggerTimes = [NaN NaN NaN];           % received start trigger time stamps [start stop next]
        triggerTimesDetected = [false false false]  % indicates if the triggers were detected since the last call of obj.readTriggerTimes() [start stop next]
        triggerTimesLastReadSamples;            % time of last trigger times read
        triggerTimesProcessingNow = false;      % protectes the 'critical section' in obj.updateTriggerTimes()
        
        triggerPolaritiesPropertyNames;         % cell array of property name for each channel in hDITriggerTimes, that holds trigger polarity in hLinScan
        triggerPolarities;                      % cell array of {'rising','falling'} edge polarity for each channel in hDITriggerTimes
        
        active = false;
    end
    
    properties
        sampleClkAcqStartTrigEdge = 'rising';   % edge polarity of the start trigger. one of {'rising','falling'}
    end
    
    properties (Dependent)
        sampleClkAcqTermOut;                    % output terminal for the Acq sample clock
        sampleClkAcqStartTrigIn;                % input terminal for the Acq sample clock start trigger
        sampleClkAcqFreq;                       % frequency for the Acq sample Clock
    end
    
    properties (Constant)
        SAMPLE_CLOCK_ACQ_CTR = 0;               % Counter channel to be used to generate the acquisition sample clock
        FRAME_CLOCK_CTR_CHAN = 1;               % Counter channel to be used to generate the frame clock
        REF_CLOCK_CTR_CHAN = 2;               % Counter channel to be used to generate the frame clock
        
        SAMPLE_CLOCK_TERM_OUT = '';
        FRAME_CLOCK_TERM_OUT  = 'PFI10';
        REFERENCE_CLOCK_TERM_OUT = 'PFI14';
        REFERENCE_CLOCK_RATE  = 10e6;
        
        TRIG_LINE_START = 'port0/line0';
        TRIG_LINE_STOP  = 'port0/line1';
        TRIG_LINE_NEXT  = 'port0/line2';
        TRIGGER_TIMES_SAMPLE_RATE = 100e3;      % [Hz] sample rate for the triggers
        TRIGGER_TIMES_EVERY_N_SAMPLES = 100e3;  % auto execute callback to ensure no buffer overflow can occur
        TRIGGER_TIMES_BUFFER_SIZE = 10;         % buffer size measured in units of everyNSample Callback samples
    end
    
    %% Lifecycle
    methods
        function obj = Triggering(hLinScan)
            obj.hLinScan = hLinScan;
            obj.hRouteRegistry = dabs.ni.daqmx.util.triggerRouteRegistry();
            
            if isempty(obj.hLinScan.mdfData.deviceNameAux)
                obj.enabled = false;
                disp('No Auxiliary board specified. Disabling auxiliary board functionality');
            else
                obj.enabled = true;
                obj.ziniCheckDaqDeviceType();
                obj.ziniPrepareTasks();
                
                %clear routes because this may not actually be the active imaging system
                obj.hRouteRegistry.deinitRoutes();
            end
        end
        
        function delete(obj)
            % delete Tasks
            obj.zprvClearTask('hSampleClockAcq');
            obj.zprvClearTask('hFrameClock');
            obj.zprvClearTask('hRefClock');
            obj.zprvClearTask('hDITriggerTimes');
            most.idioms.safeDeleteObj(obj.hRouteRegistry);
        end
    end
    
    methods
        function start(obj)
            if ~obj.enabled; return; end
            obj.assertNotActive('start');
            
            obj.configureFrameClock();
            obj.hFrameClock.start();
            obj.hSampleClockAcq.start();
            
            obj.active = true;
        end
        
        function restart(obj)
            if ~obj.enabled; return; end
            obj.abort();
           
            obj.hFrameClock.start();
            obj.hSampleClockAcq.start();
            
            obj.active = true;
        end
        
        function abort(obj)
            if ~obj.enabled; return; end
            
            obj.zprvSaveAbortTask('hFrameClock');
            obj.zprvSaveAbortTask('hSampleClockAcq');
            
            obj.active = false;
        end
        
        function startTiming(obj)
            if ~obj.enabled; return; end
            obj.hDITriggerTimes.abort();
            
            obj.triggerTimes = [0 NaN NaN];
            obj.triggerTimesDetected = [true false false];
            obj.triggerTimesLastReadSamples = 0;
            
            numDigitalChan = numel(obj.triggerPolaritiesPropertyNames);
            obj.triggerPolarities = cell(1,numDigitalChan);
            for i = 1:numel(obj.triggerPolaritiesPropertyNames)
                propName = obj.triggerPolaritiesPropertyNames{i};       % get propName for channel e.g. 'trigAcqEdge'
                obj.triggerPolarities{i} = obj.hLinScan.(propName);   % get polarity for channel ('rising'/'falling')
            end
            
            obj.hDITriggerTimes.start();
        end
        
        function abortTiming(obj)
            if ~obj.enabled; return; end
            obj.zprvSaveAbortTask('hDITriggerTimes');
        end
        
        function triggerTimes_ = readTriggerTimes(obj)
            % returns an array of timestamps (in seconds)
            % for [starTrigger stopTrigger nextTrigger]
            % if a trigger was detected, the value for the appropriate
            % array element is set to the time passed since hDITriggerTimes
            % was initially triggerd.
            % arrayelements for triggers that were not detected are set to NaN            
            triggerTimes_ = struct('start',NaN,'stop',NaN,'next',NaN);
            if ~obj.enabled
                return
            end
            
            triggerTimesArray = obj.updateTriggerTimes(true,false);
            triggerTimes_.start = triggerTimesArray(1);
            triggerTimes_.stop = triggerTimesArray(2);
            triggerTimes_.next = triggerTimesArray(3);
        end
    end
    
    %% Private methods
    methods (Hidden)    
        function ziniCheckDaqDeviceType(obj)
            hDaq = dabs.ni.daqmx.Device(obj.hLinScan.mdfData.deviceNameAux);
            if strcmp(hDaq.productCategory,'DAQmx_Val_AOSeries')
                most.idioms.warn('Support for PXIe-6738/6739 is experimental. Some features may not work.');
            else
                assert(strcmp(hDaq.productCategory,'DAQmx_Val_XSeriesDAQ'),...
                    'Auxiliary DAQ device must be a X-Series board. Current board: %s',hDaq.productCategory);
            end
        end
        
        function ziniPrepareTasks(obj)
            import dabs.ni.daqmx.*;            
            
            % set up acquisition sample clock task
            obj.hSampleClockAcq = most.util.safeCreateTask([obj.hLinScan.name '-Sample Clock Acquisition']);
            obj.hSampleClockAcqChan = obj.hSampleClockAcq.createCOPulseChanFreq(obj.hLinScan.mdfData.deviceNameAux,...
                obj.SAMPLE_CLOCK_ACQ_CTR, 'Sample Clock Acquisition Output', 1.25e6, 0.5);
            obj.hSampleClockAcq.cfgImplicitTiming('DAQmx_Val_ContSamps',2);
            obj.hSampleClockAcq.cfgDigEdgeStartTrig('ao/StartTrigger'); % preliminary, changed later
            
            get(obj.hSampleClockAcqChan,'pulseFreq');
            set(obj.hSampleClockAcqChan,'pulseTerm',obj.SAMPLE_CLOCK_TERM_OUT); % disconnect standard output terminal (for RTSI routing)
            obj.sampleClockAcqTermInt = sprintf('/%sInternalOutput',obj.hSampleClockAcqChan.chanNamePhysical);
            
            % set up frame clock task
            obj.hFrameClock = most.util.safeCreateTask([obj.hLinScan.name '-Frame Clock']);
            obj.hFrameClockChan = obj.hFrameClock.createCOPulseChanTime(obj.hLinScan.mdfData.deviceNameAux, obj.FRAME_CLOCK_CTR_CHAN,...
                'Frame Clock',1,1,0);
            obj.hFrameClock.cfgImplicitTiming('DAQmx_Val_FiniteSamps',2);
            obj.hFrameClock.cfgDigEdgeStartTrig(obj.sampleClockAcqTermInt); % frame clock is triggered by sample acq clock

            set(obj.hFrameClockChan, 'pulseTerm', obj.FRAME_CLOCK_TERM_OUT);
            get(obj.hFrameClockChan, 'pulseTimeInitialDelay');
            get(obj.hFrameClockChan, 'pulseHighTime');
            get(obj.hFrameClockChan, 'pulseLowTime');
            obj.frameClockTermInt = sprintf('/%sInternalOutput',obj.hFrameClockChan.chanNamePhysical);
            
            % set up trigger timing task
            obj.hDITriggerTimes = most.util.safeCreateTask([obj.hLinScan.name '-Trigger Times']);
            obj.hDITriggerTimes.createDIChan(obj.hLinScan.mdfData.deviceNameAux,obj.TRIG_LINE_START,'Start Trigger','DAQmx_Val_ChanPerLine');
            obj.hDITriggerTimes.createDIChan(obj.hLinScan.mdfData.deviceNameAux,obj.TRIG_LINE_STOP,'Stop Trigger','DAQmx_Val_ChanPerLine');
            % PXIe-6738 does not have line 2
            try
                obj.hDITriggerTimes.createDIChan(obj.hLinScan.mdfData.deviceNameAux,obj.TRIG_LINE_NEXT,'Next Trigger','DAQmx_Val_ChanPerLine');
            catch
            end
            obj.triggerPolaritiesPropertyNames = {'trigAcqEdge','trigStopEdge','trigNextEdge'};
            
            obj.hDITriggerTimes.cfgSampClkTiming(obj.TRIGGER_TIMES_SAMPLE_RATE,'DAQmx_Val_ContSamps');
            obj.hDITriggerTimes.cfgDigEdgeStartTrig(obj.sampleClockAcqTermInt); % triggered once at the very start of the acqMode, then runs continuously
            obj.hDITriggerTimes.everyNSamplesReadDataEnable = false;
            obj.hDITriggerTimes.everyNSamplesEventCallbacks = @(src,evnt)obj.zzDISamplesAcquiredFcn(src,evnt);
            obj.hDITriggerTimes.everyNSamples = obj.TRIGGER_TIMES_EVERY_N_SAMPLES;
            obj.hDITriggerTimes.cfgInputBufferVerify(obj.TRIGGER_TIMES_EVERY_N_SAMPLES * obj.TRIGGER_TIMES_BUFFER_SIZE, 3 * obj.TRIGGER_TIMES_BUFFER_SIZE);
            obj.hDITriggerTimes.control('DAQmx_Val_Task_Unreserve'); %this avoids an error after resetting the daq
            
            % route reference clock
            obj.configureReferenceClock();
            auxTrigBoardIsRefClkSrc = strcmpi(obj.referenceClockTermInt,sprintf('/%s/%s',obj.hLinScan.mdfData.deviceNameAux,'10MHzRefClock'));
            
            % set up synchronization to reference clock
            if ~isempty(obj.referenceClockTermInt) && ~auxTrigBoardIsRefClkSrc
                set(obj.hSampleClockAcq.channels(1),'ctrTimebaseSrc',obj.referenceClockTermInt);
                set(obj.hSampleClockAcq.channels(1),'ctrTimebaseRate',obj.referenceClockRateInt);
                
                set(obj.hFrameClock.channels(1),'ctrTimebaseSrc',obj.referenceClockTermInt);
                set(obj.hFrameClock.channels(1),'ctrTimebaseRate',obj.referenceClockRateInt);
                
                set(obj.hDITriggerTimes,'sampClkTimebaseSrc',obj.referenceClockTermInt);
                set(obj.hDITriggerTimes,'sampClkTimebaseRate',obj.referenceClockRateInt);
            end
        end
        
        function configureReferenceClock(obj)
            deviceName = obj.hLinScan.mdfData.deviceNameAux;
            
            if ~isempty(obj.hLinScan.mdfData.internalRefClockSrc)
                obj.referenceClockTermInt = obj.hLinScan.mdfData.internalRefClockSrc;
                obj.referenceClockRateInt = obj.hLinScan.mdfData.internalRefClockRate;
                
                if obj.referenceClockRateInt > 10e6
                    decim = obj.referenceClockRateInt / 10e6;
                    decim = max(4, ceil(decim));
                    
                    obj.referenceClockTermExt = sprintf('/%s/Ctr%dInternalOutput',deviceName,obj.REF_CLOCK_CTR_CHAN);
                    obj.referenceClockRateExt = obj.referenceClockRateInt / decim;
                    
                    obj.hRefClock = most.util.safeCreateTask([obj.hLinScan.name '-Ref Clock']);
                    lowTicks = floor(decim / 2);
                    obj.hRefClock.createCOPulseChanTicks(obj.hLinScan.mdfData.deviceNameAux, obj.REF_CLOCK_CTR_CHAN,...
                        'Reference Clock',obj.referenceClockTermInt,lowTicks,decim - lowTicks,0);
                    set(obj.hRefClock.channels(1),'ctrTimebaseRate',obj.referenceClockRateInt);
                    set(obj.hRefClock.channels(1),'pulseTerm',[]);
                    obj.hRefClock.cfgImplicitTiming('DAQmx_Val_ContSamps');
                    obj.hRefClock.start();
                end
            else
                if isempty(obj.hLinScan.trigReferenceClkInInternalTerm)
                    obj.referenceClockTermInt = sprintf('/%s/%s',deviceName,'10MHzRefClock');
                    obj.referenceClockRateInt = 10e6;
                else
                    obj.referenceClockTermInt = obj.hLinScan.trigReferenceClkInInternalTerm;
                    obj.referenceClockRateInt = obj.hLinScan.trigReferenceClkInInternalRate;
                end
                obj.referenceClockTermExt = obj.referenceClockTermInt;
                obj.referenceClockRateExt = obj.referenceClockRateInt;
            end
            
            if obj.hLinScan.mdfData.enableRefClkOutput
                termDest = sprintf('/%s/%s',deviceName,obj.REFERENCE_CLOCK_TERM_OUT);
                obj.hRouteRegistry.connectTerms(obj.referenceClockTermExt,termDest);
            end
        end
    end
    
    %% Setter/Getter functions
    
    methods
        function val = get.sampleClkAcqTermOut(obj)
            if ~obj.enabled; return; end
            val = obj.hSampleClockAcqChan.pulseTerm;
        end
        
        function set.sampleClkAcqTermOut(obj,val)
            if ~obj.enabled; return; end
            if ~isempty(obj.sampleClkAcqTermOut)
                % disconnect old output terminal
                hDaqSystem = dabs.ni.daqmx.System();
                obj.hSampleClockAcqChan.pulseTerm = '';
                hDaqSystem.tristateOutputTerm(obj.sampleClkAcqTermOut);
            end
            
            % set the new output terminal
            obj.hSampleClockAcqChan.pulseTerm = val;
            obj.sampleClkAcqTermOut = val;
        end
        
        function val = get.sampleClkAcqStartTrigIn(obj)
            if ~obj.enabled; return; end
            startTrigType = get(obj.hSampleClockAcq,'startTrigType');
            
            switch startTrigType
                case 'DAQmx_Val_None';
                    val = '';
                case 'DAQmx_Val_DigEdge';
                    val = get(obj.hSampleClockAcq,'digEdgeStartTrigSrc');
                otherwise
                    assert(false);
            end
        end
        
        function set.sampleClkAcqStartTrigIn(obj,val)
            if ~obj.enabled; return; end
            
            obj.assertNotActive('sampleClkAcqStartTrigIn');
            
            switch obj.sampleClkAcqStartTrigEdge
                case 'rising'
                    edge = 'DAQmx_Val_Rising';
                case 'falling'
                    edge = 'DAQmx_Val_Falling';
                otherwise
                    assert(false);
            end
            
            if isempty(val)
                obj.hSampleClockAcq.disableStartTrig();
            else
                obj.hSampleClockAcq.cfgDigEdgeStartTrig(val,edge);
            end
        end
        
        function set.sampleClkAcqStartTrigEdge(obj,val)
            if ~obj.enabled; return; end
            obj.assertNotActive('sampleClkAcqStartTrigEdge');
            
            assert(ismember(val,{'rising','falling'}),'Not a valid trigger edge: %s',val);
            
            obj.sampleClkAcqStartTrigEdge = val;
            obj.sampleClkAcqStartTrigIn = obj.sampleClkAcqStartTrigIn;
        end
        
        function val = get.sampleClkAcqFreq(obj)
            if ~obj.enabled; return; end
            val = obj.hSampleClockAcqChan.pulseFreq;
        end
        
        function set.sampleClkAcqFreq(obj,val)
            if ~obj.enabled; return; end
            obj.hSampleClockAcqChan.pulseFreq = val;
        end
    end
    
    %% Private functions
    methods (Access = private)
        function configureFrameClock(obj)
            if obj.hLinScan.framesPerAcq <= 0 || isinf(obj.hLinScan.framesPerAcq) || obj.hLinScan.trigNextStopEnable
                obj.hFrameClock.sampQuantSampMode = 'DAQmx_Val_ContSamps';
            else
                obj.hFrameClock.sampQuantSampMode = 'DAQmx_Val_FiniteSamps';
                obj.hFrameClock.sampQuantSampPerChan = obj.hLinScan.framesPerAcq;
            end
            
            [initialDelayTime, highTime, lowTime] = obj.generateFrameClockOutput();
            obj.hFrameClockChan.pulseTimeInitialDelay = initialDelayTime;
            obj.hFrameClockChan.pulseHighTime = highTime;
            obj.hFrameClockChan.pulseLowTime = lowTime;
        end
        
        function [initialDelayTime, highTime, lowTime] = generateFrameClockOutput(obj)
            hRoiGroup = obj.hLinScan.currentRoiGroup;
            scannerset = obj.hLinScan.scannerset;
            
            initialDelayTime = 0;
            if obj.hLinScan.hSI.hRoiManager.isLineScan
                highTime = obj.hLinScan.hSI.hRoiManager.scanFramePeriod / 2;
                lowTime = highTime;
            else
                zs=obj.hLinScan.hSI.hStackManager.zs; % generate planes to scan based on motor position etc
                ts=arrayfun(@(z) hRoiGroup.sliceTime(scannerset,z),zs);
                secondsPerPlane=max(ts);
                
                [~,flybackTime]=arrayfun(@(z) hRoiGroup.transitTimes(scannerset,z),zs,'UniformOutput',false);
                maxFlybackTime = max(cell2mat(flybackTime)); % not ideal. should this be min or max or should the frame time be allowed to change for each plane?
                
                highTime = secondsPerPlane - maxFlybackTime;
                lowTime  = maxFlybackTime;
            end
        end
        
        function zzDISamplesAcquiredFcn(obj,~,~)
            obj.updateTriggerTimes(false,true);
        end
        
        function triggerTimes_ = updateTriggerTimes(obj,resetAfterRead,everyNCallback)
            % this function is called periodically to prevent the
            % hDITriggerTimes input buffer from overflowing between
            % acquisitions
            persistent lastProcessingTime
            
            if ~isempty(lastProcessingTime)
                timeSinceLastProcessing = toc(lastProcessingTime);
                everyNCallabckTime = obj.TRIGGER_TIMES_EVERY_N_SAMPLES / obj.TRIGGER_TIMES_SAMPLE_RATE;
                if everyNCallback && timeSinceLastProcessing <= everyNCallabckTime;   
                    return % prevent auto callback to be fired before everyNCallbackTime is expired
                end
            end
            
            if obj.triggerTimesProcessingNow % || obj.hDITriggerTimes.isTaskDone() % the isTaskDone check is most likely not necessary, but reduces performance
                return
            end
            
            % entering 'critical section'
            obj.triggerTimesProcessingNow = true;
            lastProcessingTime = tic();
            try
                % TODO: Why is the dabs property readAvailSampPerChan not available?
                % TODO: This call is slow. Improve performance
                availableSamples = obj.hDITriggerTimes.apiCall('DAQmxGetReadAvailSampPerChan',obj.hDITriggerTimes.taskID,0);
                if availableSamples > 0
                    [triggerTrace, samplesRead] = obj.hDITriggerTimes.readDigitalData(availableSamples,'logical',1);
                    
                    for i = 1:size(triggerTrace,2)
                        triggerPolarity = obj.triggerPolarities{i}; % one of {'rising','falling'}
                        triggerSampleIndex = obj.findTriggerIndex(triggerTrace(:,i),triggerPolarity,'first');
                        if  ~isnan(triggerSampleIndex) && ~obj.triggerTimesDetected(i)
                            triggerSampleIndex = triggerSampleIndex + obj.triggerTimesLastReadSamples;
                            obj.triggerTimes(i) = triggerSampleIndex / obj.TRIGGER_TIMES_SAMPLE_RATE;
                            obj.triggerTimesDetected(i) = true;
                        end
                    end
                    
                    obj.triggerTimesLastReadSamples = obj.triggerTimesLastReadSamples + samplesRead;
                end
            catch ME
                most.idioms.reportError(ME);
            end
            
            triggerTimes_ = obj.triggerTimes;
            for i = 1:length(triggerTimes_)
               if ~obj.triggerTimesDetected(i)
                   triggerTimes_(i) = NaN;
               end
            end
            
            if resetAfterRead
                obj.triggerTimesDetected = [false false false];
            end
            
            %% leaving 'critical section'
            obj.triggerTimesProcessingNow = false;
        end
        
        function assertNotActive(obj,propName)
            assert(~obj.active,'Cannot access property %s during an active acquisition',propName);
        end
        
        function valCoercedWarning(~,propName,requestedVal,actualVal)
            if requestedVal ~= actualVal
                warning('%s was coerced to the nearest possible value. Requested: %d Actual: %d', ...
                    propName, requestedVal, actualVal);
            end
        end
        
        function zprvClearTask(obj, taskPropertyName)
            most.idioms.safeDeleteObj(obj.(taskPropertyName));
            obj.(taskPropertyName) = [];
        end
        
        function zprvSaveAbortTask(obj,taskPropertyName)
            % translates a hard error into a soft error for abort
            hTask = obj.(taskPropertyName);
            try
               hTask.abort();
               hTask.control('DAQmx_Val_Task_Unreserve');
            catch ME
               most.idioms.reportError(ME); 
            end
        end
        
        function triggerIdx = findTriggerIndex(~,signal,polarity,position)
            if nargin < 3 || isempty(polarity)
                polarity = 'rising';
            end
            
            if nargin < 4 || isempty(position)
                position = 'first';
            end
            
            signalTemp = [signal(1,:);signal];
            signal = [signal;signal(end,:)];

            switch polarity
                case 'rising'
                    signalTemp = and(signal,~signalTemp);
                case 'falling'
                    signalTemp = and(~signal,signalTemp);
                otherwise
                    assert(false)
            end
            
            numChans = size(signal,2);
            triggerIdx = zeros(1,numChans);
            for chan = 1:numChans
                index = find(signalTemp(:,chan),1,position);
                if isempty(index)
                    index = NaN;
                end
                triggerIdx(chan) = index;
            end
        end
    end
end


%--------------------------------------------------------------------------%
% Triggering.m                                                             %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
