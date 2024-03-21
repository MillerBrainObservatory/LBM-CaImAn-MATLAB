classdef Control < scanimage.interfaces.Class
    properties (SetAccess = immutable)
        hLinScan;                             % handle of Scan2D, handle gracefully if empty
        hBeams;
    end
    
    properties (SetAccess = private)
        hAOxyb;                                 % handle of AO Task for control of an analog-controlled X/Y scanner pair
        hAOxybz;                                % handle of AO Task for control of an analog-controlled X/Y scanner pair and fastz actuator
        hAO;                                    % handle to either hAOxyb or hAOxybz depending on if fastz is active
        zActive;                                % indicates that hAOxybz is the active task and that z AO waveform should be included
        
        hAOOffset;                              % handle of AO Task for offset control of an analog-controlled X/Y scanner pair
        hAOSampClk;                             % handle of Ctr Task for sample clock generation for hAO
        
        offsetVoltage = [0,0];                  % last written offset voltage for motion correction
        beamShareGalvoDAQ = false;              % Indicates that beam control channels are on the galvo DAQ. Possible if galvo control DAQ has >2 output channels
        zShareGalvoDAQ = false;                 % Indicates that the fastz control channel is on the galvo DAQ. Possible if galvo control DAQ has >2 output channels
        flagOutputNeedsUpdate = false;          % for 'live' acquisition output set to true to indicate that scan parameters (e.g. zoom) changed so that AO needs to be updated
        updatingOutputNow = false;              % protects the 'critical section' in obj.updateAnalogBufferAsync
        waveformLength;                         % length of the output waveform for one frame
        scannerOutputUnTransformed;             % scanner output before transformation (zoom,shift,multiplier)
        bufferUpdatingAsyncRetries = 0;
        samplesDone = 0;
    end
    
    properties (Access = private)
        offsetUseAsyncWrite = false;
        offsetVoltageAsyncLock = false;
        offsetVoltageAsyncNextUpdateVoltage = [];
        beamIDs;                                % beamIDs, as defined in hBeams
    end
    
    properties (Dependent)
        active;                                 % (logical) true during an active output
        startTrigIn;                            % input terminal of the start trigger (e.g. 'PFI0'); if empty, triggering is disabled
        sampClkSrc;
        sampClkTimebaseSrc;
        sampClkTimebaseRate;
        sampClkRate;
        sampClkMaxRate;
    end
    
    properties
        scanXisFast = true;                     % Fast scanning done on X scanner (identified in MDF). If false, fast scanning done on Y scanner
        
        startTrigOut;                           % output terminal of the start trigger
        
        startTrigEdge = 'rising';               % trigger polarity for the start trigger. one of {'rising','falling'}
    end
    
    properties (Hidden)
        samplesWritten;
        samplesGenerated;
        framesGenerated;
        framesWritten;
        
        genSampClk = false;
    end
    
    %% Lifecycle
    methods
        function obj = Control(hLinScan)
            obj.hLinScan = hLinScan;
            obj.hBeams = hLinScan.hSI.hBeams;
            
            if isempty(obj.hLinScan.mdfData.beamDaqID)
                obj.beamIDs = [];
            else
                obj.beamIDs = cell2mat(obj.hLinScan.hSI.hBeams.daqBeamIDs(obj.hLinScan.mdfData.beamDaqID));
            end
            
            obj.ziniPrepareTasks();
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hAOxyb);
            most.idioms.safeDeleteObj(obj.hAOxybz);
            most.idioms.safeDeleteObj(obj.hAOOffset);
            most.idioms.safeDeleteObj(obj.hAOSampClk);
        end
    end
    
    % Public Methods
    methods
        function start(obj)
            obj.assertNotActive('method:start');
            obj.hAO.abort(); % to prevent DAQmx error -200288
            if obj.genSampClk
                obj.hAOSampClk.abort();
            end
            
            obj.zActive = obj.zShareGalvoDAQ && obj.hLinScan.hSI.hFastZ.outputActive;
            if obj.zActive
                obj.hAO = obj.hAOxybz;
            else
                obj.hAO = obj.hAOxyb;
            end
            
            % calculate output buffer
            if obj.beamShareGalvoDAQ
                obj.waveformLength = obj.hBeams.configureStreaming(obj.hAO.sampClkRate);
                obj.samplesGenerated = 0;
                obj.framesGenerated = 0;
                obj.samplesWritten = obj.hBeams.streamingBufferSamples;
                obj.framesWritten = obj.hBeams.streamingBufferFrames;
                [waveformOutput,beamPathOutput] = obj.calcJointBuffer(1,obj.hBeams.streamingBufferFrames);
                if obj.hBeams.streamingBuffer
                    obj.hAO.registerEveryNSamplesEvent(@obj.streamingBufferNSampCB,obj.hBeams.nSampCbN,false);
                    obj.hAO.set('writeRegenMode','DAQmx_Val_DoNotAllowRegen');
                else
                    obj.hAO.registerEveryNSamplesEvent([],[],false);
                    obj.hAO.set('writeRegenMode','DAQmx_Val_AllowRegen');
                end
            else
                beamPathOutput = [];
                waveformOutput = obj.hLinScan.hSI.hWaveformManager.scannerAO.ao_volts.G;
                
                if obj.zActive
                    waveformOutput = [waveformOutput obj.hLinScan.hSI.hWaveformManager.scannerAO.ao_volts.Z];
                end
                
                obj.hAO.set('writeRegenMode','DAQmx_Val_AllowRegen');
                obj.waveformLength = size(waveformOutput,1);
            end
            assert(obj.waveformLength > 0, 'AO generation error. Scanner control waveform length is zero.');
            
            % configure sample mode
            if obj.hLinScan.framesPerAcq <= 0 || isinf(obj.hLinScan.framesPerAcq) || obj.hLinScan.trigNextStopEnableInternal
                obj.hAO.sampQuantSampMode = 'DAQmx_Val_ContSamps';
            else
                obj.hAO.sampQuantSampMode = 'DAQmx_Val_FiniteSamps';
                obj.hAO.sampQuantSampPerChan = obj.waveformLength * obj.hLinScan.framesPerAcq;
            end
            
            % update output buffer
            obj.hAO.cfgOutputBuffer(obj.waveformLength);
            obj.hAO.writeRelativeTo = 'DAQmx_Val_FirstSample';
            obj.hAO.writeOffset = 0;
            if ~obj.hLinScan.simulated
                obj.updateBeamStatusFrac(NaN);
                obj.hAO.writeAnalogData(waveformOutput);
                obj.updateBeamStatusFrac(beamPathOutput);
                obj.hAO.start();
                if obj.genSampClk
                    obj.hAOSampClk.start();
                end
            end
        end
        
        function restart(obj)
            obj.assertNotActive('method:restart');
            obj.hAO.abort();
            if obj.genSampClk
                obj.hAOSampClk.abort();
            end
            
            if obj.flagOutputNeedsUpdate
                % cannot simply restart, obj.start instead to update AO buffer
                obj.start()
                return;
            end
            
            try
                obj.hAO.start();
                if obj.genSampClk
                    obj.hAOSampClk.start();
                end
            catch ME
                if ~isempty(strfind(ME.message, '200462'))
                    % Warning suppressed. See commit notes.
                    %warning('Output buffer is empty. Cannot restart. Starting a new generation instead');
                    obj.start();
                else
                    rethrow(ME);
                end
            end
        end
        
        function abort(obj)
            try
                obj.hAO.abort();
                obj.hAO.control('DAQmx_Val_Task_Unreserve');
                if obj.genSampClk
                    obj.hAOSampClk.abort();
                end
                obj.updatingOutputNow = false;
            catch ME
                most.idioms.reportError(ME);
            end
        end
        
        function parkOrPointLaser(obj,xy)
            %   ParkOrPointLaser(): parks laser at mdf defined park location (vars state.acq.parkAngleX & state.acq.parkAngleY); closes shutter and turns off beam with Pockels Cell
            %   ParkOrPointLaser(xy): parks laser at user defined location xy, a 2 element vector of optical degree values
            obj.assertNotActive('parkOrPointLaser');
            obj.hLinScan.xGalvo.hDevice.unreserveResource();
            obj.hLinScan.yGalvo.hDevice.unreserveResource();
            
            if nargin < 2 || isempty(xy)
                obj.hLinScan.xGalvo.hDevice.park();
                obj.hLinScan.yGalvo.hDevice.park();
            else
                validateattributes(xy,{'numeric'},{'vector','numel',2});
                obj.hLinScan.xGalvo.hDevice.pointPosition(xy(1));
                obj.hLinScan.yGalvo.hDevice.pointPosition(xy(2));
            end
        end
        
        function centerScanner(obj)
            obj.hLinScan.xGalvo.hDevice.unreserveResource();
            obj.hLinScan.yGalvo.hDevice.unreserveResource();
            obj.hLinScan.xGalvo.hDevice.center();
            obj.hLinScan.yGalvo.hDevice.center();
        end
        
        function resetOffsetVoltage(obj)
            obj.writeOffsetVoltage([0,0]);
        end
        
        function writeOffsetAngle(obj,xyAngle)
            xyVolts = zeros(1,2);
            xyVolts(1) = obj.hLinScan.xGalvo.hDevice.position2OffsetVolts(xyAngle(1));
            xyVolts(2) = obj.hLinScan.yGalvo.hDevice.position2OffsetVolts(xyAngle(2));
            
            obj.writeOffsetVoltage(xyVolts);
        end
        
        function writeOffsetVoltage(obj,xyVoltage)
            if ~isempty(obj.hAOOffset)
                xyVoltage_clamped(1) = max(min(obj.hLinScan.mdfData.XMirrorOffsetMaxVoltage,xyVoltage(1)),-obj.hLinScan.mdfData.XMirrorOffsetMaxVoltage);
                xyVoltage_clamped(2) = max(min(obj.hLinScan.mdfData.YMirrorOffsetMaxVoltage,xyVoltage(2)),-obj.hLinScan.mdfData.YMirrorOffsetMaxVoltage);
                
                if ~isequal(obj.offsetVoltage,xyVoltage_clamped)
                    if obj.offsetUseAsyncWrite
                        obj.writeOffsetVoltageAsync(xyVoltage_clamped); % use an async call for USB-DAQ devices so we don't block the execution
                    else
                        obj.hAOOffset.writeAnalogData(xyVoltage_clamped); % this call is slow (10-15ms) on USB DAQ devices, but relatively fast on PCIe-devices
                    end
                    
                    obj.offsetVoltage = xyVoltage_clamped;
                    if ~isequal(xyVoltage,xyVoltage_clamped)
                        most.idioms.warn('Galvo Offset voltage clamped. Requested: %s, clamped: %s',mat2str(xyVoltage,3),mat2str(xyVoltage_clamped,3));
                    end
                end
            end
        end
        
        function writeOffsetVoltageAsync(obj,xyVoltage)
            % this is to speed up the write call on USB-DAQ devices
            if ~obj.offsetVoltageAsyncLock
                obj.offsetVoltageAsyncLock = true;
                obj.offsetVoltageAsyncNextUpdateVoltage = [];
                obj.hAOOffset.writeAnalogDataAsync(xyVoltage,[],[],[],@obj.writeOffsetVoltageAsyncCallback);
            else
                obj.offsetVoltageAsyncNextUpdateVoltage = xyVoltage;
            end
        end
        
        function writeOffsetVoltageAsyncCallback(obj,src,evt)
            obj.offsetVoltageAsyncLock = false;
            
            if evt.status
                fprintf(2,'Writing Offset voltage encountered an error: %d\n%s\n\n%s\n',evt.status,evt.errorString,evt.extendedErrorInfo);
            end
            
            if ~isempty(obj.offsetVoltageAsyncNextUpdateVoltage)
                obj.writeOffsetVoltageAsync(obj.offsetVoltageAsyncNextUpdateVoltage)
            end
        end
    end
    
    % Getter / Setter Methods for properties
    methods  
        function val = get.active(obj)
            val = ~obj.hAO.isTaskDoneQuiet();
        end
        
        function val = get.startTrigIn(obj)
            startTrigType = get(obj.hAO,'startTrigType');
            
            switch startTrigType
                case 'DAQmx_Val_None';
                    val = '';
                case 'DAQmx_Val_DigEdge';
                    val = get(obj.hAO,'digEdgeStartTrigSrc');
                otherwise
                    assert(false,'Unknown trigger type: %s',startTrigType);
            end
        end
        
        function set.startTrigIn(obj,val)
            obj.assertNotActive('startTrigIn');
            
            switch obj.startTrigEdge
                case 'rising'
                    edge = 'DAQmx_Val_Rising';
                case 'falling'
                    edge = 'DAQmx_Val_Falling';
                otherwise
                    assert(false);
            end
            
            if isempty(val)
                obj.hAO.disableStartTrig();
            else
                obj.hAO.cfgDigEdgeStartTrig(val,edge);
            end
        end
        
        function set.startTrigEdge(obj,val)
            obj.assertNotActive('startTrigEdge');
            assert(ismember(val,{'rising','falling'}));
            obj.startTrigEdge = val;
            obj.startTrigIn = obj.startTrigIn;    
        end
        
        function set.startTrigOut(obj,val)
            obj.assertNotActive('startTrigOut');
            if ~isempty(obj.startTrigOut)
                % disconnect old output terminal
                hDaqSystem = dabs.ni.daqmx.System();
                hDaqSystem.tristateOutputTerm(obj.startTrigOut);
            end
            
            if ~isempty(val)
                % set the new route
                val = qualifyTerminal(val);
                obj.hAO.exportSignal('DAQmx_Val_StartTrigger',val);
            end
            
            obj.startTrigOut = val;
            
            function name = qualifyTerminal(name)
                if ~isempty(name) && isempty(strfind(name,'/'))
                   name = sprintf('/%s/%s',obj.hLinScan.mdfData.deviceNameGalvo,name); 
                end
            end
        end
        
        function set.sampClkSrc(obj,v)
            set(obj.hAOxyb, 'sampClkSrc', v);
            if ~isempty(obj.hAOxybz)
                set(obj.hAOxybz, 'sampClkSrc', v);
            end
        end
        
        function set.sampClkTimebaseSrc(obj,v)
            set(obj.hAOxyb, 'sampClkTimebaseSrc', v);
            if ~isempty(obj.hAOxybz)
                set(obj.hAOxybz, 'sampClkTimebaseSrc', v);
            end
        end
        
        function set.sampClkTimebaseRate(obj,v)
            set(obj.hAOxyb, 'sampClkTimebaseRate', v);
            if ~isempty(obj.hAOxybz)
                set(obj.hAOxybz, 'sampClkTimebaseRate', v);
            end
        end
        
        function set.sampClkRate(obj,v)
            set(obj.hAOxyb, 'sampClkRate', v);
            if ~isempty(obj.hAOxybz)
                set(obj.hAOxybz, 'sampClkRate', v);
            end
        end
        
        function v = get.sampClkRate(obj)
            v = get(obj.hAO, 'sampClkRate');
        end
        
        function v = get.sampClkMaxRate(obj)
            if isempty(obj.hAOxybz)
                v = get(obj.hAOxyb, 'sampClkMaxRate');
            else
                v = get(obj.hAOxybz, 'sampClkMaxRate');
            end
        end
    end
    
    methods (Hidden)
        function streamingBufferNSampCB(obj,~,~)
            obj.samplesGenerated = obj.samplesGenerated + obj.hBeams.nSampCbN;
            obj.framesGenerated = obj.samplesGenerated / obj.hBeams.frameSamps;
            obj.updateAnalogBufferAsync();
        end
        
        function [ao,bpath] = calcJointBuffer(obj, bufStartFrm, nFrames)
            if obj.hBeams.streamingBuffer
                [bao,bpath] = obj.hBeams.calcStreamingBuffer(bufStartFrm, nFrames);
                ao = [repmat(obj.hLinScan.hSI.hWaveformManager.scannerAO.ao_volts.G, nFrames, 1) bao];
                
                if obj.zActive
                    %index out the correct section of z waveform
                    frms = bufStartFrm:(bufStartFrm+nFrames-1);
                    zWvSlices = obj.hSI.hStackManager.zs;
                    zWaveform = obj.hSI.hWaveformManager.scannerAO.ao_volts.Z;
                    zWvSliceSamps = length(zWaveform)/zWvSlices;
                    assert(zWvSliceSamps == floor(zWvSliceSamps), 'Z waveform length is not divisible by number of slices');
                    
                    for ifr = numel(frms):-1:1
                        ss = 1 + (ifr-1)*zWvSliceSamps;
                        es = ifr*zWvSliceSamps;
                        
                        slcInd_0ind = mod(frms(ifr)-1,zWvSlices);
                        aoSs = 1 + slcInd_0ind*zWvSliceSamps;
                        aoEs = (slcInd_0ind+1)*zWvSliceSamps;
                        
                        zAo(ss:es,1) = zWaveform(aoSs:aoEs,:);
                    end
                    
                    ao = [ao zAo];
                end
            else
                if obj.hBeams.enablePowerBox && obj.hBeams.hasPowerBoxes
                    ao = [obj.hLinScan.hSI.hWaveformManager.scannerAO.ao_volts.G obj.hLinScan.hSI.hWaveformManager.scannerAO.ao_volts.Bpb];
                    bpath = obj.hLinScan.hSI.hWaveformManager.scannerAO.pathFOV.Bpb;
                else
                    ao = [obj.hLinScan.hSI.hWaveformManager.scannerAO.ao_volts.G obj.hLinScan.hSI.hWaveformManager.scannerAO.ao_volts.B];
                    bpath = obj.hLinScan.hSI.hWaveformManager.scannerAO.pathFOV.B;
                end
                if obj.zActive
                    ao = [ao obj.hLinScan.hSI.hWaveformManager.scannerAO.ao_volts.Z];
                end
            end
        end
        
        function updateAnalogBufferAsync(obj,restartTask)
            if nargin < 2
                restartTask = false;
            end
            
            if obj.updatingOutputNow && ~restartTask
                obj.flagOutputNeedsUpdate = true;
                return;
            end
            
            if obj.beamShareGalvoDAQ
                if obj.hBeams.streamingBuffer
                    if restartTask
                        obj.samplesGenerated = 0;
                        obj.framesGenerated = 0;
                        obj.samplesWritten = obj.hBeams.streamingBufferSamples;
                        obj.framesWritten = obj.hBeams.streamingBufferFrames;
                        
                        framesToWrite = obj.framesWritten;
                        startFrame = 1;
                    else
                        framesToWrite = obj.hBeams.streamingBufferFrames + obj.framesGenerated - obj.framesWritten;
                        startFrame = obj.framesWritten + 1;
                    end
                    
                    obj.hAO.writeRelativeTo = 'DAQmx_Val_CurrWritePos';
                    obj.hAO.writeOffset = 0;
                    if framesToWrite > 0
                        [waveformOutput,beamPathOutput] = obj.calcJointBuffer(startFrame, framesToWrite);
                    end
                else
                    framesToWrite = 1;
                    [waveformOutput,beamPathOutput] = obj.calcJointBuffer();
                    obj.hAO.writeRelativeTo = 'DAQmx_Val_FirstSample';
                    obj.hAO.writeOffset = 0;
                end
            else
                framesToWrite = 1;
                beamPathOutput = [];
                obj.hAO.writeRelativeTo = 'DAQmx_Val_FirstSample';
                obj.hAO.writeOffset = 0;
                
                waveformOutput  = obj.hLinScan.hSI.hWaveformManager.scannerAO.ao_volts.G;
                if obj.zActive
                    waveformOutput = [waveformOutput obj.hLinScan.hSI.hWaveformManager.scannerAO.ao_volts.Z];
                end
                
                waveformLength_ = size(waveformOutput,1);
                assert(obj.waveformLength == waveformLength_, 'AO generation error. Size of waveforms have changed.');
            end
            
            obj.flagOutputNeedsUpdate = false;
            if framesToWrite > 0
                if restartTask
                    obj.hAO.abort();
                    obj.updateBeamStatusFrac(NaN);
                    obj.hAO.writeAnalogData(waveformOutput);
                else
                    obj.updateBeamStatusFrac(NaN);
                    obj.hAO.writeAnalogDataAsync(waveformOutput,2,[],[],@obj.updateAnalogBufferAsyncCb); % task.writeAnalogData(writeData, timeout, autoStart, numSampsPerChan)
                    obj.updatingOutputNow = true;
                    if obj.beamShareGalvoDAQ
                        obj.updateBeamStatusFrac(beamPathOutput);
                    end
                end
            end
        end
        
        function updateAnalogBufferAsyncCb(obj,~,evt)
            obj.updatingOutputNow = false; % this needs to be the first call in the function in case there are errors below

            if obj.beamShareGalvoDAQ && obj.hBeams.streamingBuffer
                obj.samplesWritten = obj.samplesWritten + evt.sampsWritten;
                obj.framesWritten = obj.samplesWritten / obj.hBeams.frameSamps;
            end
            
            if evt.status ~= 0 && evt.status ~= 200015 && obj.hLinScan.active
                fprintf(2,'Error updating scanner buffer: %s\n%s\n',evt.errorString,evt.extendedErrorInfo);
                
                if obj.bufferUpdatingAsyncRetries < 3 || obj.flagOutputNeedsUpdate
                    obj.bufferUpdatingAsyncRetries = obj.bufferUpdatingAsyncRetries + 1;
                    fprintf(2,'Scanimage will retry update...\n');
                    obj.updateAnalogBufferAsync();
                else
                    obj.bufferUpdatingAsyncRetries = 0;
                end
            else
                obj.bufferUpdatingAsyncRetries = 0;

                if obj.flagOutputNeedsUpdate
                    obj.updateAnalogBufferAsync();
                end
            end
        end
    end
    
    % Helper functions
    methods (Access = private)
        function updateBeamStatusFrac(obj,val)
            if obj.beamShareGalvoDAQ && ~isempty(obj.beamIDs)
                obj.hLinScan.hSI.hBeams.updateBeamStatusFrac(obj.beamIDs,val);
            end
        end
        
        function ziniPrepareTasks(obj)
            beamMDF = obj.hBeams.mdfData;
            linScanMDF = obj.hLinScan.mdfData;
            
            % initialize hAO & hAI tasks
            obj.hAOxyb = most.util.safeCreateTask([obj.hLinScan.name '-ScannerOut']);
            obj.hAOxyb.createAOVoltageChan(linScanMDF.deviceNameGalvo, linScanMDF.XMirrorChannelID, 'XMirrorChannel');
            obj.hAOxyb.createAOVoltageChan(linScanMDF.deviceNameGalvo, linScanMDF.YMirrorChannelID, 'YMirrorChannel');
            get(obj.hAOxyb,'sampClkTimebaseSrc'); % make available for dot notation access
            get(obj.hAOxyb,'sampClkTimebaseRate'); % make available for dot notation access
            
            % initialize extra AO channels for beams if they are on the same DAQ
            obj.beamShareGalvoDAQ = ~isempty(linScanMDF.beamDaqID) && strcmp(beamMDF.beamDaqDevices{linScanMDF.beamDaqID}, linScanMDF.deviceNameGalvo);
            if obj.beamShareGalvoDAQ
                for i = 1:obj.hBeams.daqNumBeams(linScanMDF.beamDaqID)
                    obj.hAOxyb.createAOVoltageChan(linScanMDF.deviceNameGalvo,beamMDF.beamDaqs(linScanMDF.beamDaqID).chanIDs(i),obj.hBeams.displayNames{obj.hBeams.daqBeamIDs{linScanMDF.beamDaqID}(i)});
                end
            end
            
            % initialize extra AO channel for fastz if it is on the same DAQ
            zId = obj.hLinScan.hSI.hFastZ.zScannerId(obj.hLinScan.name);
            if ~isempty(zId)
                zMdf = obj.hLinScan.hSI.hFastZ.mdfData.actuators(zId);
                obj.zShareGalvoDAQ = strcmp(linScanMDF.deviceNameGalvo, zMdf.daqDeviceName);
                if obj.zShareGalvoDAQ
                    obj.hAOxybz = most.util.safeCreateTask([obj.hLinScan.name '-ScannerOutWithZ']);
                    obj.hAOxybz.createAOVoltageChan(linScanMDF.deviceNameGalvo, linScanMDF.XMirrorChannelID, 'XMirrorChannel');
                    obj.hAOxybz.createAOVoltageChan(linScanMDF.deviceNameGalvo, linScanMDF.YMirrorChannelID, 'YMirrorChannel');
                    get(obj.hAOxybz,'sampClkTimebaseSrc'); % make available for dot notation access
                    get(obj.hAOxybz,'sampClkTimebaseRate'); % make available for dot notation access
                    
                    % initialize extra AO channels for beams if they are on the same DAQ
                    if obj.beamShareGalvoDAQ
                        for i = 1:obj.hBeams.daqNumBeams(linScanMDF.beamDaqID)
                            obj.hAOxybz.createAOVoltageChan(linScanMDF.deviceNameGalvo,beamMDF.beamDaqs(linScanMDF.beamDaqID).chanIDs(i),obj.hBeams.displayNames{obj.hBeams.daqBeamIDs{linScanMDF.beamDaqID}(i)});
                        end
                    end
                    
                    % channel for fastz
                    obj.hAOxybz.createAOVoltageChan(zMdf.daqDeviceName, zMdf.cmdOutputChanID, 'FastZChannel');
                end
            end
            
            %create sample clock task if acq and ctrl are on same board but not aux board
            if strcmp(linScanMDF.deviceNameAcq,linScanMDF.deviceNameGalvo) && ~strcmp(linScanMDF.deviceNameGalvo,linScanMDF.deviceNameAux)
                obj.hAOSampClk = most.util.safeCreateTask([obj.hLinScan.name '-AOSampClk']);
                obj.hAOSampClk.createCOPulseChanFreq(linScanMDF.deviceNameGalvo, 1, [obj.hLinScan.name '-AOSampClkChan'], 500e3);
                obj.hAOSampClk.cfgImplicitTiming('DAQmx_Val_ContSamps');
                obj.hAOSampClk.channels(1).set('ctrTimebaseSrc','ai/SampleClock');
                obj.hAOSampClk.channels(1).set('pulseTerm','');
            end
            
            % preliminary sample rate
            obj.hAOxyb.cfgSampClkTiming(obj.hAOxyb.get('sampClkMaxRate'), 'DAQmx_Val_FiniteSamps');
            get(obj.hAOxyb, 'writeRelativeTo');
            get(obj.hAOxyb, 'writeOffset');
            
            if ~isempty(obj.hAOxybz)
                obj.hAOxybz.cfgSampClkTiming(obj.hAOxybz.get('sampClkMaxRate'), 'DAQmx_Val_FiniteSamps');
                get(obj.hAOxybz, 'writeRelativeTo');
                get(obj.hAOxybz, 'writeOffset');
            end
            
            obj.hAO = obj.hAOxyb;
            
            % initialize offset task
            if ~isempty(linScanMDF.deviceNameOffset)
                obj.hAOOffset = most.util.safeCreateTask([obj.hLinScan.name '-ScannerOffsetOut']);
                obj.hAOOffset.createAOVoltageChan(linScanMDF.deviceNameOffset, linScanMDF.XMirrorOffsetChannelID, 'XMirrorOffsetChannel');
                obj.hAOOffset.createAOVoltageChan(linScanMDF.deviceNameOffset, linScanMDF.YMirrorOffsetChannelID, 'YMirrorOffsetChannel');
                hDev = dabs.ni.daqmx.Device(linScanMDF.deviceNameOffset);
                obj.offsetUseAsyncWrite = strcmpi(hDev.get('busType'),'DAQmx_Val_USB');
                obj.resetOffsetVoltage();
            end
        end

        function assertNotActive(obj,propName)
            assert(~obj.active,'Cannot access %s during an active acquisition',propName);
        end
    end
end


%--------------------------------------------------------------------------%
% Control.m                                                                %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
