classdef Acquisition < scanimage.interfaces.Class
    % Lightweight class enabling acquisition for SlmScan
    
    properties (SetAccess = private, Hidden)
        hSlmScan;                   % handle to Scan2D object
        hAI;                        % analog input task to read PMT data
        isFpga;                     % indicates if hAI refers to a RIO device
        acqDevType;                 % product category of DAQmx device                 
        acqParamBuffer;             % buffer for acquisition parameters
        counters;                   % internal counters updated during acquisition
        sampleAcquisitionTimer;     % timer to acquire individual lines
        lastStripeData;             % buffer that holds last acquired stripe
        active = false;             % indicates if acquisition is active
        lastSlmUpdate = tic();      % last time SLM was updated
        hFpga;
    end
    
    %% Lifecycle
    methods
        function obj = Acquisition(hSlmScan)
            obj.hSlmScan = hSlmScan;
            
            %%% Initialize hAI object
            dev = obj.hSlmScan.mdfData.deviceNameAcq;
            if strncmp(dev, 'RIO', 3) && ~isnan(str2double(dev(4:end)))
                %this is an fpga!
                obj.isFpga = true;
                obj.hAI = scanimage.components.scan2d.linscan.DataStream('fpga');
                obj.hAI.simulated = obj.hSlmScan.simulated;
                
                if obj.hSlmScan.mdfData.secondaryFpgaFifo
                    fifoName = 'fifo_LinScanMultiChannelToHostU64';
                else
                    fifoName = 'fifo_MultiChannelToHostU64';
                end
                
                if obj.hSlmScan.hSI.fpgaMap.isKey(dev)
                    hF = obj.hSlmScan.hSI.fpgaMap(dev);
                    obj.hAI.setFpgaAndFifo(hF.digitizerType, hF.hFpga.(fifoName), obj.hSlmScan.mdfData.secondaryFpgaFifo);
                else
                    % Determine bitfile name
                    fpgaType = obj.hSlmScan.mdfData.fpgaModuleType;
                    digitizerType = obj.hSlmScan.mdfData.digitizerModuleType;
                    
                    pathToBitfile = [fileparts(which('scanimage')) '\+scanimage\FPGA\FPGA Bitfiles\Microscopy'];
                    
                    if ~isempty(fpgaType)
                        pathToBitfile = [pathToBitfile ' ' fpgaType];
                    end
                    
                    if ~isempty(digitizerType)
                        pathToBitfile = [pathToBitfile ' ' digitizerType];
                    end
                    
                    pathToBitfile = [pathToBitfile '.lvbitx'];
                    assert(logical(exist(pathToBitfile, 'file')), 'The FPGA and digitizer combination specified in the machine data file is not currently supported.');
                    
                    if strncmp(fpgaType, 'NI517', 5)
                        dabs.ni.oscope.clearSession;
                        err = dabs.ni.oscope.startSession(dev,pathToBitfile);
                        assert(err == 0, 'Error when attempting to connect to NI 517x device. Code = %d', err);
                        dabs.ni.oscope.configureSampleClock(false,0);
                        digitizerType = 'NI517x';
                    end
                    
                    hFpga = scanimage.fpga.flexRio_SI(pathToBitfile,obj.hSlmScan.simulated);
                    
                    if (~obj.hSlmScan.simulated)
                        try
                            hFpga.openSession(dev);
                        catch ME
                            error('Scanimage:Acquisition',['Failed to start FPGA. Ensure the FPGA and digitizer module settings in the machine data file match the hardware.\n' ME.message]);
                        end
                    end
                    
                    obj.hSlmScan.hSI.fpgaMap(dev) = struct('hFpga',hFpga,'fpgaType',fpgaType,'digitizerType',digitizerType,'bitfilePath',pathToBitfile);
                    obj.hAI.setFpgaAndFifo(digitizerType, hFpga.(fifoName), obj.hSlmScan.mdfData.secondaryFpgaFifo);
                    obj.createdFpga = true;
                end
                obj.hFpga = obj.hAI.hFpga;
            else
                hDev = dabs.ni.daqmx.Device(obj.hSlmScan.mdfData.deviceNameAcq);
                obj.acqDevType = hDev.productCategory;
                
                obj.hAI = scanimage.components.scan2d.linscan.DataStream('daq');
                
                obj.hAI.hTask = most.util.safeCreateTask([obj.hSlmScan.name '-AnalogInput']);
                obj.hAI.hTaskOnDemand = most.util.safeCreateTask([obj.hSlmScan.name '-AnalogInputOnDemand']);
                
                % make sure not more channels are created then there are channels available on the device
                for i=1:obj.hAI.getNumAvailChans(min([obj.hSlmScan.MAX_NUM_CHANNELS numel(obj.hSlmScan.mdfData.channelIDs)]),obj.hSlmScan.mdfData.deviceNameAcq,false)
                    obj.hAI.hTask.createAIVoltageChan(obj.hSlmScan.mdfData.deviceNameAcq,obj.hSlmScan.mdfData.channelIDs(i),sprintf('Imaging-%.2d',i-1),-1,1);
                    obj.hAI.hTaskOnDemand.createAIVoltageChan(obj.hSlmScan.mdfData.deviceNameAcq,obj.hSlmScan.mdfData.channelIDs(i),sprintf('ImagingOnDemand-%.2d',i-1));
                end
                
                % preliminary sample clock configuration
                obj.hAI.hTask.cfgSampClkTiming(10000,'DAQmx_Val_ContSamps');
            end
            
            obj.clearAcqParamBuffer();
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hAI);
        end
    end
    
    methods (Hidden)
        function start(obj)
            assert(~obj.active);
            obj.bufferAcqParams();
            obj.resetCounters();
            obj.active = true;
            
            if obj.hSlmScan.hardwareTimedAcquisition
                registerCallback = false;
                obj.hAI.configureStream(registerCallback);
                obj.hAI.start();
            end
        end
        
        function trigIssueSoftwareAcq(obj)
            assert(obj.active);
            obj.acquisitionLoop();
        end
        
        function abort(obj)
            obj.active = false;
            obj.hAI.abort();
            obj.hAI.unreserve();
        end
        
        function acquisitionLoop(obj)
            lastDrawnow = tic();
            drawNowEveryNSeconds = 0.5;
            sfInfo = obj.acqParamBuffer.sfInfo;
            
            while true
                % prepare buffer for line
                data = zeros(sfInfo.pixelResolutionXY(1),obj.hAI.numChannels,obj.hSlmScan.channelsDataType);
                
                for idx = 1:sfInfo.pixelResolutionXY(1)
                    if toc(lastDrawnow) >= drawNowEveryNSeconds
                        % this is to ensure that ScanImage does not completely
                        % lock up during an acquisition
                        lastDrawnow = tic();
                        drawnow();
                    end
                    
                    if ~obj.active
                        return % check if acquisition was aborted
                    end
                    
                    obj.counters.currentSfSample = obj.counters.currentSfSample + 1;
                    obj.slmPointToSample(obj.counters.currentSfSample+obj.hSlmScan.linePhase); % point SLM to next sample
                    
                    if ~obj.hSlmScan.hardwareTimedAcquisition
                        averageNSamples = 10;
                        d = obj.acquireSamples(averageNSamples);
                        data(idx,:) = cast(mean(d,1),'like',d);
                    end
                end
                
                if obj.hSlmScan.hardwareTimedAcquisition
                    try
                        data = obj.hAI.read(sfInfo.pixelResolutionXY(1));
                    catch ME
                        if ~isempty(strfind(ME.message,'-50400')) || ~isempty(strfind(ME.message,'-200284'))
                            obj.hSlmScan.hSI.abort();
                            error('SlmScan: Timeout when waiting for PMT samples. Ensure the digitizer is receiving the SLM update trigger');
                        else
                            rethrow(ME);
                        end
                    end
                    sign_ = obj.acqParamBuffer.channelsSign;
                    sign_(end+1:size(data,2)) = 1;
                    data = bsxfun(@times,data,sign_);
                end
                
                data = data(:,obj.acqParamBuffer.channelsActive);
                [I,J] = ind2sub(size(sfInfo.buffer),mod(obj.counters.currentSfSample-1,sfInfo.totalSamples)+1);
                obj.acqParamBuffer.sfInfo.buffer(:,J,:) = data;
                
                % end of line
                
                if obj.acqParamBuffer.bidirectional && mod(obj.counters.currentSfLine,2) == 0
                    obj.acqParamBuffer.sfInfo.buffer(:,J,:) = flip(obj.acqParamBuffer.sfInfo.buffer(:,J,:),1);
                end
                obj.lastStripeData = obj.formStripeData(obj.acqParamBuffer.sfInfo,obj.counters.currentSfLine,sfInfo.zs(obj.counters.currentZIdx));
                obj.counters.currentSfLine = obj.counters.currentSfLine+1;
                
                if ~obj.active
                    return % check if acquisition was aborted
                end
                % callback after every line
                obj.hSlmScan.hLog.logStripe(obj.lastStripeData);
                obj.hSlmScan.stripeAcquiredCallback(obj.hSlmScan,[]);
                
                lastDrawnow = tic();
                drawnow(); % refresh display and process callbacks
                
                if mod(obj.counters.currentSfSample,sfInfo.totalSamples)==0
                    if obj.counters.currentSfSample >= size(obj.acqParamBuffer.waveformOutputPoints,1)
                        obj.counters.currentSfSample = 0;
                    end
                    obj.counters.currentSfLine = 1;
                    obj.counters.currentZIdx = mod(obj.counters.currentZIdx+1-1,length(sfInfo.zs))+1;
                    
                    if obj.counters.currentFrameCounter == obj.hSlmScan.framesPerAcq
                        obj.hSlmScan.abort();
                    else
                        obj.counters.currentFrameCounter = obj.counters.currentFrameCounter + 1;
                    end
                end
            end
        end
        
        function data = acquireSamples(obj,numSamples)
            if nargin < 2 || isempty(numSamples)
                numSamples = 1;
            end
            
            data = obj.hAI.acquireSamples(numSamples);
                    
            channelsSign = 1 - 2*obj.hSlmScan.mdfData.channelsInvert; % -1 for obj.mdfData.channelsInvert == true, 1 for obj.mdfDatachannelsInvert == false
            channelsSign(end+1:size(data,2)) = 1;
            channelsSign = cast(channelsSign,'like',data);
            data = bsxfun(@times,data,channelsSign);
        end        
        
        function [success, stripeData] = readStripeData(obj)
            success = ~isempty(obj.lastStripeData);
            stripeData = obj.lastStripeData;
            obj.lastStripeData = [];
        end
    end
    
    
    %% Internal Methods
    methods (Hidden)        
        function clearAcqParamBuffer(obj)
            obj.acqParamBuffer = struct();
        end
        
        function updateBufferedOffsets(obj)
            if ~isempty(obj.acqParamBuffer)
                tmpValA = cast(obj.hSlmScan.hSI.hChannels.channelOffset(obj.acqParamBuffer.channelsActive),obj.hSlmScan.channelsDataType);
                tmpValB = cast(obj.hSlmScan.hSI.hChannels.channelSubtractOffset(obj.acqParamBuffer.channelsActive),obj.hSlmScan.channelsDataType);
                channelsOffset = tmpValA .* tmpValB;
                obj.acqParamBuffer.channelsOffset = channelsOffset;
            end
        end
        
        function bufferAcqParams(obj)
            obj.acqParamBuffer = struct(); % flush buffer
            
            obj.acqParamBuffer.channelsActive = obj.hSlmScan.hSI.hChannels.channelsActive;
            obj.acqParamBuffer.channelsSign = cast(1 - 2*obj.hSlmScan.mdfData.channelsInvert(obj.acqParamBuffer.channelsActive),obj.hSlmScan.channelsDataType); % -1 for obj.mdfData.channelsInvert == true, 1 for obj.mdfDatachannelsInvert == false
            obj.acqParamBuffer.channelsSign(end+1:obj.hAI.numChannels) = 1;
            obj.acqParamBuffer.waveformOutputPoints = obj.hSlmScan.hSI.hWaveformManager.scannerAO.ao_volts.SLMxyz;
            obj.acqParamBuffer.bidirectional = obj.hSlmScan.hSlm.bidirectionalScan;
            obj.acqParamBuffer.dataType = obj.hSlmScan.channelsDataType;
            
            obj.bufferAllSfParams();
            obj.updateBufferedOffsets();
        end
        
        function resetCounters(obj)
            obj.counters = struct();
            obj.counters.currentSfLine = 1;
            obj.counters.currentZIdx = 1;
            obj.counters.currentSfSample = 0;
            obj.counters.currentFrameCounter = 1;
        end
        
        function zs = bufferAllSfParams(obj)
            roiGroup = obj.hSlmScan.currentRoiGroup;
            assert(length(obj.hSlmScan.currentRoiGroup.rois)==1,'Multi ROI imaging with SLM is currently unsupported');
            assert(length(obj.hSlmScan.currentRoiGroup.rois(1).scanfields)==1,'Multi ROI imaging with SLM is currently unsupported');
            
            % generate slices to scan based on motor position etc
            if obj.hSlmScan.hSI.hStackManager.isSlowZ
                zs = obj.hSlmScan.hSI.hStackManager.zs(obj.hSlmScan.hSI.hStackManager.stackSlicesDone+1);
            else
                zs = obj.hSlmScan.hSI.hStackManager.zs;
            end
            obj.acqParamBuffer.zs = zs;
            
            [scanFields,rois] = roiGroup.scanFieldsAtZ(zs(1));    
            sf = scanFields{1};
            roi = rois{1};
            
            sfInfo = struct();
            sfInfo.scanfield         = sf;
            sfInfo.roi               = roi;
            sfInfo.pixelResolutionXY = sf.pixelResolutionXY;
            sfInfo.totalSamples      = prod(sf.pixelResolutionXY);
            sfInfo.zs                = zs;
            sfInfo.buffer = zeros([sf.pixelResolutionXY,numel(obj.acqParamBuffer.channelsActive)],obj.acqParamBuffer.dataType); % transposed
            
            obj.acqParamBuffer.sfInfo = sfInfo;
        end
        
        function slmPointToSample(obj,sampleNumber)            
            sampleNumber = mod(sampleNumber-1,size(obj.acqParamBuffer.waveformOutputPoints,1))+1;
            currentPoint = obj.acqParamBuffer.waveformOutputPoints(sampleNumber,:);
            obj.hSlmScan.pointSlmRaw(currentPoint);
            
            while toc(obj.lastSlmUpdate) < 1/obj.hSlmScan.sampleRate
                % tight loop
                % don't use pause here, since the timing is not precise enough
            end
            obj.lastSlmUpdate = tic();
        end
        
        function stripeData = formStripeData(obj,sfInfo,lineNumber,z)
            stripeData = scanimage.interfaces.StripeData();
            
            stripeData.frameNumberAcqMode = obj.counters.currentFrameCounter;
            stripeData.frameNumberAcq = obj.counters.currentFrameCounter;
            stripeData.acqNumber = 1;               % numeric, number of current acquisition
            stripeData.stripeNumber = lineNumber;   % numeric, number of stripe within the frame
            stripeData.stripesRemaining = 0;
            
            stripeData.startOfFrame = lineNumber==1;% logical, true if first stripe of frame
            stripeData.endOfFrame   = lineNumber==sfInfo.pixelResolutionXY(2); % logical, true if last stripe of frame
            stripeData.endOfAcquisition = stripeData.endOfFrame && (mod(obj.counters.currentFrameCounter,obj.hSlmScan.framesPerAcq)==0); % logical, true if endOfFrame and last frame of acquisition            
            stripeData.endOfAcquisitionMode = stripeData.endOfAcquisition && obj.counters.currentFrameCounter/obj.hSlmScan.framesPerAcq >= obj.hSlmScan.trigAcqNumRepeats; % logical, true if endOfFrame and end of acquisition mode
            stripeData.startOfVolume = false;       % logical, true if start of volume
            stripeData.endOfVolume = false;         % logical, true if start of volume
            stripeData.overvoltage = false;
            
            stripeData.epochAcqMode;                % string, time of the acquisition of the acquisiton of the first pixel in the current acqMode; format: output of datestr(now) '25-Jul-2014 12:55:21'
            stripeData.frameTimestamp;              % [s] time of the first pixel in the frame passed since acqModeEpoch
            
            stripeData.acqStartTriggerTimestamp;
            stripeData.nextFileMarkerTimestamp;
            
            stripeData.channelNumbers = 1;          % 1D array of active channel numbers for the current acquisition
            stripeData.rawData;                     % Raw data samples
            stripeData.rawDataStripePosition;       % Raw data samples start position
            stripeData.roiData{1} = formRoiData();  % 1D cell array of type scanimage.mroi.RoiData
            stripeData.transposed = true;
            
            function roiData = formRoiData()
                roiData = scanimage.mroi.RoiData;
                
                roiData.hRoi = sfInfo.roi;          % handle to roi
                roiData.zs = z;                     % [numeric] array of zs
                roiData.channels = obj.acqParamBuffer.channelsActive;  % [numeric] array of channelnumbers in imageData
                
                roiData.imageData = cell(0,1);
                for idx = 1:length(obj.acqParamBuffer.channelsActive)
                    roiData.imageData{idx}{1} = sfInfo.buffer(:,:,idx) + obj.acqParamBuffer.channelsOffset(idx);
                end
                
                roiData.stripePosition= {[lineNumber lineNumber]}; % cell array of 1x2 start and end line of the current stripe for each z. if empty, current stripe is full frame
                roiData.stripeFullFrameNumLines = [];   % stripeFullFrameNumLines indicates the number of lines in the full frame for each z
                
                roiData.transposed = true;
                roiData.frameNumberAcq = stripeData.frameNumberAcq;
                roiData.frameNumberAcqMode = stripeData.frameNumberAcqMode;
                roiData.frameTimestamp = stripeData.frameTimestamp;
            end
        end
    end    
end

%--------------------------------------------------------------------------%
% Acquisition.m                                                            %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
