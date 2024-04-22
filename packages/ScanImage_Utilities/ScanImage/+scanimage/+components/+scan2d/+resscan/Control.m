classdef Control < scanimage.interfaces.Class    
    properties (Hidden, SetAccess = immutable)
        hScan;
    end
    
    properties (Hidden, SetAccess = private)
        xGalvoExists = false;                % true if x-galvo exists 
    end
    
    properties (Hidden, Constant)
        AO_RATE_LIMIT = 200e3;               % limit for analog output rate
    end
    
    %% Original props
    %SCANNINGGALVO
    properties
        galvoFlyBackPeriods = 1;             % the number of scanner periods to fly back the galvo. can only be updated while the scanner is idle
        zoomFactor = 1;
        fillFractionSpatial = 1;
        resonantScannerZoomOutput = true;
        
        frameClockIn = 'PFI1';               % String identifying the input terminal connected to the frame clock. Values are 'PFI0'..'PFI15' and 'PXI_Trig0'..'PXI_Trig7'

        %simulated mode
        simulated=false;
    end
    
    % Live Values - these properties can be updated during an active acquisitio    
    properties (Dependent)
        galvoParkVoltsX;        
        galvoParkVoltsY;
    end
    
    % Internal Parameters
    properties (SetAccess = private, Hidden)
        hDaqDevice;
        
        hAOTaskResonantScannerZoom;
        hCtrTaskResonantScannerZoom;
        hDOTaskResonantScannerEnable;
        
        hAOTaskGalvo;
        hCtrMSeriesSampClk;
        useSamplClkHelperTask = false;
        
        acquisitionActive = false;
        rateAOSampClk;
        resScanBoxCtrlInitialized;
        
        resonantScannerLastUpdate = clock;
        resonantScannerLastWrittenValue;
        
        activeFlag = false;
        
        galvoBufferUpdatingAsyncNow = false;
        galvoBufferNeedsUpdateAsync = false;
        galvoBufferUpdatingAsyncRetries = 0;
        galvoBuffer = [];
    end
    
    %% Lifecycle
    methods
        function obj = Control(hScan,simulated)
            if nargin < 1 || isempty(hScan)
                hScan = [];
            end
            
            if nargin < 2 || isempty(simulated)
                obj.simulated=false;
            else
                obj.simulated=simulated;
            end
            
            obj.hScan = hScan;
            
            %Get property values from machineDataFile
            validateattributes(obj.hScan.mdfData.galvoDeviceName,{'char'},{'vector','nonempty'});
            
            if ~isempty(obj.hScan.mdfData.galvoAOChanIDX)
                obj.xGalvoExists = true;
                validateattributes(obj.hScan.mdfData.galvoAOChanIDX,{'numeric'},{'scalar','nonnegative'});
                validateattributes(obj.hScan.mdfData.galvoVoltsPerOpticalDegreeX,{'numeric'},{'scalar','finite'});
            end
            validateattributes(obj.hScan.mdfData.galvoAOChanIDY,{'numeric'},{'scalar','nonnegative','nonempty'});
            
            if ~isfield(obj.hScan.mdfData,'resonantZoomDeviceName') || isempty(obj.hScan.mdfData.resonantZoomDeviceName)
                obj.hScan.mdfData.resonantZoomDeviceName = obj.hScan.mdfData.galvoDeviceName;
            end
            
            if ischar(obj.hScan.mdfData.resonantZoomAOChanID) && isempty(strtrim(obj.hScan.mdfData.resonantZoomAOChanID))
                obj.hScan.disableResonantZoomOutput = true;
            elseif ischar(obj.hScan.mdfData.resonantZoomAOChanID)
                validateattributes(obj.hScan.mdfData.resonantZoomAOChanID,{'char'},{'nonempty'});
                assert(~isempty(regexpi(obj.hScan.mdfData.resonantZoomAOChanID,'PFI[0-9]+')),'Not a valid PFI channel: %s',obj.hScan.mdfData.resonantZoomAOChanID);
            else
                validateattributes(obj.hScan.mdfData.resonantZoomAOChanID,{'numeric'},{'scalar','nonnegative','nonempty'});
            end
            validateattributes(obj.hScan.mdfData.resonantEnableTerminal,{'numeric','char'},{});
            
            validateattributes(obj.hScan.mdfData.galvoVoltsPerOpticalDegreeY,{'numeric'},{'scalar','finite'});
            validateattributes(obj.hScan.mdfData.rScanVoltsPerOpticalDegree,{'numeric'},{'scalar','finite','positive'});
            
            validateattributes(obj.hScan.mdfData.resonantScannerSettleTime,{'numeric'},{'scalar','nonnegative','nonempty'});
        end
        
        function delete(obj)
            try
                if obj.acquisitionActive
                    obj.stop();
                end
                
                % disable resonant scanner (may still be on depending on setting)
                obj.resonantScannerActivate(false);
                
                deleteTasks();                
            catch ME
                deleteTasks();
                %obj.hDaqDevice.reset(); % hard reset the device to clear all routes and delete all tasks
                rethrow(ME);
            end
            
            function deleteTasks()
                % clear DAQmx buffered Tasks
                most.idioms.safeDeleteObj(obj.hCtrMSeriesSampClk);
                most.idioms.safeDeleteObj(obj.hAOTaskGalvo);
                
                % clear unbuffered Tasks
                most.idioms.safeDeleteObj(obj.hAOTaskResonantScannerZoom);
                most.idioms.safeDeleteObj(obj.hCtrTaskResonantScannerZoom);
                most.idioms.safeDeleteObj(obj.hDOTaskResonantScannerEnable);
            end
        end
        
        function initialize(obj)
            obj.hDaqDevice = dabs.ni.daqmx.Device(obj.hScan.mdfData.galvoDeviceName);
            obj.initializeTasks();
            obj.zoomFactor = obj.zoomFactor; %self initialize output
        end
        
    end
    
    %% Public Methods
    methods        
        function start(obj)
            assert(~obj.acquisitionActive,'Acquisition is already active');    
            % Reconfigure the Tasks for the selected acquisition Model
            obj.updateTaskCfg();
            % this pause needed for the Resonant Scanner to reach
            % its amplitude and send valid triggers
            obj.activeFlag = true;
            obj.resonantScannerWaitSettle();
            % during resonantScannerWaitSettle a user might have clicked
            % 'abort' - which in turn calls obj.abort and unreserves
            % obj.hAOTaskGalvo; catch this by checking obj.activeflag
            if ~obj.activeFlag
                errorStruct.message = 'Soft error: ResScan was aborted before the resonant scanner could settle.';
                errorStruct.identifier = '';
                errorStruct.stack = struct('file',cell(0,1),'name',cell(0,1),'line',cell(0,1));
                error(errorStruct); % this needs to be an error, so that Scan2D will be aborted correctly
            end
                  
            
            obj.hAOTaskGalvo.start();
            if obj.useSamplClkHelperTask
                obj.hCtrMSeriesSampClk.start();
            end
            
            if (~obj.simulated)    
                obj.hScan.liveScannerFreq = [];
                obj.hScan.lastLiveScannerFreqMeasTime = [];
            end
            
            obj.acquisitionActive = true;  
        end
        
        function stop(obj,soft)
            if nargin < 2 || isempty(soft)
                soft = false;
            end
            
            if obj.useSamplClkHelperTask
                obj.hCtrMSeriesSampClk.abort();
                obj.hCtrMSeriesSampClk.control('DAQmx_Val_Task_Unreserve'); % to allow the galvo to be parked
            end
            
            obj.hAOTaskGalvo.stop();
            obj.hAOTaskGalvo.control('DAQmx_Val_Task_Unreserve'); % to allow the galvo to be parked
            
            obj.activeFlag = false;
                        
            %Park scanner
            % parkGalvo() has to be called after acquisitionActive is set to
            % false, otherwise we run into an infinite loop
            obj.acquisitionActive = false;
            if (~obj.simulated)
                obj.parkGalvo();
            end
            
            if obj.hScan.keepResonantScannerOn || soft
                obj.resonantScannerActivate(true);
            else
                obj.resonantScannerActivate(false);
            end
            
            obj.galvoBufferUpdatingAsyncNow = false;
        end
        
        function resonantScannerActivate(obj,activate,volts)
           if nargin < 2 || isempty(activate)
               activate = true;
           end
           
           if activate
               if nargin < 3 || isempty(volts)
                   resScanOutputPoint = obj.nextResonantVoltage;
               else
                   resScanOutputPoint = volts;
               end
           else
               resScanOutputPoint = 0;
           end
           
           obj.resonantScannerUpdateOutputVolts(resScanOutputPoint);
        end
        
        function resonantScannerWaitSettle(obj,settleTime)
            if nargin < 2 || isempty(settleTime)
            	timeToWait = obj.getRemainingResSettlingTime();
			else
            	timeToWait = obj.getRemainingResSettlingTime(settleTime);
            end
            
            if timeToWait > 0
                %fprintf('Waiting %f seconds for resonant scanner to settle\n',timeToWait);
                pause(timeToWait);
            end
        end
        
        function timeToWait = getRemainingResSettlingTime(obj,settleTime)
            if nargin < 2 || isempty(settleTime)
                settleTime = max(0.5,obj.hScan.mdfData.resonantScannerSettleTime);
            end
            
            timeSinceLastAOUpdate = etime(clock,obj.resonantScannerLastUpdate);
            timeToWait = max(0, settleTime-timeSinceLastAOUpdate);
        end
        
        function parkGalvo(obj)
           assert(~obj.acquisitionActive,'Cannot park galvo while scanner is active');
           
           if ~isempty(obj.hScan.xGalvo);
               obj.hScan.xGalvo.hDevice.park();
           end
           obj.hScan.yGalvo.hDevice.park();
        end
        
        function centerGalvo(obj)
           assert(~obj.acquisitionActive,'Cannot center galvo while scanner is active');
           
           if ~isempty(obj.hScan.xGalvo);
               obj.hScan.xGalvo.hDevice.center();
           end
           obj.hScan.yGalvo.hDevice.center();
        end
            
        function pointResAmplitudeDeg(obj,angle)
            volts = obj.hScan.zzzResonantFov2Volts(angle/obj.hScan.mdfData.resonantAngularRange);
            obj.pointResAmplitudeVolts(volts);
        end
        
        function pointResAmplitudeVolts(obj,val)
            assert(~obj.acquisitionActive,'Cannot change resonant scanner amplitude while scan is active');
            obj.resonantScannerActivate(true,val);
        end
        
        function updateLiveValues(obj,regenAO,restartTask)
            if nargin < 2
                regenAO = true;
            end
            
            if nargin < 3
                restartTask = false;
            end
            
            if obj.acquisitionActive
                try
                    if regenAO
                        obj.hScan.hSI.hWaveformManager.updateWaveforms();
                    end
                    
                    obj.updateTaskCfg(true,restartTask);
                catch ME
                    % ignore DAQmx Error 200015 since it is irrelevant here
                    % Error message: "While writing to the buffer during a
                    % regeneration the actual data generated might have
                    % alternated between old data and new data."
                    if isempty(strfind(ME.message, '200015'))
                        rethrow(ME)
                    end
                end
            else
                if obj.hScan.keepResonantScannerOn
                    obj.resonantScannerActivate();
                end
                
                % if the parking position for the Galvo was updated, apply
                % the new settings.
                obj.parkGalvo();
            end
        end
    end
    
    %% Private Methods
    methods (Hidden)
        function v = nextResonantVoltage(obj)
            v = obj.hScan.scannerset.resonantScanVoltage(obj.hScan.currentRoiGroup);
        end
        
        function v = nextResonantFov(obj)
            v = obj.hScan.scannerset.resonantScanFov(obj.hScan.currentRoiGroup);
        end
    end
    
    methods (Access = private)
        function resonantScannerUpdateOutputVolts(obj,val)
            if abs(val - obj.resonantScannerLastWrittenValue) > 0.0001
                obj.resonantScannerLastUpdate = clock;
            end
            
            if ~obj.hScan.disableResonantZoomOutput
                if ~isempty(obj.hAOTaskResonantScannerZoom)
                    obj.hAOTaskResonantScannerZoom.writeAnalogData(val);
                else
                    obj.hCtrTaskResonantScannerZoom.abort();
                    obj.hCtrTaskResonantScannerZoom.control('DAQmx_Val_Task_Unreserve');
                    if val > 0
                        dutyCycle = val / (obj.hScan.mdfData.rScanVoltsPerOpticalDegree * obj.hScan.mdfData.resonantAngularRange);
                        dutyCycle = max(min(dutyCycle,0.99),0.01); % dutyCycle cannot be 0 or 1
                        obj.hCtrTaskResonantScannerZoom.channels.set('pulseDutyCyc',dutyCycle);
                        obj.hCtrTaskResonantScannerZoom.start();
                    end
                end
                
                if most.idioms.isValidObj(obj.hDOTaskResonantScannerEnable)
                    if isempty(val)
                        val = 0;
                    else
                        scannerEnable = val>0;
                    end
                    obj.hDOTaskResonantScannerEnable.writeDigitalData(scannerEnable);
                end
            end
            
            if val
                obj.hScan.flagZoomChanged = true;
                obj.hScan.linePhase = obj.hScan.zzzEstimateLinePhase(val);
            end
            
            obj.resonantScannerLastWrittenValue = val;
            notify(obj.hScan,'resonantScannerOutputVoltsUpdated');
        end
        
        function initializeTasks(obj) 
            try
                % create Tasks
                obj.hAOTaskGalvo = most.util.safeCreateTask([obj.hScan.name '-GalvoCtrlGalvoPosition']);
                
                if ~isempty(obj.hScan.mdfData.resonantEnableTerminal)
                    if isnumeric(obj.hScan.mdfData.resonantEnableTerminal)
                        validateattributes(obj.hScan.mdfData.resonantEnableTerminal,{'numeric'},{'scalar','nonnegative','integer'});
                        chan = sprintf('PFI%d',obj.hScan.mdfData.resonantEnableTerminal);
                    else
                        validateattributes(obj.hScan.mdfData.resonantEnableTerminal,{'char'},{'vector'});
                        chan = obj.hScan.mdfData.resonantEnableTerminal;
                    end
                    obj.hDOTaskResonantScannerEnable = most.util.safeCreateTask([obj.hScan.name '-GalvoCtrlResonantScannerEnable']);
                    obj.hDOTaskResonantScannerEnable.createDOChan(obj.hScan.mdfData.resonantZoomDeviceName,chan);
                end
                
                %set up buffered AO Task to control the Galvo Scan
                if obj.xGalvoExists
                    obj.hAOTaskGalvo.createAOVoltageChan(obj.hScan.mdfData.galvoDeviceName,obj.hScan.mdfData.galvoAOChanIDX,'X Galvo Control',-10,10);
                end
                obj.hAOTaskGalvo.createAOVoltageChan(obj.hScan.mdfData.galvoDeviceName,obj.hScan.mdfData.galvoAOChanIDY,'Y Galvo Control',-10,10);
                maxSampleRate = min(scanimage.util.daqTaskGetMaxSampleRate(obj.hAOTaskGalvo),obj.AO_RATE_LIMIT);
                
                galvoOutputMode = 'DAQmx_Val_FiniteSamps';
                if obj.simulated
                    galvoOutputMode = 'DAQmx_Val_ContSamps';
                end
                
                switch obj.hDaqDevice.productCategory
                    case 'DAQmx_Val_AOSeries'
                        most.idioms.warn('Support for PXIe-6738/6739 is experimental. Some features may not work.');
                        obj.hAOTaskGalvo.cfgSampClkTiming(maxSampleRate,galvoOutputMode,2); % length of output will be overwritten later
                        obj.rateAOSampClk = get(obj.hAOTaskGalvo,'sampClkRate');
                        obj.configureFrameClkTrigger(obj.hAOTaskGalvo);
                        obj.useSamplClkHelperTask = false;
                    case 'DAQmx_Val_XSeriesDAQ'
                        obj.hAOTaskGalvo.cfgSampClkTiming(maxSampleRate,galvoOutputMode,2); % length of output will be overwritten later
                        obj.rateAOSampClk = get(obj.hAOTaskGalvo,'sampClkRate');
                        obj.configureFrameClkTrigger(obj.hAOTaskGalvo);
                        obj.useSamplClkHelperTask = false;
                    case 'DAQmx_Val_MSeriesDAQ'
                        % the M series does not support native retriggering for
                        % AOs. Workaround: Use counter to produce sample clock
                        obj.hCtrMSeriesSampClk = most.util.safeCreateTask([obj.hScan.name '-M-Series helper task']);
                        obj.hCtrMSeriesSampClk.createCOPulseChanFreq(obj.hScan.mdfData.galvoDeviceName,0,[],maxSampleRate);
                        obj.rateAOSampClk = get(obj.hCtrMSeriesSampClk.channels(1),'pulseFreq');
                        obj.hCtrMSeriesSampClk.channels(1).set('pulseTerm',''); % we do not need to export the sample clock to a PFI. delete
                        obj.hCtrMSeriesSampClk.cfgImplicitTiming(galvoOutputMode,2); % length of output will be overwritten later
                        obj.configureFrameClkTrigger(obj.hCtrMSeriesSampClk);
                        
                        % setup hAOTaskGalvo to use the sample clock generated by the counter
                        samplClkInternalOutputTerm = sprintf('/%sInternalOutput',obj.hCtrMSeriesSampClk.channels(1).chanNamePhysical);
                        obj.hAOTaskGalvo.cfgSampClkTiming(obj.rateAOSampClk,'DAQmx_Val_ContSamps',2,samplClkInternalOutputTerm);
                        obj.useSamplClkHelperTask = true;
                    otherwise
                        error('Primary DAQ Device needs to be either M-series or X-series');
                end
                
                obj.parkGalvo();
                
                %set up unbuffered Task to set the resonant scanner zoom level
                
                if isnumeric(obj.hScan.mdfData.resonantZoomAOChanID)
                    obj.hAOTaskResonantScannerZoom = most.util.safeCreateTask([obj.hScan.name '-GalvoCtrlResonantScannerZoomVolts']);
                    hChan = obj.hAOTaskResonantScannerZoom.createAOVoltageChan(obj.hScan.mdfData.resonantZoomDeviceName,obj.hScan.mdfData.resonantZoomAOChanID);
                    rngHigh = hChan.get('DACRngHigh');
                    vrg = min(rngHigh,1.1*obj.hScan.mdfData.rScanVoltsPerOpticalDegree*obj.hScan.mdfData.resonantAngularRange);
                    hChan.set('min',0);
                    hChan.set('max',vrg);
                else
                    obj.hCtrTaskResonantScannerZoom = most.util.safeCreateTask([obj.hScan.name '-GalvoCtrlResonantScannerZoomPWM']);
                    resOutputCtrChannel = 3;
                    counterOutputFreq = 100e3;
                    obj.hCtrTaskResonantScannerZoom.createCOPulseChanFreq(obj.hScan.mdfData.resonantZoomDeviceName,resOutputCtrChannel,[],counterOutputFreq);
                    set(obj.hCtrTaskResonantScannerZoom.channels,'pulseTerm',obj.hScan.mdfData.resonantZoomAOChanID);
                    obj.hCtrTaskResonantScannerZoom.cfgImplicitTiming('DAQmx_Val_ContSamps');
                end
                
                obj.resonantScannerActivate(false); % set output to zero
            catch ME
                obj.hDaqDevice.reset(); %clear all routes
                delete(obj)
                rethrow(ME);
            end
            
            obj.resScanBoxCtrlInitialized = true;
        end
        
        function configureFrameClkTrigger(obj,hTask)
            if ~obj.simulated
                hTask.cfgDigEdgeStartTrig(obj.frameClockIn,'DAQmx_Val_Rising');
                hTask.set('startTrigRetriggerable',true);
            end
        end
             
        function updateTaskCfg(obj, isLive, restartTask)            
            if nargin < 2 || isempty(isLive)
                isLive = false;
            end
            
            if nargin < 3
                restartTask = false;
            end
            
            recurse = false;
            
            [scanPoints,samplesPerFrame] = obj.getGalvoScanOutputPts();
            
            % Handle Resonant Scanner.
            % Update AO Buffers (Performance seems to be better when updating the galvo task last.
            resScanOutputPoint_ = scanPoints(1,1);
            obj.resonantScannerUpdateOutputVolts(resScanOutputPoint_);
            
            % Handle Galvo.
            if obj.xGalvoExists
                obj.galvoBuffer = scanPoints(:,2:3);
            else
                obj.galvoBuffer = scanPoints(:,3);
            end
            bufferLength = length(obj.galvoBuffer);
            assert(bufferLength > 0, 'AO generation error. Galvo control waveform length is zero.');
            
            % If acq is not live make sure buffered tasks are stopped
            if ~isLive
                if obj.useSamplClkHelperTask
                    obj.hCtrMSeriesSampClk.abort();
                end

                obj.hAOTaskGalvo.abort();
                obj.hAOTaskGalvo.control('DAQmx_Val_Task_Unreserve'); % to allow the galvo to be parked
            
                oldSampleRate = obj.rateAOSampClk;
                if obj.useSamplClkHelperTask
                    obj.hCtrMSeriesSampClk.set('sampQuantSampPerChan',length(obj.galvoBuffer));
                    obj.configureFrameClkTrigger(obj.hCtrMSeriesSampClk);
                    if ~obj.simulated
                        obj.hCtrMSeriesSampClk.channels(1).set('ctrTimebaseSrc',obj.hScan.trigReferenceClkOutInternalTerm);
                        obj.hCtrMSeriesSampClk.channels(1).set('ctrTimebaseRate',obj.hScan.trigReferenceClkOutInternalRate);
                    end
                    obj.hAOTaskGalvo.set('sampQuantSampPerChan',samplesPerFrame);
                    
                    obj.rateAOSampClk = get(obj.hCtrMSeriesSampClk.channels(1),'pulseFreq');
                else
                    obj.configureFrameClkTrigger(obj.hAOTaskGalvo);
                    obj.hAOTaskGalvo.set('sampQuantSampPerChan',samplesPerFrame);
                    if ~obj.simulated
                        if obj.hScan.useResonantTimebase
                            obj.hAOTaskGalvo.set('sampClkTimebaseSrc',obj.hScan.hTrig.getPXITerminal('resonantTimebaseOut'));
                            obj.hAOTaskGalvo.set('sampClkTimebaseRate',obj.hScan.resonantTimebaseNominalRate);
                        else
                            obj.hAOTaskGalvo.set('sampClkTimebaseSrc',obj.hScan.trigReferenceClkOutInternalTerm);
                            obj.hAOTaskGalvo.set('sampClkTimebaseRate',obj.hScan.trigReferenceClkOutInternalRate);
                        end
                    end
                    obj.rateAOSampClk = get(obj.hAOTaskGalvo,'sampClkRate');
                end
                % setting the sampClkTimebaseSrc might change the
                % rateAOSampClk. in this case execute updateTaskCfg one
                % more time
                if obj.rateAOSampClk ~= oldSampleRate
                    recurse = true;
                end
                
                timeout = 3;
            else
                timeout = nan;
            end
            
            % Update AO Buffers
            if restartTask
                obj.hAOTaskGalvo.abort();
                timeout = 3;
            end
            
            obj.hAOTaskGalvo.cfgOutputBuffer(bufferLength);
            obj.updateGalvoBufferAsync(timeout);
            
            if restartTask && obj.hScan.active
                obj.hAOTaskGalvo.start();
            end
            
            if recurse
                obj.updateTaskCfg();
            end
        end
        
        function updateGalvoBufferAsync(obj, timeout)
            
            if nargin < 2 || isempty(timeout)
                timeout = nan;
            end
            
            if obj.galvoBufferUpdatingAsyncNow
                % async call currently in progress. schedule update after current update finishes
                obj.galvoBufferNeedsUpdateAsync = true;
            else
                obj.galvoBufferNeedsUpdateAsync = false;
                obj.galvoBufferUpdatingAsyncNow = true;
                obj.hAOTaskGalvo.writeAnalogDataAsync(obj.galvoBuffer,[],[],[],@(src,evt)obj.updateGalvoBufferAsyncCallback(src,evt));
            end
            
            if ~isnan(timeout)
                t = tic;
                while obj.galvoBufferUpdatingAsyncNow
                    pause(.01);
                    assert(toc(t) < timeout, 'Galvo buffer write timed out.');
                end
            end
        end
        
        function updateGalvoBufferAsyncCallback(obj,~,evt)
            obj.galvoBufferUpdatingAsyncNow = false;
            
            if evt.status ~= 0 && evt.status ~= 200015 && obj.hScan.active
                fprintf(2,'Error updating galvo buffer: %s\n%s\n',evt.errorString,evt.extendedErrorInfo);
                
                if obj.galvoBufferUpdatingAsyncRetries < 3 || obj.galvoBufferNeedsUpdateAsync
                    obj.galvoBufferUpdatingAsyncRetries = obj.galvoBufferUpdatingAsyncRetries + 1;
                    fprintf(2,'Scanimage will retry update...\n');
                    obj.updateGalvoBufferAsync();
                else
                    obj.galvoBufferUpdatingAsyncRetries = 0;
                end
            else
                obj.galvoBufferUpdatingAsyncRetries = 0;

                if obj.galvoBufferNeedsUpdateAsync
                    obj.updateGalvoBufferAsync();
                end
            end
        end
        
        function [dataPoints,samplesPerFrame] = getGalvoScanOutputPts(obj)
            
            dataPoints = [obj.hScan.hSI.hWaveformManager.scannerAO.ao_volts.R obj.hScan.hSI.hWaveformManager.scannerAO.ao_volts.G];
            samplesPerFrame = obj.hScan.hSI.hWaveformManager.scannerAO.ao_samplesPerTrigger.G;
            
            %Replace any NaN's with the maximum volts for the resonant scanner.
            %This handles any and all invalid values passed into the resonant scanner.
            maxResonantVolts = max(dataPoints(:,1));
            dataPoints(isnan(dataPoints),1) = maxResonantVolts;
            
            assert(~mod(length(dataPoints),samplesPerFrame),'Length of dataPoints has to be divisible by samplesPerFrame');
        end
    end
    
    %% Property Set Methods
    methods        
        function set.frameClockIn(obj,value)
            assert(~obj.acquisitionActive,'Cannot change %s while scanner is active','frameClockIn');
            validateattributes(value,{'char'},{'vector','nonempty'});
            
            obj.frameClockIn = value;
            % settings are applied in updateTaskCfg()
        end
        
        function set.galvoFlyBackPeriods(obj,value)
            assert(~obj.acquisitionActive,'Cannot change %s while scanner is active','galvoFlyBackPeriods');
            assert(value >= 1,'galvoFlyBackPeriods must be greater or equal to 1');
            obj.galvoFlyBackPeriods = value;
        end
        
        function value = get.galvoParkVoltsX(obj)
            value = obj.hScan.mdfData.galvoParkDegreesX * obj.hScan.mdfData.galvoVoltsPerOpticalDegreeX;
        end
        
        function value = get.galvoParkVoltsY(obj)
            value = obj.hScan.mdfData.galvoParkDegreesY * obj.hScan.mdfData.galvoVoltsPerOpticalDegreeY;
        end
    end
end


%--------------------------------------------------------------------------%
% Control.m                                                                %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
