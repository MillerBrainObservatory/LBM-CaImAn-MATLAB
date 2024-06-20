classdef Acquisition < scanimage.interfaces.Class
    
    %% FRIEND  PROPS    
    
    %%% Key knobs for Acquisition functionality
    properties (Hidden, Access={?scanimage.interfaces.Class})        
        frameAcquiredFcn;           % Callback function to be executed when a frame is acquired
    end
    
    %%% Knobs for optional modulation of Acquisition functionality
    properties (Hidden)
        frameTagging = true;        % Activates frame tagging (now always active - 4/21/14); MEX code relies on frameTagging = true (4/16/2015)
        reverseLineRead = false;    % flip the image horizontally
        channelsInvert = false;     % specifies if the digitizer inverts the channel values
        recordFirstSampleDelay = false; % indicates that the last pixel written in a line is the delay from when the line acquisition started to the when the first sample arrived
        
        simulatedFramePeriod = 33;  % Frame Period (in ms) at which to issue frames in simulated mode.
        
        pixelsPerLine = 512;
        linesPerFrame = 512;
        flybackLinesPerFrame = 16;
        
        xResolutionNumerator;
		xResolutionDenominator;
		yResolutionNumerator;
		yResolutionDenominator;
        
        simulateFrameData = false;
        roiDataPack = [];
        simNoise = 0;
        simDataSourceFrames;
        simDataSourceRect;
        
        enableSampleReplacement = false;
    end
    
    %%% Knobs for testing/debug
    properties (Hidden)
        simulated=false;
        debugOutput = false;        
        dummyData = false;
        enableBenchmark = false;
        benchmarkData;
        framesProcessed = 0;
    end
    
    %%% Flag props for use by external classes to schedule or defer Resize and Mask computations, respectively
    properties  (Hidden, Access={?scanimage.interfaces.Class}, AbortSet)      
        flagResizeAcquisition = true; % After startup the frame copier needs to be initialized 
    end
    
    %%% Read-only props
    properties (Hidden, SetAccess=private, Dependent)
        adapterModuleChannelCount;
        rawAdcOutput;                % returns up-to-date Adc data without processing. can be queried at any time
        
        periodsPerFrame;
    end
        
    %% INTERNAL PROPS
    
    %Immutable props
    properties (Hidden,SetAccess = immutable)
        hScan;
        hFpga;
        
        fpgaFifoNumberMultiChan;
        fpgaFifoNumberAuxData;
        fpgaSystemTimerLoopCountRegister;
        
        hTimerContinuousFreqMeasurement;
        
        flexRioAdapterModuleName;
    end
    
    properties (Hidden, Dependent)
        flexRioAdapterModuleNameWithAppendix;
    end

    properties (Hidden, SetAccess = private)  
        acqRunning = false;
        
        framesAcquired = 0;                     % total number of frames acquired in the acquisition mode
        acqCounter = 0;                         % number of acqs acquired
        lastEndOfAcquisition = 0;               % total frame number when the last end of acquisition flag was received
        epochAcqMode = [];                      % string, time of the acquisition of the acquisiton of the first pixel in the current acqMode; format: output of datestr(now) '25-Jul-2014 12:55:21'
        
        tagSizeFifoElements;                    % Number of FIFO elements for the tag (0 for frameTagging == 0)
                
        flagUpdateMask = true;                  % After startup the mask needs to be sent to the FPGA
        
		acqParamBuffer = struct();              % buffer holding frequently used parameters to limit parameter recomputation
        
        externalSampleClock = false;            % indicates if external/internal sample rate is used
        wasEverExternallyClocked = false;
        
        mexInit = false;
        AMCmdSent = false;
        
        stateMachineLoopRate = 0;
        fpgaLoopRate;
        sampleRateAcq = 0;
        rawSampleRateAcq = 0;
    end
    
    properties (Hidden, Dependent)
        scanFrameRate;               % number of frames per second
        dataRate;                    % the theoretical dataRate produced by the acquisition in MB/s
        dcOvervoltage;               % true if input voltage range is exceeded. indicates that coupling changed to AC to protect ADC        
        
        estimatedPeriodClockDelay;   % delays the start of the acquisition relative to the period trigger to compensate for line fillfractionSpatial < 1
        
        loggingEnable;               % accessed by MEX function
        channelsActive;              % accessed by MEX function
        channelsDisplay;             % accessed by MEX function
        channelsSave;                % accessed by MEX function
        channelsDisplayArrayPointer; % accessed by MEX function
        channelsSaveArrayPointer;    % accessed by MEX function
        firstSampleDelayEnable;        % accessed by MEX function
    end
    
    %%% Dependent properties computing values needed to pass onto FPGA API
    properties (Hidden, Dependent)
        linePhaseSamples;
        triggerHoldOff;
        beamTiming;        
        
        auxTriggersEnable;          % accessed by MEX
        
        I2CEnable;                  % accessed by MEX
        I2C_STORE_AS_CHAR;          % accessed by MEX
    end    
    
    %%% Properties made available to MEX interface, e.g. for logging and/or frame copy threads
    properties (Hidden, SetAccess = private)
        frameSizePixels;         %Number of Pixels in one frame (not including frame tag)
        dataSizeBytes;            %Number of Bytes in one packed frame (multiple channels + padding)
        packageSizeBytes;         %Number of FIFO elements for one frame (frame + optional frame tag)
        packageSizeFifoElements;  %Number of FIFO elements for one frame (frame + optional frame tag)
        interlacedNumChannels;    %Number of packed channels
        
        fpgaFifoAuxDataActualDepth; %Number of elements the aux trigger can hold. Can differ from FIFO_ELEMENT_SIZE_AUX_TRIGGERS
    end
    
    %%% Mask params
    properties (Hidden, SetAccess=private)
        mask; %Array specifies samples per pixel for each resonant scanner period
        maskParams; %struct of params pertaining to mask        
    end
    
    properties (Hidden,Dependent)
        fifoSizeFrames;                     %number of frames the DMA FIFO can hold; derived from fifoSizeSeconds
        
        %name constant; accessed by MEX interface
        frameQueueLoggerCapacity;           %number of frames the logging frame queue can hold; derived from frameQueueSizeSeconds
        frameQueueMatlabCapacity;           %number of frames the matlab frame queue can hold; derived from frameQueueLoggerCapacity and framesPerStack
    end

    
    %% CONSTANTS
    properties (Hidden, Constant)
        ADAPTER_MODULE_MAP = containers.Map({278099318,278099319,278099349,278099186,278099316,278099669},{'NI5732','NI5733','NI5734','NI5751','NI5771','NI5772'});
        ADAPTER_MODULE_RAW_SAMPLING_RATE_MAP = containers.Map({'NI5732','NI5733','NI5734','NI5751','NI517x','NI5771','NI5771 (Time Demux)','NI5772'},{80e6,120e6,120e6,50e6,250e6,1.5e9,1.5e9,0.8e9});
        FPGA_STATE_MACHINE_LOOP_RATE = containers.Map({'NI5732','NI5733','NI5734','NI5751','NI517x','NI5771','NI5771 (Time Demux)','NI5772'},{[],[],[],[],[],100e6,100e6,80e6});
        FPGA_RAW_ACQ_LOOP_ITERATIONS_COUNT_FACTOR = containers.Map({'NI5732','NI5733','NI5734','NI5751','NI517x','NI5771','NI5771 (Time Demux)','NI5772'},{1,1,1,1,2,8,8,4});
        FPGA_RAW_SAMPLE_RATE_TO_SAMPLE_RATE_FACTOR = containers.Map({'NI5732','NI5733','NI5734','NI5751','NI517x','NI5771','NI5771 (Time Demux)','NI5772'},{1,1,1,1,2,[],[],[]});
        ADAPTER_MODULE_SAMPLING_RATE_RANGE_MAP = containers.Map({'NI5732','NI5733','NI5734','NI5751','NI517x','NI5771','NI5771 (Time Demux)','NI5772'},{[20e6 80e6],[50e6 120e6],[50e6 120e6],[50e6 50e6],[20e6 125e6],[850e6 1.5e9],[850e6 1.5e9],[400e6 800e9]});
        ADAPTER_MODULE_TRIGGER_TO_ADC_DELAY = containers.Map({'NI5732','NI5733','NI5734','NI5751','NI517x','NI5771','NI5771 (Time Demux)','NI5772'},{16,16,16,0,0,0,0,0}); % TODO: Evaluate trigger delay for NI5751 and NI517x
        ADAPTER_MODULE_ADC_BIT_DEPTH = containers.Map({'NI5732','NI5733','NI5734','NI5751','NI517x','NI5771','NI5771 (Time Demux)','NI5772'},{14,16,16,14,14,12,16,16});
        ADAPTER_MODULE_AVAIL_INPUT_RANGES = containers.Map({'NI5732','NI5733','NI5734','NI5751','NI517x','NI5771','NI5771 (Time Demux)','NI5772'},{[1,0.5,0.25],[1,0.5,0.25],[1,0.5,0.25],[1,0.5,0.25],[2.5,1,0.5,0.1],[1],[1],[1]});
        
        FPGA_MEASURE_SLOW_TRIGGER_RATE = containers.Map({'NI5732','NI5733','NI5734','NI5751','NI517x','NI5771','NI5771 (Time Demux)','NI5772'},{0,0,0,0,0,0,0,1});
        FPGA_SET_TIS = containers.Map({'NI5732','NI5733','NI5734','NI5751','NI517x','NI5771','NI5771 (Time Demux)','NI5772'},{[],[],[],[],[],0,0,1});
        FPGA_MAX_SUPPORTED_INTERLACE = containers.Map({'NI5732','NI5733','NI5734','NI5751','NI517x','NI5771','NI5771 (Time Demux)','NI5772'},{4,4,4,4,4,4,16,32});
        
        FRAME_TAG_SIZE_BYTES = 32;
        
        FPGA_SYS_CLOCK_RATE = 200e6;        %Hard coded on FPGA[Hz]
        
        TRIGGER_HEAD_PROPERTIES = {'triggerClockTimeFirst' 'triggerTime' 'triggerFrameStartTime' 'triggerFrameNumber'};
        CHANNELS_INPUT_RANGES = {[-1 1] [-.5 .5] [-.25 .25]};
        
        HW_DETECT_POLLING_INTERVAL = 0.1;   %Hardware detection polling interval time (in seconds)
        HW_DETECT_TIMEOUT = 5;              %Hardware detection timeout (in seconds)
        HW_POLLING_INTERVAL = 0.01;         %Hardware polling interval time (in seconds)
        HW_TIMEOUT = 5;                     %Hardware timeout (in seconds)

        FIFO_SIZE_SECONDS = 1;              %time worth of frame data the DMA Fifo can hold
        FIFO_SIZE_LIMIT_MB = 250;           %limit of DMA FIFO size in MB
        FIFO_ELEMENT_SIZE_BYTES_MULTI_CHAN = 8;  % uint64
        FIFO_ELEMENT_SIZE_BYTES_SINGLE_CHAN = 2; % int16
        PIXEL_SIZE_BYTES = 2;  % int16, also defined in NIFPGAMexTypes.h as pixel_t;
        
        FRAME_QUEUE_LOGGER_SIZE_SECONDS = 1;     %time worth of frame data the logger frame queue can hold
        FRAME_QUEUE_LOGGER_SIZE_LIMIT_MB = 250;  %limit of logger frame queue size in MB
        
        FRAME_QUEUE_MATLAB_SIZE_SECONDS = 0.3;   %time worth of frame data the matlab frame queue can hold
        FRAME_QUEUE_MATLAB_SIZE_LIMIT_MB = 250;  %limit of matlab frame queue size in MB
        
        FIFO_ELEMENT_SIZE_AUX_DATA = 1000; % number of aux data elements each frame can store (one element is 8bytes)
         
        LOG_TIFF_IMAGE_DESCRIPTION_SIZE = 2000;   % (number of characters) the length of the Tiff Header Image Description
        MEX_SEND_EVENTS = true;
        
        SYNC_DISPLAY_TO_VOLUME_RATE = true; % ensure that all consecutive slices within one volume are transferred from Framecopier. drop volumes instead of frames
    end
    
    %% Lifecycle
    methods
        function obj = Acquisition(hScan,simulated)
            if nargin < 1 || isempty(hScan) || ~isvalid(hScan)
                hScan = [];
            end
            
            if nargin < 2 || isempty(simulated)
                obj.simulated = hScan.simulated;
            else
                obj.simulated = simulated;
            end
            
            obj.hScan = hScan;
            
            obj.dispDbgMsg('Initializing Object & Opening FPGA session');
            
            res = obj.hScan.mdfData.rioDeviceID;
            if obj.hScan.hSI.fpgaMap.isKey(res)
                obj.hFpga = obj.hScan.hSI.fpgaMap(res).hFpga;
            else
                % Determine bitfile name
                fpgaType = obj.hScan.mdfData.fpgaModuleType;
                digitizerType = obj.hScan.mdfData.digitizerModuleType;
                customSigCondOption = obj.hScan.mdfData.customSigCondOption;
                
                pathToBitfile = [fileparts(which('scanimage')) '\+scanimage\FPGA\FPGA Bitfiles\Microscopy'];
                
                if ~isempty(fpgaType)
                    pathToBitfile = [pathToBitfile ' ' fpgaType];
                end
                
                if ~isempty(digitizerType)
                    pathToBitfile = [pathToBitfile ' ' digitizerType];
                end
                
                if ~isempty(customSigCondOption)
                    pathToBitfile = [pathToBitfile ' (' customSigCondOption ')'];
                end
                
                pathToBitfile = [pathToBitfile '.lvbitx'];
                assert(logical(exist(pathToBitfile, 'file')), 'The FPGA and digitizer combination specified in the machine data file is not currently supported.\n(Bitfile: %s)',pathToBitfile);
                
                if strncmp(fpgaType, 'NI517', 5)
                    dabs.ni.oscope.clearSession;
                    err = dabs.ni.oscope.startSession(res,pathToBitfile);
                    assert(err == 0, 'Error when attempting to connect to NI 517x device. Code = %d', err);
                end
                
                obj.hFpga = scanimage.fpga.flexRio_SI(pathToBitfile,obj.simulated);
                
                if (~obj.simulated)
                    try
                        obj.hFpga.openSession(res);
                    catch ME
                        error('Scanimage:Acquisition',['Failed to start FPGA. Ensure the FPGA and digitizer module settings in the machine data file match the hardware.\n' ME.message]);
                    end
                end
                
                obj.hScan.hSI.fpgaMap(res) = struct('hFpga',obj.hFpga,'fpgaType',fpgaType,'digitizerType',digitizerType,'bitfilePath',pathToBitfile);
            end
            
            assert(isprop(obj.hFpga,'fifo_MultiChannelToHostU64') ...
                && isprop(obj.hFpga,'fifo_AuxDataToHostU64'), ...
                'Expected FIFO objects not found for loaded FPGA module bitfile');
            
            %Hard-Reset FPGA. This brings the FPGA in a known state after an aborted acquisition
            obj.fpgaReset();
            
            obj.flexRioAdapterModuleName = obj.fpgaDetectAdapterModule();
            obj.hFpga.adapterModuleName = obj.flexRioAdapterModuleName;
            
            obj.hScan.zprvMDFVerify('externalSampleClock',{{'logical'},{'scalar','nonempty'}},[]);
            if obj.hScan.mdfData.externalSampleClock
                sampleClockMode = 'external';
            else
                sampleClockMode = 'internal';
            end
            
            obj.configureAdapterModuleSampleClock(sampleClockMode);
            obj.hFpga.resetDcOvervoltage(); % configure for DC coupling
            
            %Store FPGA device FIFO names. The names of the FIFO are parsed
            %from the bitfile, so they can change when the FPGA code is
            %modified. Storing the parameters here enables us to change the
            %names in Matlab without having to recompile the MEXfunction
            obj.fpgaFifoNumberMultiChan   = obj.hFpga.fifo_MultiChannelToHostU64.fifoNumber;
            obj.fpgaFifoNumberAuxData = obj.hFpga.fifo_AuxDataToHostU64.fifoNumber;
            registerSysTimeProps = obj.hFpga.registerMap('SystemTimerLoopCount');
            obj.fpgaSystemTimerLoopCountRegister = registerSysTimeProps.offset;
            
            obj.hTimerContinuousFreqMeasurement = timer('Name','TimerContinuousFreqMeasurement','Period',1,'BusyMode','drop','ExecutionMode','fixedSpacing','TimerFcn',@obj.liveFreqMeasCallback);
            
            %Initialize MEX-layer interface
            ResonantAcqMex(obj,'init');
            obj.mexInit = true;
            
            if strfind(obj.flexRioAdapterModuleNameWithAppendix, '(Time Demux)')
                obj.enableSampleReplacement = 1;
            end
            
            if ~isempty(obj.FPGA_STATE_MACHINE_LOOP_RATE(obj.flexRioAdapterModuleName))
                % set preliminary sampleRateAcq for NI5771 so computeMask
                % does not throw error
                obj.sampleRateAcq = obj.FPGA_STATE_MACHINE_LOOP_RATE(obj.flexRioAdapterModuleName);
            end
            
            setTis = obj.FPGA_SET_TIS(obj.flexRioAdapterModuleNameWithAppendix);
            if ~isempty(setTis)
                obj.hFpga.sendAdapterModuleUserCommand(4,setTis,0);
            end
        end
        
        function delete(obj)
            if obj.acqRunning
                obj.abort();
            end
            
            if obj.mexInit
                ResonantAcqMex(obj,'delete');   % This will now unlock the mex file ot allow us to clear it from Matlab
            end
            clear('ResonantAcqMex'); % unload mex file
            
            most.idioms.safeDeleteObj(obj.hTimerContinuousFreqMeasurement);
        end
        
        function initialize(obj)
            %Initialize Mask
            obj.computeMask();
            
            %Initialize some fpga defaults
            period = obj.stateMachineLoopRate / obj.hScan.mdfData.nominalResScanFreq;
            obj.hFpga.NominalResonantPeriodTicks = round(period);
            obj.hFpga.AutoAdjustTriggerHoldOff = true;
            obj.hFpga.MaxResonantPeriodTicks = ceil(period*1.1);
            obj.hFpga.MinResonantPeriodTicks = floor(period*0.9);
            obj.hFpga.SettlingPeriods = 100;
            
            %photon counting
            obj.hFpga.PhotonCountingEnable = obj.hScan.mdfData.photonCountingEnable;
        end
    end          
    
    
    %% PROP ACCESS METHODS
    methods
        function set.stateMachineLoopRate(obj,val)
           obj.stateMachineLoopRate = val;
           
           % side effect
           obj.measureActualSampleRate();
        end
        
        function v = get.fpgaLoopRate(obj)
            v = obj.fpgaLoopRate;
        end
        
        function set.externalSampleClock(obj,val)
            obj.wasEverExternallyClocked = obj.wasEverExternallyClocked || val;
            obj.externalSampleClock = val;
        end
        
        function set.rawSampleRateAcq(obj,val)
            obj.rawSampleRateAcq = val;
            rawSampleRateToSampleRate = obj.FPGA_RAW_SAMPLE_RATE_TO_SAMPLE_RATE_FACTOR(obj.flexRioAdapterModuleNameWithAppendix);
            
            if ~isempty(rawSampleRateToSampleRate)
                obj.sampleRateAcq = obj.rawSampleRateAcq ./ rawSampleRateToSampleRate;
            end
            
            stateMachineLoopRate = obj.FPGA_STATE_MACHINE_LOOP_RATE(obj.flexRioAdapterModuleNameWithAppendix);
            if isempty(stateMachineLoopRate)
                obj.stateMachineLoopRate = obj.sampleRateAcq;
            else
                obj.stateMachineLoopRate = stateMachineLoopRate;
            end
            obj.hFpga.rawSampleRateAcq = val;
        end
        
        function set.sampleRateAcq(obj,val)
            obj.sampleRateAcq = val;
            obj.hScan.sampleRate = NaN; %fire setter in Scan2D to update UI 
        end
        
        function val = get.auxTriggersEnable(obj)
            % 5772 does not support aux triggers at this time
           val= obj.hScan.mdfData.auxTriggersEnable && ~strcmp(obj.flexRioAdapterModuleName,'NI5772'); 
        end
        
        function val = get.I2CEnable(obj)
            val= obj.hScan.mdfData.I2CEnable;
        end        
        
        function val = get.I2C_STORE_AS_CHAR(obj)
            val = obj.hScan.mdfData.I2CStoreAsChar;
        end
        
        function val = get.periodsPerFrame(obj)
            linesPerPeriod = 2^(obj.hScan.bidirectional);
            val = obj.linesPerFrame / linesPerPeriod;
        end
        
        function val = get.dcOvervoltage(obj)
            val = obj.hFpga.AcqStatusDCOvervoltage;
        end
        
        function val = get.interlacedNumChannels(obj)
            activeChannels = numel(obj.hScan.hSI.hChannels.channelsActive);
            
            maxSupportedInterlace = obj.FPGA_MAX_SUPPORTED_INTERLACE(obj.flexRioAdapterModuleNameWithAppendix);
            
            if activeChannels == 0
                val = 1;
            elseif (maxSupportedInterlace >= 32) && any(obj.hScan.hSI.hChannels.channelsActive > 16)
                val = 32;
            elseif (maxSupportedInterlace >= 16) && any(obj.hScan.hSI.hChannels.channelsActive > 4)
                val = 16;
            else
                val = min(2^ceil(log2(activeChannels)),maxSupportedInterlace);
            end
        end
        
        function val = get.dataRate(obj)
%             pixelsPerRecord = obj.pixelsPerLine * 2^obj.hScan.bidirectional;
%             bytesPerRecord = pixelsPerRecord * obj.FIFO_ELEMENT_SIZE_BYTES_SINGLE_CHAN;
%             val = bytesPerRecord * obj.hScan.scannerFrequency; % in bytes/second
%             val = val * obj.interlacedNumChannels;
            val = obj.scanFrameRate * obj.packageSizeBytes;
            val = val / 1E6;   % in MB/s
        end
        
        function val = get.scanFrameRate(obj)
            val = obj.hScan.scannerFrequency*(2^obj.hScan.bidirectional)/(obj.linesPerFrame+obj.flybackLinesPerFrame);
        end
        
        function val = get.fifoSizeFrames(obj)
            % limit size of DMA Fifo
            fifoSizeSecondsLimit = obj.FIFO_SIZE_LIMIT_MB / obj.dataRate;
            fifoSizeSeconds_ = min(obj.FIFO_SIZE_SECONDS,fifoSizeSecondsLimit);
            
            % hold at least 5 frames            
            val = max(5,ceil(obj.scanFrameRate * fifoSizeSeconds_));
        end
        
        function val = get.frameQueueLoggerCapacity(obj)
            % limit size of frame queue
            frameQueueLoggerSizeSecondsLimit = obj.FRAME_QUEUE_LOGGER_SIZE_LIMIT_MB / obj.dataRate;
            frameQueueLoggerSizeSeconds_ = min(obj.FRAME_QUEUE_LOGGER_SIZE_SECONDS,frameQueueLoggerSizeSecondsLimit);
            
            % hold at least 5 frames
            val = max(5,ceil(obj.scanFrameRate * frameQueueLoggerSizeSeconds_));
        end
        
        function val = get.frameQueueMatlabCapacity(obj)
            % limit size of frame queue
            frameQueueMatlabSizeSecondsLimit = obj.FRAME_QUEUE_MATLAB_SIZE_LIMIT_MB / obj.dataRate;
            frameQueueMatlabSizeSeconds_ = min(obj.FRAME_QUEUE_MATLAB_SIZE_SECONDS,frameQueueMatlabSizeSecondsLimit);
            
            % hold at least 3 frames
            val = max(3,ceil(obj.scanFrameRate * frameQueueMatlabSizeSeconds_));

            if obj.SYNC_DISPLAY_TO_VOLUME_RATE && ~isinf(obj.hScan.framesPerStack)
                max(obj.hScan.framesPerStack,0); %make sure this is positive
                
                % queueSizeInVolumes:
                % has to be at least 1
                % the larger this value the longer the delay between acquisition and display
                % the smaller this value, the more volumes might be dropped
                %   in the display, and the display rate might be reduced
                queueSizeInVolumes = 1.5; % 1.5 means relatively small display latency
                
                assert(queueSizeInVolumes >= 1); % sanity check
                val = max(val,ceil(queueSizeInVolumes * obj.hScan.framesPerStack));
            end
        end
        
        function val = get.rawAdcOutput(obj)
            obj.hFpga.fpgaCheckAdapterModuleInitialization();
            if obj.simulated
                val = [0 0 0 0];
            else
                val = obj.hFpga.DebugRawAdcOutput;
            end
        end

        function val = get.triggerHoldOff(obj)
            val = round(max(0,obj.linePhaseSamples + obj.estimatedPeriodClockDelay));
        end
 
        function val = get.estimatedPeriodClockDelay(obj)
            %TODO: Improve Performance
            totalTicksPerLine = (obj.stateMachineLoopRate / obj.hScan.mdfData.nominalResScanFreq) / 2;
            acqTicksPerLine = totalTicksPerLine * obj.hScan.fillFractionTemporal;
            
            val = (totalTicksPerLine - acqTicksPerLine)/2;
            
            val = val + obj.ADAPTER_MODULE_TRIGGER_TO_ADC_DELAY(obj.flexRioAdapterModuleNameWithAppendix);
            val = round(val);
        end
        
        function val = get.adapterModuleChannelCount(obj)
            val = obj.hFpga.adapterModuleChannelCount;
        end
        
        function value = get.beamTiming(obj)      
            beamOnLeadTicks = round(obj.hScan.beamClockDelay * obj.stateMachineLoopRate);
            beamOffLagTicks = round(obj.hScan.beamClockExtend * obj.stateMachineLoopRate) - beamOnLeadTicks;
            
            beamClockOnForward  = -beamOnLeadTicks;
            beamClockOffForward = obj.maskParams.loopTicksPerLine + beamOffLagTicks;
            
            beamClockOnBackward  = 0;
            beamClockOffBackward = 0;
            
            if beamOnLeadTicks > obj.triggerHoldOff
                most.idioms.dispError('Beams switch time is set to precede period clock. This setting cannot be fullfilled.\n');
            end
            
            value = [beamClockOnForward beamClockOffForward beamClockOnBackward beamClockOffBackward];
        end
        
        function val = get.flexRioAdapterModuleNameWithAppendix(obj)
            if ~isempty(obj.hScan.mdfData.customSigCondOption)
                val = [obj.flexRioAdapterModuleName ' (' obj.hScan.mdfData.customSigCondOption ')'];
            else
                val = obj.flexRioAdapterModuleName;
            end
        end
    end
    
    %%% acquisition parameters
    methods
        function val = get.loggingEnable(obj)               % accessed by MEX function
            val = obj.hScan.hSI.hChannels.loggingEnable;
        end
        
        function val = get.channelsActive(obj)              % accessed by MEX function
            val = obj.hScan.hSI.hChannels.channelsActive;
            % maybe these checks are a little paranoid, but I really don't want
            % the mex function to crash (GJ)
            assert(all(0<val & val<=obj.adapterModuleChannelCount));
            assert(all(floor(val) == val));
            assert(isequal(val,unique(val)));
            assert(issorted(val));
            val = double(val);
        end
        
        function val = get.channelsDisplay(obj)
            val = obj.hScan.hSI.hChannels.channelDisplay;
            % maybe these checks are a little paranoid, but I really don't want
            % the mex function to crash (GJ)
            try
                assert(all(0<val & val<=obj.adapterModuleChannelCount));
                assert(all(floor(val) == val));
                assert(isequal(val,unique(val)));
                assert(issorted(val));
            catch ME
                most.idioms.reportError(ME);
                rethrow(ME);
            end
            val = double(val);
        end
        
        function val = get.channelsSave(obj)
            val = obj.hScan.hSI.hChannels.channelSave;
            % maybe these checks are a little paranoid, but I really don't want
            % the mex function to crash (GJ)
            try
                assert(all(0<val & val<=obj.adapterModuleChannelCount));
                assert(all(floor(val) == val));
                assert(isequal(val,unique(val)));
                assert(issorted(val));
            catch ME
                most.idioms.reportError(ME);
                rethrow(ME);
            end
            val = double(val);
        end
        
        function val = get.channelsDisplayArrayPointer(obj)
            switch obj.interlacedNumChannels
                case 1
                    interlacedChannels = obj.channelsActive;
                case 2
                    interlacedChannels = obj.channelsActive;
                case 4
                    interlacedChannels = 1:4;
                case 16
                    interlacedChannels = 1:16;
                case 32
                    interlacedChannels = 1:32;
                otherwise
                    error('Something bad happened');
            end
            [tf,val] = ismember(obj.channelsDisplay,interlacedChannels);
            if ~all(tf)
                fprintf(2,'channelsDisplay are not part of interlacedChannels');
                error('channelsDisplay are not part of interlacedChannels');
            end
        end
        
        function val = get.channelsSaveArrayPointer(obj)
            switch obj.interlacedNumChannels
                case 1
                    interlacedChannels = obj.channelsActive;
                case 2
                    interlacedChannels = obj.channelsActive;
                case 4
                    interlacedChannels = 1:4;
                case 16
                    interlacedChannels = 1:16;
                case 32
                    interlacedChannels = 1:32;
                otherwise
                    error('Something bad happened');
            end
            [tf,val] = ismember(obj.channelsSave,interlacedChannels);
            if ~all(tf)
                fprintf(2,'channelsSave are not part of interlacedChannels');
                error('channelsSave are not part of interlacedChannels');
            end
        end
        
        function v = get.firstSampleDelayEnable(obj)
            v = obj.recordFirstSampleDelay && obj.hScan.uniformSampling && (obj.hScan.pixelBinFactor == 1);
        end
        
        function set.frameTagging(obj,val)
            %validation
            obj.zprpAssertNotRunning('frameTagging');
            validateattributes(val,{'logical' 'numeric'},{'binary' 'scalar'});
            %set prop
            assert(val,'frameTagging cannot be deactivated');
            obj.frameTagging = val;
            %side effects
            obj.flagResizeAcquisition = true;
        end

        function set.frameAcquiredFcn(obj,val)
            %validation
            if isempty(val)
                val = [];
            else
                validateattributes(val,{'function_handle'},{'scalar'});
            end
            
            %set prop
            obj.frameAcquiredFcn = val;
            
            %side effects
            ResonantAcqMex(obj,'registerFrameAcqFcn',val);
        end
    end
    
    %%% live acq params
    methods
        function set.channelsInvert(obj,val)
            obj.hFpga.channelsInvert = val;
        end
        
        function v = get.channelsInvert(obj)
            v = obj.hFpga.channelsInvert;
        end
        
        function val = get.linePhaseSamples(obj)
            val = obj.stateMachineLoopRate * obj.hScan.linePhase;
        end
        
        function set.reverseLineRead(obj,val)
            %validation
            validateattributes(val,{'logical' 'numeric'},{'binary' 'scalar'});
            %set prop
            obj.reverseLineRead = val;
        end
    end
    
    methods
        function v = getRoiIntensity(obj,roiNumber)
            idx = roiNumber - 1;
            obj.hFpga.RoiGetIntensityIndex = idx;
%             t = tic;
%             while obj.hFpga.RoiIntensityReadIndex ~= idx
%                 assert(toc(t) < 0.1, 'Timed out attempting to read ROI Intensity.');
%             end
            v = obj.hFpga.RoiIntensity;
        end
        
        function writeAnalysisRoiData(obj,roiNumber,rect,slices,channel,thresh)
            % roiNumbers are 1, 2, 3...64
            % rect is [start pixel, start line, pixel width, pixel height]
            % pixels and lines start at 1
            % channel is 1 2 3 or 4
            % thresh is uint16
            if obj.reverseLineRead
                x1 = min(max(rect(1)-1,0),obj.pixelsPerLine-1);
                x2 = min(max(rect(1)+rect(3)-2,0),obj.pixelsPerLine-1);
            else
                x1 = obj.pixelsPerLine - min(max(rect(1)+rect(3)-2,0),obj.pixelsPerLine-1);
                x2 = obj.pixelsPerLine - min(max(rect(1)-1,0),obj.pixelsPerLine-1);
            end
            x1 = fliplr(dec2bin(uint16(x1),12));
            x2 = fliplr(dec2bin(uint16(x2),12));
            
            y1 = uint16(min(max(rect(2)-1,0),obj.linesPerFrame-1));
            y2 = uint16(min(max(rect(2)+rect(4)-2,0),obj.linesPerFrame-1));
            
            ch = fliplr(dec2bin(uint16(channel-1),2));
            
            pixLocHi = dec2bin(0,32);
            pixLocHi(1:12) = x1(1:12);
            pixLocHi(13:24) = x2(1:12);
            pixLocHi(25:26) = ch(1:2);
            pixLocHi = uint64(bin2dec(fliplr(pixLocHi)));
            
            pixLoc = uint64(y1) + bitshift(uint64(y2),16) + bitshift(pixLocHi,32);
            
            
            % calc total number of pixels
            N = rect(3) * rect(4) * (slices(2) - slices(1) + 1);
            div = uint64((2^32)/N);
            
            s1 = uint64(slices(1)-1);
            s2 = uint64(slices(2)-1);
            slLoc = s1 + bitshift(s2,16) + bitshift(div,32);
            
            
            obj.hFpga.RoiWriteIndex = roiNumber-1;
            obj.hFpga.RoiPixelLocation = pixLoc;
            obj.hFpga.RoiSliceLocation = slLoc;
            obj.hFpga.RoiThreshold = thresh;
            obj.hFpga.RoiWriteParams = true;
        end
        
        function writePatternDO(obj,doNumber,pattern,mask)
            % doNumbers are 1, 2, 3, 4
            % pattern is an array of logicals
            % mask is an array of logicals
            
            bits = arrayfun(@num2str,pattern);
            bits(end+1:64) = '0';
            obj.hFpga.RoiDOParam1 = bin2dec(fliplr(bits(1:32))) + bitshift(bin2dec(fliplr(bits(33:64))),32);
            
            bits = arrayfun(@num2str,mask);
            bits(end+1:64) = '0';
            obj.hFpga.RoiDOParam2 = bin2dec(fliplr(bits(1:32))) + bitshift(bin2dec(fliplr(bits(33:64))),32);
            
            obj.hFpga.RoiDOModeWriteIndex = bitshift(uint8(doNumber-1),2) + 1;
            obj.hFpga.RoiWriteDOParams = true;
        end
        
        function writePwmDO(obj,doNumber,roiNumber,pwmFreq,intensity1,dutyCycle1,intensity2,dutyCycle2)
            % doNumbers are 1, 2, 3, 4
            % roiNumbers are 1, 2, 3...64
            % [intensity1,dutyCycle1] and [intensity1,dutyCycle1] set up a linear relationship between intensity and duty cycle
            % intensityN is -2^15 to 2^15. dutyCycleN is -1 to 1
            
            period = typecast([uint32(obj.stateMachineLoopRate/pwmFreq) 0], 'uint64');
            roiNum = bitshift(uint64(roiNumber-1),32);
            obj.hFpga.RoiDOParam1 = period + roiNum;
            
            intensityOffset = typecast([int16(intensity1) 0 0 0], 'uint64');
            dutyOffset = typecast([0 int16(double(dutyCycle1)*2^15) 0 0],'uint64'); %fixed point representation; -1 to 1 is -32768 to 32767; casted to uint
            M = (double(dutyCycle2) - double(dutyCycle1)) / (double(intensity2) - double(intensity1));
            scale = typecast([0 int32(M*2^31)],'uint64'); %fixed point representation; -1 to 1 is -2^31 to 2^31; casted to uint
            obj.hFpga.RoiDOParam2 = intensityOffset + dutyOffset + scale;
            
            obj.hFpga.RoiDOModeWriteIndex = bitshift(uint8(doNumber-1),2) + 2;
            obj.hFpga.RoiWriteDOParams = true;
        end
        
        function clearDO(obj,doNumber)
            % doNumbers are 1, 2, 3, 4
            
            obj.hFpga.RoiDOModeWriteIndex = bitshift(uint8(doNumber),2);
            obj.hFpga.RoiWriteDOParams = true;
        end
    end
    
    %Property-access helpers
    methods (Hidden)
        function zprpUpdateMask(obj)
            if obj.hScan.uniformSampling
                obj.hFpga.UniformMaskBin = obj.hScan.pixelBinFactor;
                obj.hFpga.AcqParamSamplesPerRecord = obj.maskParams.samplesPerLine;
            else
                assert(all(obj.mask > 0),'The horizontal pixel resolution is too high for the acquisition sample rate. Reduce pixels per line or enable uniform sampling.');
                
                obj.hFpga.UniformMaskBin = 0;
                obj.dispDbgMsg('Sending Mask to FPGA');
                
                % generate the mask write indices and cast the data to the
                % right datatype
                maskWriteIndices = cast(0:(length(obj.mask)-1),'uint16');
                maskData = cast(obj.mask(:)','uint16');
                assert(all(maskData == obj.mask(:)'),'The mask data changed when converting it to uint16.');
                
                % interleave the indices with the mask data and recast it into
                % a uint32. This is the format the MasktoFPGA FIFO expects
                maskToSend = reshape([maskData;maskWriteIndices],1,[]);
                maskToSend = typecast(maskToSend,'uint32');
                
                try
                    if (~obj.simulated)
                        maxNumMaskSamples = 4096; % hard coded array size on FPGA
                        assert(length(obj.mask) <= maxNumMaskSamples,'Length of mask exceeds maximum of %d entries',maxNumMaskSamples);
                        assert(obj.maskParams.samplesPerLine <= intmax(class(obj.hFpga.AcqParamSamplesPerRecord)),...
                            'Too many samples in mask for FPGA to handle'); % sanity check
                        
                        if obj.externalSampleClock || obj.wasEverExternallyClocked
                            % DMA FIFO transfer could crash if external
                            % sample clock is unstable
                            
                            % Elementwise transfer of mask array to FPGA
                            for i = 1:length(obj.mask)
                                obj.hFpga.MaskWriteIndex = i-1;
                                obj.hFpga.MaskElementData = obj.mask(i);
                                obj.hFpga.MaskDoWriteElement = true;
                            end
                        else     
                            % Stream Mask to FPGA with a DMA FIFO
                            obj.hFpga.fifo_MaskToFPGA.write(maskToSend);
                        end
                    end
                    
                    obj.hFpga.AcqParamSamplesPerRecord = obj.maskParams.samplesPerLine;
                catch ME
                    error('Error sending mask to FPGA device: \n%s',ME.message);
                end
            end
            obj.flagUpdateMask = false;
        end
        
        function zprpResizeAcquisition(obj)
            obj.frameSizePixels = obj.pixelsPerLine * obj.linesPerFrame; %not including frame tag
            
            fifoElementSizeBytes = obj.FIFO_ELEMENT_SIZE_BYTES_MULTI_CHAN;
            
            obj.tagSizeFifoElements = (obj.FRAME_TAG_SIZE_BYTES / fifoElementSizeBytes) * obj.frameTagging ;
            assert(obj.tagSizeFifoElements == floor(obj.tagSizeFifoElements),'Frame Tag Byte Size must be an integer multiple of FIFO Element Byte Size');
            
            obj.dataSizeBytes = obj.PIXEL_SIZE_BYTES .* obj.frameSizePixels .* obj.interlacedNumChannels;
            obj.dataSizeBytes = ceil(obj.dataSizeBytes / fifoElementSizeBytes) * fifoElementSizeBytes; % add padding bytes
            
            obj.packageSizeBytes = obj.dataSizeBytes + obj.FRAME_TAG_SIZE_BYTES;
            obj.packageSizeFifoElements = obj.packageSizeBytes / fifoElementSizeBytes;
            assert(floor(obj.packageSizeFifoElements) == obj.packageSizeFifoElements); % needs to be integer
            
            if obj.simulated
                obj.simulatedFramePeriod = obj.hScan.hSI.hRoiManager.scanFramePeriod*1000;
            else
                %Configure FIFO managed by FPGA interface
                obj.hFpga.fifo_MultiChannelToHostU64.configure(obj.packageSizeFifoElements*obj.fifoSizeFrames);
                obj.hFpga.fifo_MultiChannelToHostU64.start();
            end
            
            assert((obj.hScan.mdfData.I2CEnable + obj.hScan.mdfData.auxTriggersEnable + obj.hScan.mdfData.photonCountingEnable) <= 1,'I2CEnable, auxTriggersEnable, usePhotonCountinModule are mutually exclusive');
            if obj.hScan.mdfData.I2CEnable
                obj.hFpga.AuxDataFifoMode = 'I2C';
            elseif obj.hScan.mdfData.auxTriggersEnable
                obj.hFpga.AuxDataFifoMode = 'Aux Triggers';
            else
                obj.hFpga.AuxDataFifoMode = 'Disabled';
            end                    
            
            if obj.hScan.mdfData.auxTriggersEnable || obj.hScan.mdfData.I2CEnable
                if ~obj.simulated                   
                    obj.fpgaFifoAuxDataActualDepth = obj.hFpga.fifo_AuxDataToHostU64.configure(obj.FIFO_ELEMENT_SIZE_AUX_DATA);
                    obj.hFpga.fifo_AuxDataToHostU64.start();
                else
                    obj.fpgaFifoAuxDataActualDepth = obj.FIFO_ELEMENT_SIZE_AUX_DATA;
                end 
            end

            obj.reverseLineRead = obj.hScan.mdfData.reverseLineRead;
            obj.enableBenchmark = obj.hScan.enableBenchmark;
            obj.framesProcessed = 0;
            
            % calculate resolution of first ROI in pix per cm then turn
            % into fraction with 2^30 as the numerator
            sfs = [obj.acqParamBuffer.scanFields{:}];
            sfs = [sfs{:}];
            assert(~isempty(sfs),'Scan does not contain any scanfields');
            sf = sfs(1);
            
            %sf = obj.acqParamBuffer.scanFields{1}{1};
            resDenoms = 2^30 ./ (1e4 * sf.pixelResolutionXY ./ (sf.sizeXY * obj.hScan.hSI.mdfData.objectiveResolution));
            
            obj.xResolutionNumerator = 2^30;
            obj.xResolutionDenominator = resDenoms(1);
            obj.yResolutionNumerator = 2^30;
            obj.yResolutionDenominator = resDenoms(2);
        end
    end
    
    
    %% FRIEND METHODS
    methods (Hidden)
        function loadSimulatedFrames(obj,frames,coords)
            if iscell(frames)
                frames = cat(3,frames{:});
            end
            obj.simDataSourceFrames = int16(frames);
            obj.simDataSourceRect = double(coords);
            ResonantAcqMex(obj,'loadSimulatedFrames');
        end
        
        function v = configureCustomSampling(obj,func,data)
            switch func
                case 1
                    c1 = uint64(1); % custom function 1
                    c1 = c1 + uint64(min(data.laserPulseChan-1,3)) * 2^4;
                    c1 = c1 + uint64(int16(data.laserPulseThreshold)) * 2^6;
                    
                    c2 = uint64(0);
                    for i = 1:4
                        chanDat = data.channelConfig(i);
                        
                        cc = uint64(uint8(chanDat.phase));
                        cc = cc + uint64(min(uint8(chanDat.N),31)) * 2^8;
                        cc = cc + chanDat.enableBlanking * 2^13;
                        cc = cc + chanDat.enablePrevSampleSubtraction * 2^14;
                        c2 = c2 + cc*2^(15*(i-1));
                    end
                    
                otherwise
                    c1 = uint64(0);
                    c2 = uint64(0);
            end
            
            obj.hFpga.CustomSamplingConfiguration1 = c1;
            obj.hFpga.CustomSamplingConfiguration2 = c2;
            
            v = obj.measureActualSampleRate();
        end
        
        function v = measureActualSampleRate(obj)
            loopRate = obj.sampleRateAcq;
            try
                % workaround until all fpga targets are built
                v = loopRate / double(obj.hFpga.CustomSamplingDecimation);
            catch
                v = loopRate;
            end
            obj.sampleRateAcq = v;
        end
        
        function start(obj)
            obj.dispDbgMsg('Starting Acquisition');
            
            if ~obj.simulated
                obj.hFpga.fpgaCheckAdapterModuleInitialization();
                obj.hFpga.checkAdapterModuleErrorState();
                
                if obj.externalSampleClock
                    obj.measureExternalRawSampleClockRate();
                end
                
                if obj.FPGA_MEASURE_SLOW_TRIGGER_RATE(obj.flexRioAdapterModuleNameWithAppendix)
                    obj.NI577xMeasureSampleClockRate();
                end
            end
            
            if ~obj.simulated && obj.dcOvervoltage
                obj.hFpga.resetDcOvervoltage();
            end
            
            obj.hFpga.AcqEngineDoReset = true;
            obj.hFpga.ResetDebugCounters = true;
            obj.fpgaStartAcquisitionParameters();
            
            obj.computeMask();
            obj.zprpUpdateMask();
                        
            % reset counter
            obj.framesAcquired = 0;
            obj.acqCounter = 0;
            obj.lastEndOfAcquisition = 0;
            
            obj.bufferAcqParams();
            obj.zprpResizeAcquisition();
            
            if obj.dataRate > 240
                most.idioms.dispError('The current acquisition data rate is %.2f MB/s, while the bandwith of PCIe v1.x is 250MB/s. Approaching this limit might result in data loss.\n',obj.dataRate);
            end
            
            %Configure queue(s) managed by MEX interface
            ResonantAcqMex(obj,'resizeAcquisition');
            obj.flagResizeAcquisition = false;
            
            %Start acquisition
            if ~obj.simulated
                ResonantAcqMex(obj,'syncFpgaClock'); % Sync FPGA clock and system clock
            end
            ResonantAcqMex(obj,'startAcq');     % Arm Frame Copier to receive frames
            obj.hFpga.AcqEngineDoArm = true;    % then start the acquisition
            obj.acqRunning = true;
        end
        
        function abort(obj)
            if ~obj.acqRunning
                return
            end
            
            ResonantAcqMex(obj,'stopAcq');
            
            obj.hFpga.AcqEngineDoReset = true;
            
            if (~obj.simulated)
                obj.fpgaStopFifo();
            end
            
            obj.acqRunning = false;
            
            try
                obj.hFpga.checkAdapterModuleErrorState();
            catch ME
                most.idioms.reportError(ME);
            end
        end
        
        function [stripeData,planeNum] = frameToRois(obj,stripeData,frameData)
            numPlanes = length(obj.acqParamBuffer.zs);
            planeNum = mod(stripeData.frameNumberAcqMode-1,obj.acqParamBuffer.framesPerStack)+1;
            
            stripeData.startOfVolume = planeNum == 1;
            stripeData.endOfVolume = planeNum == numPlanes;
            
            if planeNum > numPlanes
                % flyback frame
                stripeData.roiData = {};
            else
                z = obj.acqParamBuffer.zs(planeNum);
                stripeData.roiData = {};
                
                startLines = obj.acqParamBuffer.startLines{planeNum};
                endLines = obj.acqParamBuffer.endLines{planeNum};
                
                rois = obj.acqParamBuffer.rois{planeNum};
                for i = 1:numel(rois)
                    roiData = scanimage.mroi.RoiData();
                    roiData.hRoi = rois{i};
                    
                    startLine = startLines(i);
                    endLine = endLines(i);
                    numLines = endLine-startLine+1;
                    
                    roiData.zs = z;
                    roiData.channels = stripeData.channelNumbers;
                    
                    roiData.stripePosition = {[1, numLines]};
                    roiData.stripeFullFrameNumLines = numLines;
                    
                    roiData.acqNumber = stripeData.acqNumber;
                    roiData.frameNumberAcq = stripeData.frameNumberAcq;
                    roiData.frameNumberAcqMode = stripeData.frameNumberAcqMode;
                    roiData.frameTimestamp = stripeData.frameTimestamp;
                    
                    roiData.imageData = cell(length(roiData.channels),1);
                    for chanIdx = 1:length(roiData.channels)
                        if startLine == 1 && endLine == size(frameData{chanIdx},2);
                            % performance improvement for non-mroi mode
                            roiData.imageData{chanIdx}{1} = frameData{chanIdx}; % images are transposed at this point
                        else
                            roiData.imageData{chanIdx}{1} = frameData{chanIdx}(:,startLine:endLine); % images are transposed at this point
                        end
                    end
                    stripeData.roiData{i} = roiData;
                end
            end
        end
        
        function generateSoftwareAcqTrigger(obj)
            if ~obj.simulated
                obj.hFpga.AcqTriggerDoSoftwareTrig = true;
            else
                ResonantAcqMex(obj,'trigger');
            end
        end
        
        function generateSoftwareAcqStopTrigger(obj)
            obj.hFpga.StopTriggerDoSoftwareTrig = true;
        end
        
        function generateSoftwareNextFileMarkerTrigger(obj)
            obj.hFpga.AdvanceTriggerDoSoftwareTrig = true;
        end
        
        function signalReadyReceiveData(obj)
            ResonantAcqMex(obj,'signalReadyReceiveData');
        end
        
        function [success,stripeData] = readStripeData(obj)
            stripeData = scanimage.interfaces.StripeData();
            
            if ~obj.acqRunning
                success = false;
                return
            end
            
            % fetch data from Mex function
            [success, frameData, frameTag, framesRemaining, acqStatus] = ResonantAcqMex(obj,'getFrame');
            
            if acqStatus.numDroppedFramesLogger > 0
                try % this try catch is a bit paranoid, but we want to make sure that the acquisition is aborted and some sort of error is printed
                    errorMsg = sprintf('Data logging lags behind acquisition: %d frames lost.\nAcquisition stopped.\n',acqStatus.numDroppedFramesLogger);
                    most.idioms.dispError(errorMsg);
                catch ME
                    errorMsg = 'Unknown error.';
                    most.idioms.reportError(ME);
                end
                
                obj.hScan.hSI.abort();
                
                errordlg(errorMsg,'Error during acquisition','modal');
                success = false;
                return
            end
            
            if ~success
                return % read from empty queue
            end
            
            if frameTag.endOfAcq
                obj.hScan.hTrig.resetAcqStartPulse();
            end
            
            if frameTag.frameTagCorrupt
                try % this try catch is a bit paranoid, but we want to make sure that the acquisition is aborted and some sort of error is printed
                    pixelsLost = obj.hFpga.AcqStatusFIFOPixelsLost;

                    fpgaState = obj.hFpga.AcqStatusEngineState; % we have to capture the fpga state before abort() resets it to idle

                    errorMsg = sprintf(['Error: Data of frame %d appears to be corrupt. Acquistion stopped. ',...
                               'Corrupt data was not logged to disk.\n...',...
                               'Most likely pixels were lost because PXIe data bandwidth was exceeded.\n',...
                               'Debug information: %d pixelsLost; Fpga state = %s\n'],...
                                obj.framesAcquired+1,pixelsLost,fpgaState);
                    most.idioms.dispError(errorMsg);
                catch ME
                    errorMsg = 'Unknown error.';
                    most.idioms.reportError(ME);
                end
                
                obj.hScan.hSI.abort();
                
                errordlg(errorMsg,'Error during acquisition','modal');
                success = false;
                return
            end
            
            if frameTag.totalAcquiredFrames == 1
                obj.epochAcqMode = now;
            end
            
            stripeData.endOfAcquisitionMode = frameTag.endOfAcqMode;
            stripeData.endOfAcquisition = frameTag.endOfAcq;
            if strcmp(obj.flexRioAdapterModuleName, 'NI517x')
                stripeData.overvoltage = false;
%                 stripeData.overvoltage = dabs.ni.oscope.checkOverload;
            else
                % need to fix over voltage detection for 517x!!
                stripeData.overvoltage = frameTag.dcOvervoltage;
            end
            stripeData.startOfFrame = true; % there is only one stripe per frame for resonant scanning
            stripeData.endOfFrame = true;   % there is only one stripe per frame for resonant scanning
            stripeData.stripeNumber = 1;    % there is only one stripe per frame for resonant scanning
            stripeData.frameNumberAcqMode = frameTag.totalAcquiredFrames;
            stripeData.frameNumberAcq = frameTag.totalAcquiredFrames - obj.lastEndOfAcquisition;
            stripeData.stripesRemaining = framesRemaining;
            stripeData.epochAcqMode = obj.epochAcqMode;
            stripeData.channelNumbers = obj.hScan.hSI.hChannels.channelDisplay; %This is a little slow, since it's dependent: obj.channelsDisplay;
            
            if obj.simNoise
                for i = 1:numel(frameData)
                    frameData{i} = frameData{i} + int16(obj.simNoise*rand(size(frameData{i})));
                end
            end
            
            % replace dummy values for empty pixels
            if obj.enableSampleReplacement
                for i = 1:numel(frameData)
                    frameData{i}(frameData{i} == -16384) = 0;
                end
            end
            
            if obj.enableBenchmark
                benchmarkDat.totalAcquiredFrames = frameTag.totalAcquiredFrames;
                
                benchmarkDat.frameCopierProcessTime = double(typecast(frameTag.nextFileMarkerTimestamp,'uint64'));
                benchmarkDat.frameCopierCpuCycles = double(frameTag.acqNumber);
                
                benchmarkDat.frameLoggerProcessTime = double(typecast(frameTag.acqTriggerTimestamp,'uint64'));
                benchmarkDat.frameLoggerCpuCycles = double(typecast(frameTag.frameTimestamp,'uint64'));
                
                obj.benchmarkData = benchmarkDat;
                obj.framesProcessed = obj.framesProcessed + 1;
                
                stripeData.acqNumber = 1;
                stripeData.frameTimestamp = 0;
                stripeData.acqStartTriggerTimestamp = 0;
                stripeData.nextFileMarkerTimestamp = 0;
            else
                stripeData.acqNumber = frameTag.acqNumber;
                stripeData.frameTimestamp = frameTag.frameTimestamp;
                stripeData.acqStartTriggerTimestamp = frameTag.acqTriggerTimestamp;
                stripeData.nextFileMarkerTimestamp = frameTag.nextFileMarkerTimestamp;
            end
            
            stripeData = obj.frameToRois(stripeData,frameData); % images are transposed at this point
            
            % update counters
            if stripeData.endOfAcquisition
                obj.acqCounter = obj.acqCounter + 1;
                obj.lastEndOfAcquisition = stripeData.frameNumberAcqMode;
            end
            
            obj.framesAcquired = stripeData.frameNumberAcqMode;
            
            
            % control acquisition
            if stripeData.endOfAcquisitionMode
                obj.abort(); %self-shutdown
            end
        end
    
        function computeMask(obj)            
            if obj.hScan.uniformSampling
                obj.mask = repmat(obj.hScan.pixelBinFactor,obj.pixelsPerLine,1);
            else
                obj.mask = scanimage.util.computeresscanmask(obj.hScan.scannerFrequency,obj.sampleRateAcq,obj.hScan.fillFractionSpatial, obj.pixelsPerLine);
            end
            
            obj.maskParams.samplesPerLine = sum(obj.mask);
            obj.maskParams.loopTicksPerLine = obj.maskParams.samplesPerLine * round(obj.stateMachineLoopRate / obj.sampleRateAcq);
            obj.flagUpdateMask = true;
        end
        
        function configureAdapterModuleSampleClock(obj,mode)
            assert(~obj.acqRunning,'Cannot change sample clock mode during active acquisition');
            
            switch lower(mode)
                case 'external'
                    configureExternalSampleClock();
                case 'internal'
                    configureInternalSampleClock();
                otherwise
                    error('Unknown sample clock mode: %s',mode);
            end
            
            function configureInternalSampleClock()
                if strcmp(obj.flexRioAdapterModuleName, 'NI517x')
                    dabs.ni.oscope.configureSampleClock(false,0);
                else
                    command   = 0; % 0 = Clock Settings
                    userData0 = 3; % 3 = Internal Sample Clock locked to an external Reference Clock through Sync Clock <- FPGA hardcoded to use PXIe_Clk10 as Sync Clock
                    userData1 = 0; % unused
                    
                    status = obj.hFpga.sendAdapterModuleUserCommand(command,userData0,userData1);
                    assert(status == 0,'Configuring internal sample clock for FlexRio digitizer module failed with status code %d',status);
                end
                
                obj.rawSampleRateAcq = obj.ADAPTER_MODULE_RAW_SAMPLING_RATE_MAP(obj.flexRioAdapterModuleNameWithAppendix);
                obj.externalSampleClock = false;
            end
            
            function configureExternalSampleClock()
                fprintf('Setting up external sample clock for FPGA digitizer module.\n');
                obj.externalSampleClock = true; %This needs to be set before the call of sendAdapterModuleUserCommand
                
                assert(~isempty(regexpi(obj.flexRioAdapterModuleName,'NI573|NI577')),...
                    'External sample clock unsupported for digitizer module %s. Please set the machine data file property ''externalSampleClockRate'' to false and restart ScanImage',...
                    obj.flexRioAdapterModuleName);
                
                obj.hScan.zprvMDFVerify('externalSampleClockRate',{{'numeric'},{'scalar','nonempty','positive'}},[]);
                
                loopRateRange = obj.ADAPTER_MODULE_SAMPLING_RATE_RANGE_MAP(obj.flexRioAdapterModuleNameWithAppendix);
                assert(( min(obj.hScan.mdfData.externalSampleClockRate) >= loopRateRange(1) ) && ...
                       ( max(obj.hScan.mdfData.externalSampleClockRate) <= loopRateRange(2) ),...
                    'The sample rate specified in the machine data file ( %.3fMHz ) is outside the supported range of the %s FPGA digitizer module ( %.1f - %.1fMHz )',...
                    obj.hScan.mdfData.externalSampleClockRate/1e6,obj.flexRioAdapterModuleName,loopRateRange(1)/1e6,loopRateRange(2)/1e6);
                
                if strcmp(obj.flexRioAdapterModuleName, 'NI517x')
                    dabs.ni.oscope.configureSampleClock(true,obj.hScan.mdfData.externalSampleClockRate);
                else
                    command   = 0; % 0 = Clock Settings
                    userData0 = 2; % 2 = External Sample Clock through the CLK IN connector
                    userData1 = 0; % unused
                    
                    status = obj.hFpga.sendAdapterModuleUserCommand(command,userData0,userData1);
                    assert(status == 0,'Configuring external sample clock for FlexRio digitizer module failed with status code %d',status);
                end
                 
                obj.rawSampleRateAcq = obj.hScan.mdfData.externalSampleClockRate; %preliminary, actual loop rate measured later
            end
        end
        
        function measureExternalRawSampleClockRate(obj)
            measurePeriod     = 1e-3;   % [s] count sample clock edges for measurePeriod of time
            numMeasurements   = 100;    % number of measurement repeats to calculate mean and standard deviation
            allowOverClocking = 0.01;   % allow to overclock the digitizer by 1%
            loopRateRange   = obj.ADAPTER_MODULE_SAMPLING_RATE_RANGE_MAP(obj.flexRioAdapterModuleNameWithAppendix);
            maxLoopRateStd  = 50e4;    % [Hz] TODO: need to fine tune this value (somewhat of a guess right now)
            
            obj.hFpga.checkAdapterModuleErrorState();
            
            % start measuring the sample rate
            fprintf('Measuring FPGA digitizer sample clock frequency...\n');
            obj.hFpga.AcqStatusAcqLoopMeasurePeriod = round(measurePeriod * obj.FPGA_SYS_CLOCK_RATE);
            measurePeriod = double(obj.hFpga.AcqStatusAcqLoopMeasurePeriod) / obj.FPGA_SYS_CLOCK_RATE; %read measure period back to account for rounding errors
            
            loopIterationsCountFactor = obj.FPGA_RAW_ACQ_LOOP_ITERATIONS_COUNT_FACTOR(obj.flexRioAdapterModuleNameWithAppendix);
            
            measurements = zeros(numMeasurements,1);
            for iter = 1:numMeasurements
                measurements(iter) = obj.hFpga.AcqStatusAcqLoopIterationsCount / measurePeriod * loopIterationsCountFactor;
                most.idioms.pauseTight(measurePeriod);
            end
            
            loopRateMean = mean(measurements);
            loopRateStd  = std(measurements);
            
            if loopRateMean < 1e3
               most.idioms.dispError(['The external sample rate frequency %.1fHz is suspiciously low. ',...
                   'Is the clock connected and running?\n\n'],loopRateMean) ;
            end
            
            if ( loopRateMean < loopRateRange(1)*(1-allowOverClocking) ) || ...
               ( loopRateMean > loopRateRange(2)*(1+allowOverClocking) )
                
               plotMeasurement(measurements);
               error('The external sample clock frequency %.3fMHz is outside the supported range of the %s FPGA digitizer module (%.1f - %.1fMHz).',...
                      loopRateMean/1e6,obj.flexRioAdapterModuleName,loopRateRange(1)/1e6,loopRateRange(2)/1e6);
            end
               
            if loopRateStd > maxLoopRateStd
                plotMeasurement(measurements);
                error('The external sample clock of the FPGA digitizer module is unstable. Sample frequency mean: %.3EHz, SD: %.3EHz. Please make sure the sample clock is connected and running.',...
                    loopRateMean,loopRateStd); % GJ 2015-03-01 <- if this check fails, we might have to adjust maxLoopRateStd
            end
            
            % if TIS is in use, actual sample rate is double
            tis = obj.FPGA_SET_TIS(obj.flexRioAdapterModuleNameWithAppendix);
            if ~isempty(tis) && tis
                loopRateMean = loopRateMean * 2;
            end
            
            %if all checks passed, save sample rate to property            
            obj.rawSampleRateAcq = loopRateMean;            
            fprintf('FPGA digitizer module external sample clock is stable at %.3fMHz (SD: %.0fHz)\n',obj.rawSampleRateAcq/1e6,loopRateStd);
            
            %local function
            function plotMeasurement(measurements)
                persistent hFig
                if isempty(hFig) || ~ishghandle(hFig)
                    hFig = figure('Name','FPGA digitizer module sample frequency','NumberTitle','off','MenuBar','none');
                end
                
                clf(hFig);
                figure(hFig); %bring to front
                
                hAx = axes('Parent',hFig);
                plot(hAx,linspace(1,measurePeriod * numMeasurements,numMeasurements),measurements);
                title(hAx,'FPGA digitizer module sample frequency');
                xlabel(hAx,'Time [s]');
                ylabel(hAx,'Sample Frequency [Hz]');
            end
        end
        
        function NI577xMeasureSampleClockRate(obj)
            measurePeriod     = 1e-3;   % [s] count sample clock edges for measurePeriod of time
            numMeasurements   = 100;    % number of measurement repeats to calculate mean and standard deviation
            maxLoopRateStd  = 3e4;    % [Hz] TODO: need to fine tune this value (somewhat of a guess right now)
            
            obj.hFpga.checkAdapterModuleErrorState();
            
            % start measuring the sample rate
            fprintf('Measuring NI5771 sample rate...\n');
            obj.hFpga.NI5771TriggerMeasurePeriod = round(measurePeriod * obj.FPGA_SYS_CLOCK_RATE);
            measurePeriod = double(obj.hFpga.NI5771TriggerMeasurePeriod) / obj.FPGA_SYS_CLOCK_RATE; %read measure period back to account for rounding errors
            
            measurements = zeros(numMeasurements,1);
            for iter = 1:numMeasurements
                measurements(iter) = obj.hFpga.NI5771TriggerIterationsCount / measurePeriod;
                most.idioms.pauseTight(measurePeriod);
            end
            
            loopRateMean = mean(measurements);
            loopRateStd  = std(measurements);
            
            if loopRateMean < 1e3
               most.idioms.dispError(['The NI5771 sample rate  %.1fHz is suspiciously low. ',...
                   'Is the trigger connected and running?\n\n'],loopRateMean) ;
            end
               
            if loopRateStd > maxLoopRateStd
                plotMeasurement(measurements);
                error('NI5771: The external trigger of the FPGA digitizer module is unstable. Sample frequency mean: %.3EHz, SD: %.3EHz. Please make sure the trigger is connected and running.',...
                    loopRateMean,loopRateStd); % GJ 2015-03-01 <- if this check fails, we might have to adjust maxLoopRateStd
            end
            
            %if all checks passed, save sample rate to property            
            obj.sampleRateAcq = loopRateMean;
            fprintf('NI5771: The external trigger rate is stable at %.3fMHz (SD: %.0fHz)\n',obj.sampleRateAcq/1e6,loopRateStd);
            
            if strcmpi(obj.flexRioAdapterModuleNameWithAppendix,'NI5771 PhotonCounting')
                numGroups = obj.hFpga.NI5771PhotonCountingTwoGroups + 1;
            else
                numGroups = 1;
            end
            
            assert(obj.sampleRateAcq/numGroups < obj.FPGA_STATE_MACHINE_LOOP_RATE(obj.flexRioAdapterModuleNameWithAppendix),...
                'Error: The NI5771 trigger rate (%.3fMHz)is greater than the processing loop rate (%.3fMHz). This will result in lost data points!',...
                obj.sampleRateAcq/1e6,obj.FPGA_STATE_MACHINE_LOOP_RATE(obj.flexRioAdapterModuleNameWithAppendix)/1e6);
            
            %local function
            function plotMeasurement(measurements)
                persistent hFig
                if isempty(hFig) || ~ishghandle(hFig)
                    hFig = figure('Name','FPGA digitizer module sample frequency','NumberTitle','off','MenuBar','none');
                end
                
                clf(hFig);
                figure(hFig); %bring to front
                
                hAx = axes('Parent',hFig);
                plot(hAx,linspace(1,measurePeriod * numMeasurements,numMeasurements),measurements);
                title(hAx,'NI5771 Trigger rate');
                xlabel(hAx,'Time [s]');
                ylabel(hAx,'Trigger rate [Hz]');
            end
        end
        
        function fpgaUpdateLiveAcquisitionParameters(obj,property)
            if obj.acqRunning || strcmp(property,'forceall')
                obj.dispDbgMsg('Updating FPGA Live Acquisition Parameter: %s',property);
                
                if updateProp('linePhaseSamples')
                    if (obj.linePhaseSamples + obj.estimatedPeriodClockDelay) < 0
                        most.idioms.warn('Phase is too negative. Adjust the physical scan phase on the resonant driver board.');
                    end
                    
                    obj.hFpga.AcqParamLiveTriggerHoldOff = uint32(obj.triggerHoldOff);
                end
                
                beamTiming = obj.triggerHoldOff + obj.beamTiming;
                obj.hFpga.BeamClockOnForward   = beamTiming(1);
                obj.hFpga.BeamClockOffForward  = beamTiming(2);
            end
            
            % Helper function to identify which properties to update
            function tf = updateProp(currentprop)
                tf = strcmp(property,'forceall') || strcmp(property,currentprop);
            end
        end
        
        function clearAcqParamBuffer(obj)
            obj.acqParamBuffer = struct();
        end
        
        function bufferAcqParams(obj,live)
            if nargin < 2 || isempty(live)
                live = false;
            end
            
            if ~live
                obj.acqParamBuffer = struct(); % flush buffer
            end
            
            roiGroup = obj.hScan.currentRoiGroup;
            
            % generate planes to scan based on motor position etc
            if obj.hScan.hSI.hStackManager.isSlowZ
                zs = obj.hScan.hSI.hStackManager.zs(obj.hScan.hSI.hStackManager.stackSlicesDone+1);
            else
                zs = obj.hScan.hSI.hStackManager.zs;
            end
            obj.acqParamBuffer.zs = zs;

            scannerset = obj.hScan.scannerset;
            for idx = numel(zs) : -1 : 1
                [scanFields{idx},rois{idx}] = roiGroup.scanFieldsAtZ(zs(idx));
            end
            obj.acqParamBuffer.rois = rois;
            obj.acqParamBuffer.scanFields = scanFields;
            
            if ~live || obj.simulateFrameData
                [startLines,endLines] = cellfun(@(sfs)acqActiveLines(scannerset,sfs),scanFields,'UniformOutput',false);
                obj.acqParamBuffer.startLines = startLines;
                obj.acqParamBuffer.endLines   = endLines;
                obj.acqParamBuffer.numPlanes  = numel(zs);
                obj.acqParamBuffer.framesPerStack = obj.acqParamBuffer.numPlanes + obj.hScan.hSI.hFastZ.numDiscardFlybackFrames;
            end
            
            if obj.simulateFrameData
                % pack up roi info for mex;
                Nz = numel(zs);
                obj.roiDataPack = Nz;
                for i = 1:Nz
                    sfs = scanFields{i};
                    sls = startLines{i};
                    els = endLines{i};
                    Nsf = numel(sfs);
                    obj.roiDataPack(end+1) = Nsf;
                    for j = 1:Nsf
                        obj.roiDataPack(end+1) = sls(j)-1;
                        obj.roiDataPack(end+1) = els(j)-1;
                        obj.roiDataPack(end+1) = els(j) - sls(j) + 1;
                        
                        sf = sfs{j};
                        r = [sf.centerXY sf.sizeXY] - 0.5*[sf.sizeXY 0 0];
                        obj.roiDataPack(end+1) = r(1);
                        obj.roiDataPack(end+1) = r(2);
                        obj.roiDataPack(end+1) = r(3);
                        obj.roiDataPack(end+1) = r(4);
                    end
                end
                
                if live
                    ResonantAcqMex(obj,'updateRois');
                end
            end
            
            function [startAcqLines, endAcqLines] = acqActiveLines(scannerset,sfs)
                if(~isempty(sfs))
                    scanFieldsWithTransit = [{NaN} sfs]; %pre- and ap- pend "park" to the scan field sequence to transit % the FPGA clock does not tick for the frame flyback, so we do not include the global flyback here
                    transitPairs = scanimage.mroi.util.chain(scanFieldsWithTransit); %transit pairs
                    transitTimes = cellfun(@(pair) scannerset.transitTime(pair{1},pair{2}),transitPairs);
                    linePeriods  = cellfun(@(sf)scannerset.linePeriod(sf),sfs);
                    transitLines = round(transitTimes' ./ linePeriods);
                    
                    % get scanFieldLines
                    scanFieldLines = cellfun(@(sf)sf.pixelResolution(2),sfs);
                    
                    % interleave transitLines and scanFieldLines
                    assert(length(transitLines)==length(scanFieldLines));
                    lines(1:2:2*length(transitLines))  = transitLines;
                    lines(2:2:2*length(scanFieldLines))= scanFieldLines;
                    
                    lines = cumsum(lines);
                    
                    startAcqLines = lines(1:2:end) + 1;
                    endAcqLines   = lines(2:2:end);
                else
                    startAcqLines = [];
                    endAcqLines = [];
                end
            end
        end
        
        function resonantScannerFreq = calibrateResonantScannerFreq(obj,averageNumSamples)
            if nargin < 2 || isempty(averageNumSamples)
                averageNumSamples = 100;
            end
            
            if ~obj.simulated
                if ~logical(obj.hFpga.AcqStatusPeriodClockSettled)
                    resonantScannerFreq = NaN;
                else
                    t = tic;
                    nRej = obj.hFpga.AcqStatusPeriodClockRejectedPulses;
                    resonantPeriods = zeros(averageNumSamples,1);
                    resonantPeriods(1) = double(obj.hFpga.AcqStatusPeriodClockPeriod) / obj.stateMachineLoopRate;
                    for idx = 2:averageNumSamples
                        most.idioms.pauseTight(resonantPeriods(idx-1)*1.1);
                        resonantPeriods(idx) = double(obj.hFpga.AcqStatusPeriodClockPeriod) / obj.stateMachineLoopRate;
                    end
                    
                    nRej = obj.hFpga.AcqStatusPeriodClockRejectedPulses - nRej;
                    dt = toc(t);
                    rejRate = (double(nRej) / dt);
                    if rejRate > (obj.hScan.mdfData.nominalResScanFreq * .01)
                        most.idioms.warn('%d period clock pulses (%d per second) were ignored because they were out of tolerance. Period clock may be noisy.', nRej, floor(rejRate));
                    end
                    
                    if averageNumSamples > 1
                        meanp = mean(resonantPeriods);
                        stddev = std(resonantPeriods);
                        minp = meanp - 3 * stddev;
                        maxp = meanp + 3 * stddev;
                        resonantPeriodsNrm = resonantPeriods(resonantPeriods > minp);
                        resonantPeriodsNrm = resonantPeriodsNrm(resonantPeriodsNrm < maxp);
                        outliers = numel(find(resonantPeriods < minp)) + numel(find(resonantPeriods > maxp));

                        resonantFrequencies = 1 ./ resonantPeriods;
                        checkMeasurements(resonantFrequencies, outliers);
                        resonantScannerFreq = 1/mean(resonantPeriodsNrm);
                    else
                        resonantScannerFreq = 1/resonantPeriods;
                    end
                end
            else
                resonantScannerFreq = obj.hScan.mdfData.nominalResScanFreq + rand(1);
            end
            
            % nested functions
            function checkMeasurements(measurements, outliers)
                maxResFreqStd = 10;
                maxResFreqError = 0.1;
                
                resFreqMean = mean(measurements);
                resFreqStd  = std(measurements);
                
                resFreqNom = obj.hScan.mdfData.nominalResScanFreq;
                
                if abs((resFreqMean-resFreqNom)/resFreqNom) > maxResFreqError
                    most.idioms.warn('The measured resonant frequency does not match the nominal frequency. Measured: %.1fHz Nominal: %.1fHz',...
                        resFreqMean,resFreqNom) ;
                end
                
                if outliers > 0
                    if outliers > 1
                        s = 's';
                    else
                        s = '';
                    end
                    msg = sprintf('%d outlier%s will be ignored in calculation.\n',outliers,s);
                else
                    msg = '';
                end
                
                if resFreqStd > maxResFreqStd
                    plotMeasurement(measurements);
                    most.idioms.dispError(['The resonant frequency is unstable. Mean: %.1fHz, SD: %.1fHz.\n',...
                               'Possible solutions:\n\t- Reduce the zoom\n\t- increase the value of resonantScannerSettleTime in the Machine Data File\n',...
                               '\t- set hSI.hScanner(''%s'').keepResonantScannerOn = true\n%s'],...
                               resFreqMean,resFreqStd,obj.hScan.name,msg);
                end
            end
           
            function plotMeasurement(measurements)
                persistent hFig
                if isempty(hFig) || ~ishghandle(hFig)
                    hFig = figure('Name','Resonant scanner frequency','NumberTitle','off','MenuBar','none');
                end
                
                clf(hFig);
                figure(hFig); %bring to front
                
                hAx = axes('Parent',hFig);
                plot(hAx,measurements);
                title(hAx,'Resonant scanner frequency');
                xlabel(hAx,'Measurements');
                ylabel(hAx,'Resonant Frequency [Hz]');
            end
        end
    end
    
    %% INTERNAL METHODS
    methods (Access = private)        
        function fpgaStartAcquisitionParameters(obj)
            obj.dispDbgMsg('Initializing Acquisition Parameters on FPGA');
            
            %Set basic channel properties
            obj.channelsInvert = obj.hScan.mdfData.channelsInvert;
                        
            if isinf(obj.hScan.framesPerStack)
                framesPerStack_ = 0;
            else
                framesPerStack_ = obj.hScan.framesPerStack;
            end

            if isinf(obj.hScan.framesPerAcq)
                framesPerAcquisition_ = 0;
            else
                framesPerAcquisition_ = obj.hScan.framesPerAcq;
            end
            
            if isinf(obj.hScan.trigAcqNumRepeats)
                acquisitionsPerAcquisitionMode_ = 0;
            else
                acquisitionsPerAcquisitionMode_ = obj.hScan.trigAcqNumRepeats;
            end
            
            obj.hFpga.AcqParamRecordsPerFrame = obj.linesPerFrame;
            obj.hFpga.AcqParamBidirectionalAcq = obj.hScan.bidirectional;
            obj.hFpga.AcqParamFramesPerGrab = framesPerAcquisition_;
            obj.hFpga.AcqParamFramesPerStack = framesPerStack_;
            obj.hFpga.AcqParamGrabsPerAcquisition = uint16(acquisitionsPerAcquisitionMode_);
            obj.hFpga.AcqParamFlybackPeriods = obj.flybackLinesPerFrame / 2^obj.hScan.bidirectional;
            obj.hFpga.AcqParamFrameTaggingEnable = obj.frameTagging;
            obj.hFpga.DebugProduceDummyData = obj.dummyData;
            obj.hFpga.PeriodClockDebounce = ceil(obj.stateMachineLoopRate * obj.hScan.mdfData.PeriodClockDebounceTime) * logical(~obj.dummyData);
            obj.hFpga.TriggerDebounce = ceil(obj.stateMachineLoopRate * obj.hScan.mdfData.TriggerDebounceTime);
            obj.hFpga.AcqParamPixelsPerLine = obj.pixelsPerLine;
            obj.hFpga.InterlaceNumChannels = obj.interlacedNumChannels;
            obj.hFpga.AcqParamRecordFirstSampleDelay = obj.firstSampleDelayEnable;
            
            fpgaChannelsActive = obj.channelsActive-1; % fpga channels are 0-based
            switch obj.interlacedNumChannels
                case 1
                    obj.hFpga.InterlaceChannel1Select = fpgaChannelsActive(1);
                    obj.hFpga.InterlaceChannel2Select = 1;
                case 2
                    obj.hFpga.InterlaceChannel1Select = fpgaChannelsActive(1);
                    obj.hFpga.InterlaceChannel2Select = fpgaChannelsActive(2);
                case {4 16 32}
                otherwise
                    error('Something bad happened. Cannot handle %d FPGA channels',obj.interlacedNumChannels);
            end
            
            %From Georg:
            %BeamClockMode values: 'Trigger' or 'Toggle'
            %
            %Trigger: the clock signal is high for the duration of the beam
            %Toggle:  the clock signal generates a 75ns pulse when the beam changes its on/off status
            obj.hFpga.BeamClockMode = 'Trigger';
            
            if length(obj.hFpga.MaskDisableAveraging) < 4 % Older version of BitFile only supports global maskDisableAveraging
                obj.hFpga.MaskDisableAveraging = obj.hScan.maskDisableAveraging(1);
                if ~all(obj.hScan.maskDisableAveraging == obj.hScan.maskDisableAveraging(1))
                    most.idioms.warn('This bitfile does not support disabling averaging on individual channels');
                end
            else
                maskDisableAveraging = obj.hScan.maskDisableAveraging;
                maskDisableAveraging(4+1:end) = []; % trim
                maskDisableAveraging(end+1:4) = maskDisableAveraging(end);
                obj.hFpga.MaskDisableAveraging = maskDisableAveraging;
            end 
            
            
            if obj.hScan.mdfData.photonCountingEnable
                obj.hFpga.PhotonCountingEnable = true;
                
                obj.hFpga.PhotonCountingDebounce = round(obj.hScan.mdfData.photonCountingDebounce * obj.stateMachineLoopRate);
                obj.hFpga.PhotonCountScale = obj.hScan.mdfData.photonCountingScaleByPowerOfTwo; 
                
                obj.hScan.mdfData.auxTriggersEnable = false; % because FPGA PFI0..3 is used for photon counting
                obj.hScan.mdfData.I2CEnable = false; % because FPGA PFI0..3 is used for photon counting
            else
                obj.hFpga.PhotonCountingEnable = false;
            end
            
            if isprop(obj.hFpga, 'fifo_SampleScope')
                obj.enableSampleReplacement = obj.hScan.mdfData.LaserTriggerSampleMaskEnable;
                obj.hFpga.LinScanDivertSamples = false;
                obj.hFpga.ResScanFilterSamples = obj.hScan.mdfData.LaserTriggerSampleMaskEnable;
                obj.hFpga.LaserTriggerDelay = obj.hScan.mdfData.LaserTriggerSampleWindow(1);
                obj.hFpga.LaserSampleWindowSize = obj.hScan.mdfData.LaserTriggerSampleWindow(2);
                obj.hFpga.LaserTriggerFilterTicks = obj.hScan.mdfData.LaserTriggerFilterTicks;
            end
            
            % configure aux triggers
            obj.hFpga.AuxTriggerEnable = obj.hScan.mdfData.auxTriggersEnable;
            obj.hFpga.AuxTriggerDebounce = max(round(obj.hScan.mdfData.auxTriggersTimeDebounce * obj.FPGA_SYS_CLOCK_RATE),1); % could be a live prop
            obj.hFpga.AuxTriggerInvertLines = obj.hScan.mdfData.auxTriggerLinesInvert; % could be a live prop
            
            % configure I2C engine
            obj.hFpga.I2CEnable = obj.hScan.mdfData.I2CEnable;
            obj.hFpga.I2CAddress = obj.hScan.mdfData.I2CAddress;
            obj.hFpga.I2CDebounce = round(obj.hScan.mdfData.I2CDebounce * obj.stateMachineLoopRate);
            obj.hFpga.I2CDisableACKOutput = obj.hScan.mdfData.I2CDisableAckOutput;
            
            %additionally update the Live Acquisition Parameters
            if (~obj.simulated)
                obj.fpgaUpdateLiveAcquisitionParameters('forceall');
            end
        end
        
        function fpgaReset(obj)
            obj.dispDbgMsg('Resetting FPGA');
            if (~obj.simulated)
                obj.hFpga.reset();
                obj.hFpga.run();
            end
            obj.dispDbgMsg('Resetting FPGA completed');
        end
        
        function fpgaModuleName = fpgaDetectAdapterModule(obj)
            obj.dispDbgMsg('Detecting FlexRIO Adapter Module');
            
            if strncmp(obj.hScan.mdfData.fpgaModuleType, 'NI517', 5)
                fpgaModuleName = 'NI517x';
                return;
            elseif obj.simulated
                % fake adapter module
                if strfind(obj.hScan.mdfData.digitizerModuleType,'5732')
                    expectedModuleID = 278099318;
                    insertedModuleID = 278099318;
                elseif strfind(obj.hScan.mdfData.digitizerModuleType,'5733')
                    expectedModuleID = 278099319;
                    insertedModuleID = 278099319;
                else
                    % fake a NI5734 adapter module
                    expectedModuleID = 278099349;
                    insertedModuleID = 278099349;
                end
            else
                startPolling = tic;
                while obj.hFpga.AdapterModulePresent == 0 || obj.hFpga.AdapterModuleIDInserted == 0
                    pause(obj.HW_DETECT_POLLING_INTERVAL);
                    if toc(startPolling) > obj.HW_DETECT_TIMEOUT
                        error('No FlexRIO Adapter Module installed');
                    end
                end
                
                % get the adapter module name
                expectedModuleID = obj.hFpga.AdapterModuleIDExpected;
                insertedModuleID = obj.hFpga.AdapterModuleIDInserted;
            end
            
            expectedModuleName = obj.ADAPTER_MODULE_MAP(expectedModuleID);
            if isKey(obj.ADAPTER_MODULE_MAP,insertedModuleID)
                fpgaModuleName = obj.ADAPTER_MODULE_MAP(insertedModuleID);
            else
                fpgaModuleName = sprintf('Unknown Module ID: %d', insertedModuleID);
            end

            if ~obj.simulated
                %check if right module is installed
                assert(obj.hFpga.AdapterModuleIDMismatch == 0,...
                    'Wrong Adapter Module installed. Expected Module: ''%s'', Inserted Module:''%s''',...
                    expectedModuleName,fpgaModuleName);
            end
        end
        
        function fpgaStopFifo(obj)
            obj.dispDbgMsg('Stopping FIFO');

            scanimage.components.scan2d.resscan.util.flushFpgaFifo(obj.hFpga.fifo_MultiChannelToHostU64);
            obj.hFpga.fifo_MultiChannelToHostU64.stop();
            
            scanimage.components.scan2d.resscan.util.flushFpgaFifo(obj.hFpga.fifo_AuxDataToHostU64);
            obj.hFpga.fifo_AuxDataToHostU64.stop();
        end
        
        function liveFreqMeasCallback(obj,~,~)
            obj.hScan.liveScannerFreq = obj.calibrateResonantScannerFreq(1);
            obj.hScan.lastLiveScannerFreqMeasTime = clock;
        end
    end
    
    %% Private Methods for Debugging
    methods (Access = private)
        function dispDbgMsg(obj,varargin)
            if obj.debugOutput
                fprintf(horzcat('Class: ',class(obj),': ',varargin{1},'\n'),varargin{2:end});
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
