classdef ResScan < scanimage.components.Scan2D & most.HasMachineDataFile
    % ResScan - subclass of Scan2D for resonant scanning
    %   - controls a resonant(X) - galvo(X) mirror pair OR
    %              a resonant(X) - galvo(X) - galvo(Y) mirror triplet
    %   - handles the configuration of the NI-FlexRIO FPGA and digitizer
    %       module for acquiring PMT
    %   - format PMT data into images
    %   - handles acquistion timing and acquisition state
    %   - export timing signals
    
    
    %% USER PROPS
    properties (SetObservable, Transient)
        linePhaseMode = 'Nearest Neighbor';   % Specifies method for estimating line phase if it is not measured at the current resonant amplitude
        % Note: This is all just guessing. The user must either explicitly
        % set scan phases for all zoom levels or we have to make a way for
        % the scanner to automatically set the scan phase for perfect bidi
        % alignment.
        %
        % Interpolate:      Linearly interpolate between next lower and next
        %                   higher zoom factor with a set scan phase.
        % Nearest Neighbor: Choose between scan phase of next lower and next
        %                   higher zoom factor with a set scan phase, whichever zoom factor is
        %                   closest to current.
        % Next Lower:       Choose the scan phase of the next lower zoom factor
        %                   with a set scan phase.
        % Next Higher:      Choose the scan phase of the next higher zoom factor
        %                   with a set scan phase.
        
        keepResonantScannerOn = false;  % Indicates that resonant scanner should always be on. Avoids settling time and temperature drift
        sampleRate;                     % [Hz] sample rate of the digitizer; cannot be set
        pixelBinFactor = 1;             % if objuniformSampling == true, pixelBinFactor defines the number of samples used to form a pixel
        channelOffsets;                 % Array of integer values; channelOffsets defines the dark count to be subtracted from each channel if channelsSubtractOffsets is true
    end
    
    properties (SetObservable)
        uniformSampling = false;        % [logical] defines if the same number of samples should be used to form each pixel (see also pixelBinFactor); if true, the non-uniform velocity of the resonant scanner over the field of view is not corrected
        maskDisableAveraging = false;   % [logical, array] defines for each channel if averaging is enabled/disabled
    end
    
    properties (SetObservable, Hidden)
        recordScannerFeedback = false;
    end
    
    %These are stored in class data file, so don't cfg
    properties (SetObservable, Transient, Dependent)
        resonantLimitedFovMode = true;  % [logical] defines if the resonant scanner range should define the maximum range of the x-scan
        useNonlinearResonantFov2VoltsCurve = false; % [logical] activates the LUT for correcting the aspect ratio of the resonant scanner at different zoom levels
        mask;
    end
    
    %% FRIEND PROPS
    properties (Hidden)
        enableContinuousFreqMeasurement = false;
        
        useResonantTimebase = true;
        resonantSettlingPeriods = 100;
        nomResPeriodTicks;
        resonantTimebaseNominalRate = 1e6;
        resonantTimebaseTicksPerPeriod;
        scannerPeriodRTB;
        
        xGalvo;
        yGalvo;
        galvoCalibration;
        
        coercedFlybackTime;
        coercedFlytoTime;
        
        enableBenchmark = false;
        
        lastFrameAcqFcnTime = 0;
        totalFrameAcqFcnTime = 0;
        cpuFreq = 2.5e9;
        
        totalDispUpdates = 0;
        totalDispUpdateTime = 0;
    end
    
    properties (Hidden, Dependent)
        resonantScannerLastWrittenValue;
    end
    
    properties (Hidden)
        disableResonantZoomOutput = false;
        flagZoomChanged = false;        % (Logical) true if user changed the zoom via spinner controls.
        
        liveScannerFreq;
        lastLiveScannerFreqMeasTime;
    end
    
    properties (Hidden, SetAccess = ?scanimage.interfaces.Class, Dependent)
        fpgaShutterOut;     % true/false sets the digital signal on the fpgaShutterOutTerm to close/open the shutter
        fpgaShutterOutTerm; % set output terminal for shutter on FPGA
    end
 
    %% INTERNAL PROPS
    properties (Hidden, SetAccess = private)            
        hAcq;                               % handle to image acquisition system
        hCtl;                               % handle to galvo control system
        hTrig;                              % handle to trigger system
        
        hCalFig = [];
        hCalPlot = [];
        hCalPlotPt = [];
    end
    properties (Hidden, SetAccess = private)
        resonantLimitedFovMode_ = true;
        useNonlinearResonantFov2VoltsCurve_ = false;
    end
    
    properties (Hidden, SetAccess = protected, Dependent) 
        %         trigAcqInTermAllowed;               % cell array of strings with allowed terminal names for the acq trigger (e.g. {'PFI1','PFI2'})
        %         trigNextInTermAllowed;              % cell array of strings with allowed terminal names for the acq trigger (e.g. {'PFI1','PFI2'})
        %         trigStopInTermAllowed;              % cell array of strings with allowed terminal names for the acq trigger (e.g. {'PFI1','PFI2'})        
        linePhaseStep;                      % [s] minimum step size of the linephase
        
        periodsPerFrame;
        digitalIODeviceType;
        digitalIODaqName;
    end
    
    properties (Hidden, SetAccess = protected)
        %allowedTriggerInputTerminals;
        %allowedTriggerInputTerminalsMap;
        
        linePhase_;                     % Transient linePhase value set at current zoom; if non-empty will be stored to linePhaseMap on change of zoom or abort
        linePhaseMap;                   % containers.Map() that holds the LUT values for scan phase. Saved on acq abort to class data file.
        scanFreqMap;                    % containers.Map() that holds the LUT values for scan frequency. Saved on acq abort to class data file.
        resFov2VoltsMap;                % containers.Map() that holds the LUT values for scan angle to voltage conversion to correct for non linearity
        defaultRoiSize;
        angularRange;
        supportsRoiRotation = false;
    end
    
    %%% Abstract prop realizations (most.Model)
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = zlclAppendDependsOnPropAttributes(scanimage.components.Scan2D.scan2DPropAttributes());
        mdlHeaderExcludeProps = {'logFileStem' 'logFilePath' 'logFileCounter' 'channelsAvailableInputRanges'};
    end    
        
    %%% Abstract property realizations (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'ResScan';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp; %#ok<MCCPI>
        mdfPropPrefix; %#ok<MCCPI>
        
        mdfDefault = defaultMdfSection();
    end
    
    %%% Abstract prop realization (scanimage.interfaces.Component)
    properties (SetAccess = protected, Hidden)
        numInstances = 0;
    end        
    
    %%% Abstract property realizations (scanimage.subystems.Scan2D)
    properties (Constant)
        scannerType = 'Resonant';                % short description of the scanner type
        builtinFastZ = false;
    end
    
    properties (Constant, Hidden)
        linePhaseUnits = 'seconds';
    end
    
    %%% Constants
    properties (Constant, Hidden)
        MAX_NUM_CHANNELS = 4;               % Maximum number of channels supported
        
        COMPONENT_NAME = 'ResScan';                                                     % [char array] short name describing functionality of component e.g. 'Beams' or 'FastZ'
        PROP_TRUE_LIVE_UPDATE = {...              % Cell array of strings specifying properties that can be set while the component is active
            'linePhase','beamClockDelay','logFileCounter','useNonlinearResonantFov2VoltsCurve','channelsFilter'};
        PROP_FOCUS_TRUE_LIVE_UPDATE = {};    % Cell array of strings specifying properties that can be set while focusing
        DENY_PROP_LIVE_UPDATE = {'framesPerAcq','trigAcqTypeExternal',...  % Cell array of strings specifying properties for which a live update is denied (during acqState = Focus)
            'trigAcqTypeExternal','trigNextStopEnable','trigAcqInTerm',...
            'trigNextInTerm','trigStopInTerm','trigAcqEdge','trigNextEdge',...
            'trigStopEdge','stripeAcquiredCallback','logAverageFactor','logFilePath',...
            'logFileStem','logFramesPerFile','logFramesPerFileLock','logNumSlices'};
        
        FUNC_TRUE_LIVE_EXECUTION = {'readStripeData','trigIssueSoftwareAcq','measureScannerFrequency',...
            'trigIssueSoftwareNext','trigIssueSoftwareStop',...
            'plotFov2VoltageCurve','adjustResVoltageCal','clearResFov2VoltsCal',...
            'createResFov2VoltsCalControlPoint','removeResFov2VoltsCalControlPoint'};  % Cell array of strings specifying functions that can be executed while the component is active
        FUNC_FOCUS_TRUE_LIVE_EXECUTION = {}; % Cell array of strings specifying functions that can be executed while focusing
        DENY_FUNC_LIVE_EXECUTION = {'pointScanner','parkScanner','centerScanner','measureScannerFrequencySweep'};  % Cell array of strings specifying functions for which a live execution is denied (during acqState = Focus)
    end    
    
    %% Lifecycle
    methods
        function obj = ResScan(hSI, simulated, name, legacymode)
            % ResScan constructor for scanner object
            %  obj = ResScan(hSI)                 
            %  obj = ResScan(hSI, simulated)
            %  obj = ResScan(hSI, simulated, name)
            %  obj = ResScan(hSI, simulated, name, legacymode)
            
            if nargin < 2 || isempty(simulated)
                simulated = false;
            end
            
            if nargin < 3 || isempty(name)
                name = 'Resonant';
            end
            
            if nargin > 3 && ~isempty(legacymode) && legacymode
                custMdfHeading = 'ResScan';
            else
                legacymode = false;
                custMdfHeading = ['ResScan (' name ')'];
            end
            
            obj = obj@scanimage.components.Scan2D(hSI,simulated,name,legacymode);
            obj = obj@most.HasMachineDataFile(true, custMdfHeading);
            
            if obj.simulated
                obj.useResonantTimebase = false;
            end
            
            % Optionally define X-Galvo scanning hardware.
            if ~isempty(obj.mdfData.xGalvoAngularRange) && ~isempty(obj.mdfData.galvoAOChanIDX)
                obj.xGalvo = scanimage.mroi.scanners.Galvo();
                obj.xGalvo.name = sprintf('%s-X-Galvo',name);
                obj.xGalvo.waveformCacheBasePath = obj.hSI.hWaveformManager.waveformCacheBasePath;
                obj.xGalvo.travelRange = [-obj.mdfData.xGalvoAngularRange obj.mdfData.xGalvoAngularRange]./2;
                obj.xGalvo.voltsPerDistance = obj.mdfData.galvoVoltsPerOpticalDegreeX;
                obj.xGalvo.parkPosition = obj.mdfData.galvoParkDegreesX;
                obj.xGalvo.positionDeviceName = obj.mdfData.galvoDeviceName;
                obj.xGalvo.positionChannelID = obj.mdfData.galvoAOChanIDX;
                obj.xGalvo.feedbackDeviceName = obj.mdfData.galvoDeviceName;
                obj.xGalvo.feedbackChannelID = obj.mdfData.galvoAIChanIDX;
            end
            
            % Define Y-Galvo scanning hardware.
            assert(~isempty(obj.mdfData.yGalvoAngularRange),'yGalvoAngularRange is not defined in machine data file');
            obj.yGalvo = scanimage.mroi.scanners.Galvo();
            obj.yGalvo.name = sprintf('%s-Y-Galvo',name);
            obj.yGalvo.waveformCacheBasePath = obj.hSI.hWaveformManager.waveformCacheBasePath;
            obj.yGalvo.travelRange = [-obj.mdfData.yGalvoAngularRange obj.mdfData.yGalvoAngularRange]./2;
            obj.yGalvo.voltsPerDistance = obj.mdfData.galvoVoltsPerOpticalDegreeY;
            obj.yGalvo.parkPosition = obj.mdfData.galvoParkDegreesY;
            obj.yGalvo.positionDeviceName = obj.mdfData.galvoDeviceName;
            obj.yGalvo.positionChannelID = obj.mdfData.galvoAOChanIDY;
            obj.yGalvo.feedbackDeviceName = obj.mdfData.galvoDeviceName;
            obj.yGalvo.feedbackChannelID = obj.mdfData.galvoAIChanIDY;
            
            %Initialize class data file (ensure props exist in file)
            obj.zprvEnsureClassDataFileProps();
            
            %Initialize the scan maps (from values in Class Data File)
            obj.loadClassData();
            
            %Verify mdf settings
            assert(isempty(obj.mdfData.beamDaqID) || (obj.mdfData.beamDaqID <= obj.hSI.hBeams.numInstances), 'ResScan: Invalid value for beamDaqID');
            
            %Construct sub-components
            % Open FPGA acquisition adapter
            obj.hAcq = scanimage.components.scan2d.resscan.Acquisition(obj,obj.simulated);
            
            % Open scanner control adapter
            obj.hCtl = scanimage.components.scan2d.resscan.Control(obj,obj.simulated);
            
            % Open trigger routing adapter
            obj.hTrig = scanimage.components.scan2d.resscan.Triggering(obj,obj.simulated);
            
            obj.numInstances = 1; % This has to happen _before_ any properties are set
            
            % initialize scanner frequency from mdfData
            obj.scannerFrequency = obj.mdfData.nominalResScanFreq;
            
            %Initialize sub-components
            obj.hAcq.frameAcquiredFcn = @(src,evnt)obj.frameAcquiredFcn;            
            obj.hAcq.initialize();
            obj.hCtl.initialize();
            obj.hTrig.initialize();
            
            obj.channelsFilter = 'Bessel';      % channels filter type; one of {'None','Elliptic','Bessel'}
                        
            %Initialize Scan2D props (not initialized by superclass)
            obj.channelsInputRanges = repmat(obj.channelsAvailableInputRanges(1),1,obj.channelsAvailable);
            obj.channelOffsets = zeros(1, obj.channelsAvailable);
            obj.channelsSubtractOffsets = true(1, obj.channelsAvailable);
            
            if ~isempty(obj.mdfData.photonCountingDisableAveraging)
                obj.maskDisableAveraging = obj.mdfData.photonCountingDisableAveraging;
            end
            
            dev = obj.mdfData.rioDeviceID;
            if obj.hSI.fpgaDataScopeMap.isKey(dev)
                obj.hDataScope = obj.hSI.fpgaDataScopeMap(dev);
            else
                obj.hDataScope = scanimage.components.scan2d.resscan.FpgaDataScope(obj);
                obj.hSI.fpgaDataScopeMap(dev) = obj.hDataScope;
            end
        end
        
        function delete(obj)
            % delete - deletes the ResScan object, parks the mirrors and
            %   deinitializes all routes
            %   obj.delete()  returns nothing
            %   delete(obj)   returns nothing
            
            obj.safeAbortDataScope();
            
            most.idioms.safeDeleteObj(obj.hTrig);
            most.idioms.safeDeleteObj(obj.hAcq);
            most.idioms.safeDeleteObj(obj.hCtl);
            
            obj.galvoCalibration = []; % dummy set to save calibration data
            most.idioms.safeDeleteObj(obj.xGalvo);
            most.idioms.safeDeleteObj(obj.yGalvo);
            
            obj.saveMaps();
        end
    end
    
    %% PROP ACCESS METHODS
    methods
        function set.channelOffsets(obj,val)
            if ~isempty(val)
                assert(numel(val) == obj.channelsAvailable, 'Number of elements must match number of physical channels.');
                lclSubtractOffset = cast(obj.channelsSubtractOffsets,obj.channelsDataType);
                for iter = 1:min(numel(val),numel(lclSubtractOffset))
                    fpgaVal(iter) = -val(iter) * lclSubtractOffset(iter);
                end
                obj.channelOffsets = val;
                obj.hAcq.hFpga.AcqParamLiveChannelOffsets = fpgaVal;
            end
        end
        
        function set.pixelBinFactor(obj,val)
            if obj.uniformSampling
                val = obj.validatePropArg('pixelBinFactor',val);
                if obj.componentUpdateProperty('pixelBinFactor',val)
                    obj.pixelBinFactor = val;
                end
            else
                obj.errorPropertyUnSupported('pixelBinFactor',val);
            end
        end
        
        function set.sampleRate(obj,val)
            obj.errorPropertyUnSupported('sampleRate',val,'set');
            
            %side effects
            obj.linePhase = obj.linePhase;
        end
        
        function val = get.sampleRate(obj)
            val = obj.hAcq.sampleRateAcq;
        end
        
        function set.fpgaShutterOut(obj,val)
            validateattributes(val,{'logical' 'numeric'},{'binary' 'scalar'});
            obj.hAcq.hFpga.ShutterOutput = val;
        end
        
        function val = get.fpgaShutterOut(obj)
            val = obj.hAcq.hFpga.ShutterOutput;
        end
        
        function set.fpgaShutterOutTerm(obj,val)
            obj.hAcq.hFpga.ShutterTerminalOut = val;
        end
        
        function val = get.fpgaShutterOutTerm(obj)
            val = obj.hAcq.hFpga.ShutterTerminalOut;
        end
        
        function val = get.resonantScannerLastWrittenValue(obj)
           val = obj.hCtl.resonantScannerLastWrittenValue; 
        end
        
        function set.linePhaseStep(obj,val)
            obj.mdlDummySetProp(val,'linePhaseStep');
        end
        
        function val = get.linePhaseStep(obj)
            val = 1 / obj.hAcq.stateMachineLoopRate;
        end
        
        function val = get.digitalIODeviceType(obj)
            val = obj.hTrig.digitalIODeviceType;
        end
        
        function val = get.digitalIODaqName(obj)
            val = obj.hTrig.digitalIODaqName;
        end
        %         function val = get.trigNextInTermAllowed(obj)
        %             val = obj.allowedTriggerInputTerminals;
        %         end
        %
        %         function val = get.trigStopInTermAllowed(obj)
        %             val = obj.allowedTriggerInputTerminals;
        %         end
        
        function set.linePhaseMode(obj, v)
            assert(ismember(v, {'Next Lower' 'Next Higher' 'Nearest Neighbor' 'Interpolate'}), 'Invalid choice for linePhaseMode. Must be one of {''Next Lower'' ''Next Higher'' ''Nearest Neighbor'' ''Interpolate''}.');
            obj.linePhaseMode = v;
            if obj.mdlInitialized && obj.numInstances > 0
                obj.setClassDataVar('linePhaseMode',v,obj.classDataFileName);
            end
        end
        
        function set.enableContinuousFreqMeasurement(obj, v)
            if obj.componentUpdateProperty('enableContinuousFreqMeasurement',v)
                obj.enableContinuousFreqMeasurement = v;
                
                if v && strcmp(obj.hAcq.hTimerContinuousFreqMeasurement.Running,'off')
                    start(obj.hAcq.hTimerContinuousFreqMeasurement);
                else
                    stop(obj.hAcq.hTimerContinuousFreqMeasurement);
                end
            end
        end
        
        function set.keepResonantScannerOn(obj, v)
            obj.keepResonantScannerOn = v;
            if obj.mdlInitialized && obj.numInstances > 0
                obj.setClassDataVar('keepResonantScannerOn',v,obj.classDataFileName);
                if ~obj.active
                    obj.hCtl.resonantScannerActivate(v);
                end
            end
        end
        
        function set.resonantLimitedFovMode(obj,v)
            if ~v && ~obj.hCtl.xGalvoExists
                most.idioms.warn('Disabling resonant limited FOV mode is only supported for RGG scanners.');
                v = true;
            end
            
            obj.resonantLimitedFovMode_ = v;
            obj.scannerset = nan;
            
            obj.setClassDataVar('resonantLimitedFovMode',v,obj.classDataFileName);
        end
        
        function v = get.resonantLimitedFovMode(obj)
            v = obj.resonantLimitedFovMode_;
        end
        
        function set.useNonlinearResonantFov2VoltsCurve(obj,v)
            v = obj.validatePropArg('useNonlinearResonantFov2VoltsCurve',v);
            if obj.componentUpdateProperty('useNonlinearResonantFov2VoltsCurve',v)
                obj.useNonlinearResonantFov2VoltsCurve_ = v;
                obj.setClassDataVar('useNonlinearResonantFov2VoltsCurve',v,obj.classDataFileName);
                if v
                    if obj.mdlInitialized
                        obj.plotFov2VoltageCurve();
                    end
                    
                    if abs((obj.mdfData.resonantAngularRange * obj.mdfData.rScanVoltsPerOpticalDegree) - obj.zzzResonantFov2Volts(1)) > 0.01
                        most.idioms.warn('FOV to voltage map value for FOV=1 is not consistent with mdf. Map may need to be reset.');
                    end
                end
                
                obj.updateLiveValues();
            end
        end
        
        function v = get.useNonlinearResonantFov2VoltsCurve(obj)
            v = obj.useNonlinearResonantFov2VoltsCurve_;
        end
        
        function val = get.mask(obj)
            obj.hAcq.computeMask();
            val = obj.hAcq.mask;
        end
        
        function sz = get.defaultRoiSize(obj)
            scales = abs(obj.scannerToRefTransform([1 5]));
            if obj.resonantLimitedFovMode
                sz = min(obj.angularRange .* scales);
            else
                sz = min([obj.mdfData.resonantAngularRange obj.mdfData.yGalvoAngularRange] .* scales);
            end
        end
        
        function rg = get.angularRange(obj)
            if obj.resonantLimitedFovMode
                x = obj.mdfData.resonantAngularRange;
            else
                x = obj.mdfData.xGalvoAngularRange + obj.mdfData.resonantAngularRange;
            end
            rg = [x obj.mdfData.yGalvoAngularRange];
        end
        
        function set.uniformSampling(obj,v)
            if obj.componentUpdateProperty('uniformSampling',v)
                obj.uniformSampling = v;
                obj.scanPixelTimeMean = nan;
            end
        end
        
        function set.maskDisableAveraging(obj,v)
            if obj.componentUpdateProperty('maskDisableAveraging',v)
                validateattributes(v,{'numeric','logical'},{'binary'});
                assert(length(v) <= obj.channelsAvailable);
                v(end+1:obj.channelsAvailable) = v(end);
                obj.maskDisableAveraging = v;
                
                if ~isempty(obj.mdfData.photonCountingDisableAveraging)
                    mdf = most.MachineDataFile.getInstance();
                    if mdf.isLoaded
                        obj.writeVarToHeading('writeVarToHeading',v);
                        obj.mdfData.photonCountingDisableAveraging = v;
                    end
                end
            end
        end
        
        function set.galvoCalibration(obj,val)
            obj.setClassDataVar('galvoCalibration',obj.galvoCalibration,obj.classDataFileName);
        end
        
        function val = get.galvoCalibration(obj)
            val = struct();
            if ~isempty(obj.xGalvo)
                val.xGalvo = obj.xGalvo.hDevice.calibrationData;
            end
            
            if ~isempty(obj.yGalvo)
                val.yGalvo = obj.yGalvo.hDevice.calibrationData;
            end
        end
        
        function v = get.coercedFlybackTime(obj)
            numScannerPeriods = ceil(obj.flybackTimePerFrame * obj.scannerFrequency);
            v = numScannerPeriods / obj.scannerFrequency;
        end
        
        function v = get.coercedFlytoTime(obj)
            numScannerPeriods = ceil(obj.flytoTimePerScanfield * obj.scannerFrequency);
            v = numScannerPeriods / obj.scannerFrequency;
        end
    end
      
    %%% Abstract method implementations (scanimage.components.Scan2D)
    % AccessXXX prop API for Scan2D
    methods (Access = protected, Hidden)
        function val = accessScannersetPostGet(obj,~)
            % Determine flyback time per frame
            if obj.hSI.hStackManager.isFastZ && strcmp(obj.hSI.hFastZ.waveformType, 'step')
                numScannerPeriods = ceil(obj.hSI.hFastZ.flybackTime * obj.scannerFrequency);
                flybackTime = max(obj.coercedFlybackTime, numScannerPeriods / obj.scannerFrequency);
            else
                flybackTime = obj.coercedFlybackTime;
            end
            
            % Define Resonant Scanning Hardware.
            r = scanimage.mroi.scanners.Resonant(obj.mdfData.resonantAngularRange,...
                @obj.zzzResonantFov2Volts,...
                obj.bidirectional,...
                1/obj.scannerFrequency,...
                obj.fillFractionSpatial,...
                obj.hCtl.rateAOSampClk);
            
            % Define Y-Galvo Scanning Hardware.
            assert(~isempty(obj.yGalvo),'yGalvo is not defined in machine data file');
            obj.yGalvo.travelRange = [-obj.mdfData.yGalvoAngularRange obj.mdfData.yGalvoAngularRange]./2;
            obj.yGalvo.voltsPerDistance = obj.mdfData.galvoVoltsPerOpticalDegreeY;
            obj.yGalvo.flytoTimeSeconds = obj.coercedFlytoTime;
            obj.yGalvo.flybackTimeSeconds = flybackTime;
            obj.yGalvo.sampleRateHz = obj.hCtl.rateAOSampClk;
            obj.yGalvo.useScannerTimebase = obj.useResonantTimebase;
            
            % Define X-Galvo Scanning Hardware.
            if ~isempty(obj.xGalvo)
                obj.xGalvo.travelRange = [-obj.mdfData.xGalvoAngularRange obj.mdfData.xGalvoAngularRange]./2;
                obj.xGalvo.voltsPerDistance = obj.mdfData.galvoVoltsPerOpticalDegreeX;
                obj.xGalvo.flytoTimeSeconds = obj.coercedFlytoTime;
                obj.xGalvo.flybackTimeSeconds = flybackTime;
                obj.xGalvo.sampleRateHz = obj.hCtl.rateAOSampClk;
                obj.xGalvo.useScannerTimebase = obj.useResonantTimebase;
            end
            
            % Define beam hardware
            if obj.hSI.hBeams.numInstances && ~isempty(obj.mdfData.beamDaqID)
                beams = obj.hSI.hBeams.scanner(obj.mdfData.beamDaqID,[],obj.linePhase,obj.beamClockDelay,obj.beamClockExtend);
            else
                beams = [];
            end
            
            % Define fastz hardware
            fastz = obj.hSI.hFastZ.scanner(obj.name);
            if ~isempty(fastz) && obj.useResonantTimebase
                fastz.sampleRateHz = 200e3;
            end
            
            % Create resonant galvo galvo scannerset using hardware descriptions above
            val=scanimage.mroi.scannerset.ResonantGalvoGalvo(obj.name,r,obj.xGalvo,obj.yGalvo,beams,fastz,obj.fillFractionSpatial);
            val.resonantLimitedFovMode = obj.resonantLimitedFovMode;
            val.modifiedTimebaseSecsPerSec = obj.scannerFrequency * obj.resonantTimebaseTicksPerPeriod / obj.resonantTimebaseNominalRate;
        end
        
        function accessBidirectionalPostSet(obj,~)
%             %Side-effects                        
%             obj.linesPerFrame = obj.linesPerFrame;                  % make sure that linesPerFrame is even when bidirectional scanning
%             obj.flybackLinesPerFrame = obj.flybackLinesPerFrame;    % make sure that flybackLinesPerFrame is even when bidirectional scanning
%                                     
%             obj.hAcq.computeMask();
%             obj.hAcq.flagResizeAcquisition = true;
        end
        
        function val = accessStripingEnablePreSet(~,val)
            % unsupported in ResScan
            val = false;
        end
        
        function val = accessLinePhasePreSet(obj,val)
            
            v = obj.hCtl.resonantScannerLastWrittenValue;
            
            if isempty(v) || v == 0
                try
                    v = obj.hCtl.nextResonantVoltage;
                catch
                end
            end
            
            if ~obj.robotMode && ~obj.flagZoomChanged && obj.mdlInitialized && (v > 0)
                % line phase is measured in seconds
                samples = round((val) * obj.hAcq.stateMachineLoopRate);
                val = samples / obj.hAcq.stateMachineLoopRate ; % round to closest possible value
                
                %Only cache the linePhase vlaue when its values have been adjusted by the user
                obj.linePhaseMap(round(v*1000)/1000) = val;
            end
            
            obj.flagZoomChanged = false;
        end
        
        function accessLinePhasePostSet(obj)
            obj.hAcq.fpgaUpdateLiveAcquisitionParameters('linePhaseSamples');
        end
        
        function val = accessLinePhasePostGet(obj,val)
            % No-op
        end
        
        function val = accessChannelsFilterPostGet(~,val)
            % no-op
        end
        
        function val = accessChannelsFilterPreSet(obj,val)
            val = obj.hAcq.hFpga.setChannelFilter(val);
        end
        
        function accessBeamClockDelayPostSet(obj,~)            
            obj.hAcq.fpgaUpdateLiveAcquisitionParameters('beamClockDelay'); %The delay applies to the 'head', not 'tail' of the beam buffer
        end
        
        function accessBeamClockExtendPostSet(obj,~)
            if obj.active
                obj.hSI.hBeams.updateBeamBufferAsync(true);
            end
        end
        
        function accessChannelsAcquirePostSet(obj,~)
            obj.hAcq.flagResizeAcquisition = true;
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function val = accessChannelsInputRangesPreSet(obj,val)
            val = obj.hAcq.hFpga.setInputRanges(val);
        end
        
        function val = accessChannelsInputRangesPostGet(~,val)
            %No-op
        end
        
        function val = accessChannelsAvailablePostGet(obj,~)
            val = obj.hAcq.adapterModuleChannelCount;
        end
        
        function val = accessChannelsAvailableInputRangesPostGet(obj,~)
            upperLimits = obj.hAcq.ADAPTER_MODULE_AVAIL_INPUT_RANGES(obj.hAcq.flexRioAdapterModuleNameWithAppendix);
            upperLimits = sort(upperLimits,'descend');
            numRanges = length(upperLimits);
            val = cell(1,numRanges);
            for i = 1:numRanges
                val{i} = [-upperLimits(i) upperLimits(i)];
            end
        end
                     
        function val = accessFillFractionSpatialPreSet(obj,val)
            try
                if ~obj.uniformSampling
                    scanimage.util.computeresscanmask(obj.scannerFrequency, obj.sampleRate, val, obj.hAcq.pixelsPerLine);
                end
            catch
                most.idioms.warn('Attempted to set fill fraction too low.', val);
                val = obj.fillFractionSpatial;
            end
        end
                     
        function accessFillFractionSpatialPostSet(obj,~)
            obj.hAcq.computeMask();
        end
        
        function val = accessSettleTimeFractionPostSet(obj,val)
            obj.errorPropertyUnSupported('settleTimeFraction',val);
        end
        
        function val = accessFlytoTimePerScanfieldPostGet(obj,val)
            val = max(val, 1/obj.scannerFrequency);
        end
        
        function val = accessFlybackTimePerFramePostGet(obj,val)
            val = max(val, 1/obj.scannerFrequency);
        end
        
        function accessLogAverageFactorPostSet(obj,~)
            obj.hAcq.flagResizeAcquisition = true;
        end
        
        function accessLogFileCounterPostSet(obj,~)
            obj.hAcq.flagResizeAcquisition = true;
        end
        
        function accessLogFilePathPostSet(obj,~)
            obj.hAcq.flagResizeAcquisition = true;
        end
        
        function accessLogFileStemPostSet(obj,~)
            obj.hAcq.flagResizeAcquisition = true;
        end
        
        function accessLogFramesPerFilePostSet(obj,~)
            obj.hAcq.flagResizeAcquisition = true;
        end

        function accessLogFramesPerFileLockPostSet(obj,~)
            obj.hAcq.flagResizeAcquisition = true;
        end
        
        function val = accessLogNumSlicesPreSet(obj,val)
            obj.hAcq.loggingNumSlices = val;
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function val = accessTrigFrameClkOutInternalTermPostGet(obj,~)
            val = obj.hTrig.readInternalTerminalName('frameClockOut');
        end
        
        function val = accessTrigBeamClkOutInternalTermPostGet(obj,~)
            val = obj.hTrig.readInternalTerminalName('beamModifiedLineClockOut');
        end
        
        function val = accessTrigAcqOutInternalTermPostGet(obj,~)
            val = obj.hTrig.readInternalTerminalName('acqTriggerOut');
        end
        
        function val = accessTrigReferenceClkOutInternalTermPostGet(~,~)
            val = 'PXI_CLK10';
        end
        
        function val = accessTrigReferenceClkOutInternalRatePostGet(~,~)
            val = 10e6;
        end
        
        function val = accessTrigReferenceClkInInternalTermPostGet(~,~)
            val = 'PXI_CLK10';
        end
        function val = accessTrigReferenceClkInInternalRatePostGet(~,~)
            val = 10e6;
        end  
        function val = accessTrigAcqInTermAllowedPostGet(obj,~) 
            val = obj.hTrig.externalTrigTerminalOptions;
        end
        
        function val = accessTrigNextInTermAllowedPostGet(obj,~)
            val = obj.hTrig.externalTrigTerminalOptions;
        end
        
        function val = accessTrigStopInTermAllowedPostGet(obj,~)
            val = obj.hTrig.externalTrigTerminalOptions;
        end
             
        function val = accessTrigAcqEdgePreSet(obj,val)    
            obj.hTrig.acqTriggerOnFallingEdge = strcmp(val,'falling');
        end
        
        function accessTrigAcqEdgePostSet(~,~)
            % Nothing to do here
        end
        
        function val = accessTrigAcqInTermPreSet(obj,val)                        
            if isempty(val)
                obj.trigAcqTypeExternal = false;
            end
            obj.hTrig.acqTriggerIn = val;
        end
        
        function accessTrigAcqInTermPostSet(~,~)
            % Nothing to do here
        end
        
        function val = accessTrigAcqInTermPostGet(obj,~)
            val = obj.hTrig.acqTriggerIn;
        end
        
        function val = accessTrigAcqTypeExternalPreSet(obj,val)
            val = logical(val); % convert 'binaryflex' to 'logcial'
        end
        
        function accessTrigAcqTypeExternalPostSet(~,~)
             %No-op        
        end
        
        function val = accessTrigNextEdgePreSet(obj,val)
            obj.hTrig.nextFileMarkerOnFallingEdge = strcmp(val,'falling');
        end
        
        function val = accessTrigNextInTermPreSet(obj,val)
            obj.hTrig.nextFileMarkerIn = val;
        end
        
        function val = accessTrigNextStopEnablePreSet(~,~)
            val = true; % the FPGA can handle Next and Stop triggering at all times. no need to deactivate it               
        end
        
        function val = accessTrigStopEdgePreSet(obj,val)
            obj.hTrig.acqStopTriggerOnFallingEdge = strcmp(val,'falling');
        end
        
        function val = accessFunctionTrigStopInTermPreSet(obj,val)
            %termName = obj.allowedTriggerInputTerminalsMap(val); % qualify terminal name (e.g. DIO0.1 -> /FPGA/DIO0.1)
            obj.hTrig.acqStopTriggerIn = val;
        end
        
        function val = accessMaxSampleRatePostGet(obj,~)
            val = obj.sampleRate;
        end
        
        function accessScannerFrequencyPostSet(obj,~)
            obj.nomResPeriodTicks = floor(obj.hAcq.stateMachineLoopRate / obj.scannerFrequency);
            obj.resonantTimebaseTicksPerPeriod = floor(obj.resonantTimebaseNominalRate / obj.scannerFrequency);
            obj.scannerPeriodRTB = obj.resonantTimebaseTicksPerPeriod / obj.resonantTimebaseNominalRate;
        end
        
        function val = accessScannerFrequencyPostGet(~,val)
            % No op
        end

        function val = accessScanPixelTimeMeanPostGet(obj,~)
            if ~obj.active
                % if acq is active, let this occur automatically
                ppl = obj.getPixPerLine();
                if isempty(ppl) || ppl < 4
                    val = nan;
                    return;
                end
                obj.hAcq.pixelsPerLine = ppl;
                obj.hAcq.computeMask();
            end
            val = (sum(obj.hAcq.mask(1:obj.hAcq.pixelsPerLine)) / obj.sampleRate) / obj.hAcq.pixelsPerLine;
        end
        
        function val = accessScanPixelTimeMaxMinRatioPostGet(obj,~)
            if isnan(obj.scanPixelTimeMean)
                val = nan;
            else
                maxPixelSamples = double(max(obj.hAcq.mask(1:obj.hAcq.pixelsPerLine)));
                minPixelSamples = double(min(obj.hAcq.mask(1:obj.hAcq.pixelsPerLine)));
                val = maxPixelSamples / minPixelSamples;
            end
        end
        
        function val = accessChannelsAdcResolutionPostGet(obj,~)
            val = obj.hAcq.ADAPTER_MODULE_ADC_BIT_DEPTH(obj.hAcq.flexRioAdapterModuleNameWithAppendix);
        end
        
        function val = accessChannelsDataTypePostGet(~,~)
            val = 'int16';
        end
        
        % Component overload function
        function val = componentGetActiveOverride(obj,~)
            val = obj.hAcq.acqRunning;
        end
        
        function val = accessScannerToRefTransformPreSet(obj,val)
            assert(~scanimage.mroi.util.isTransformRotating(val),'ResScan affine cannot contain rotational component.');
            assert(~scanimage.mroi.util.isTransformShearing(val),'ResScan affine cannot contain shearing component.');
            assert(~scanimage.mroi.util.isTransformPerspective(val),'ResScan affine cannot contain perspective component.');
        end
        
        function accessChannelsSubtractOffsetsPostSet(obj)
            obj.channelOffsets = obj.channelOffsets; % update offsets on FPGA            
        end
    end
    
    %% USER METHODS
    
    %%% Abstract methods realizations (scanimage.interfaces.Scan2D)
    methods
        
        % methods to issue software triggers
        % these methods should only be effective if specified trigger type
        % is 'software'
        function trigIssueSoftwareAcq(obj)
            % trigIssueSoftwareAcq issues a software acquisition start trigger
            %   if ReScan is started, this will start an acquisition
            %   
            %   obj.trigIssueSoftwareAcq()  returns nothing
            
            if obj.componentExecuteFunction('trigIssueSoftwareAcq')
                obj.hAcq.generateSoftwareAcqTrigger();
            end
        end
        
        function trigIssueSoftwareNext(obj)
            % trigIssueSoftwareNext issues a software acquisition next trigger
            %   if ReScan is in an active acquisition, this will roll over the current acquisition
            %   
            %   obj.trigIssueSoftwareNext()  returns nothing
            
            if obj.componentExecuteFunction('trigIssueSoftwareNext')
                obj.hAcq.generateSoftwareNextFileMarkerTrigger();
            end
        end
        
        function trigIssueSoftwareStop(obj)
	        % trigIssueSoftwareStop issues a software acquisition stop trigger
            %   if ReScan is in an active acquisition, this stop the current acquisition
            %   
            %   obj.trigIssueSoftwareStop()  returns nothing
            
            if obj.componentExecuteFunction('trigIssueSoftwareStop')
                obj.hAcq.generateSoftwareAcqStopTrigger();
            end
        end
        
        function pointScanner(obj,fastDeg,slowDeg)
            % pointScanner moves the scanner to the defined angles (in degrees)
            %
            %   obj.pointScanner(fastDeg,slowDeg)   activates the resonant scanner with amplitude 'fastDeg' and points the galvo scanner to position 'slowDeg'
            %           slowDeg can be scalar (y-galvo only) or a 1x2 array [xGalvoDegree, yGalvoDegree]
            
            % points the XY scanner to a position (units: degree)
            if obj.componentExecuteFunction('pointScanner',fastDeg,slowDeg)
                obj.hCtl.pointResAmplitudeDeg(fastDeg);
                
                if isempty(obj.xGalvo)
                    obj.yGalvo.hDevice.pointPosition(slowDeg);
                else
                    validateattributes(slowDeg,{'numeric'},{'numel',2});
                    obj.xGalvo.hDevice.pointPosition(slowDeg(1));
                    obj.yGalvo.hDevice.pointPosition(slowDeg(2));
                end
            end
        end
        
        function centerScanner(obj)
            % centerScanner deactivates the resonant scanner and centers the x and y galvos
            % 
            %   obj.centerScanner()   returns nothing
            
            if obj.componentExecuteFunction('centerScanner')
                obj.hCtl.pointResAmplitudeDeg(0);
                obj.hCtl.centerGalvo();
            end
        end
        
        function parkScanner(obj)
            % parkScanner parks the x and y galvo scanner,
            %         deactivates resonant scanner if obj.keepResonantScannerOn == false
            %
            %   obj.parkScanner()  returns nothing
            
            if obj.componentExecuteFunction('parkScanner')
                obj.hCtl.parkGalvo();
                if obj.mdlInitialized
                    if obj.keepResonantScannerOn && obj ~= obj.hSI.hScan2D
                        % this is to prevent an error during switching the
                        % imaging system: after switching the imaging
                        % system all scanners are parked. However, the
                        % if keepResonantScanner == true,
                        % resonantSCannerActivate queries the roiGroup to
                        % determine the next output voltage. since
                        % roiGroupDefault now spans the FOV of a
                        % different scanner, the output voltage could be
                        % out of range. In this case, don't update the
                        % voltage from the roigroup, but just apply the
                        % last written value instead
                        obj.hCtl.resonantScannerActivate(true,obj.hCtl.resonantScannerLastWrittenValue);
                    else
                        obj.hCtl.resonantScannerActivate(obj.keepResonantScannerOn);
                    end
                end
            end
        end
        
        function updateLiveValues(obj,regenAO)
            % updateLiveValues updates the scanner output waveforms after
            %       scan parameters have changed
            %
            %   obj.updateLiveValues()          regenerates the output waveforms and updates the output buffer
            %   obj.updateLiveValues(regenAO)   if regenAO == true regenerates the output waveforms, then updates the output buffer
            
            if nargin < 2
                regenAO = true;
            end
            
            obj.hCtl.updateLiveValues(regenAO);
            
            if obj.active && strcmpi(obj.hSI.acqState,'focus')
                obj.hAcq.bufferAcqParams(true);
            end
            
            obj.updateFov2VoltageCurvePlot();
        end
        
        function updateSliceAO(obj)
            % updateSliceAO updates the scan paramters during a slow-z
            %    stack and refreshes the output waveforms
            %
            %  obj.updateSliceAO()
            
            obj.hAcq.bufferAcqParams(false);
            obj.hCtl.updateLiveValues(false,true);
        end
    end
    
    %%% Resonant scanning specific methods
    methods
        function calibrateGalvos(obj)
            hWb = waitbar(0,'Calibrating Scanner','CreateCancelBtn',@(src,evt)delete(ancestor(src,'figure')));
            try
                obj.scannerset.calibrateScanner('G');
                obj.galvoCalibration = []; % dummy set to store calibration
            catch ME
                hWb.delete();
                rethrow(ME);
            end
            hWb.delete();
        end
        
        function resFreq = measureScannerFrequency(obj)
            % measureScannerFrequency activates the resonant scanner with
            %   the currently selected amplitude and measures the resonant
            %   frequency
            %
            %   resFreq = obj.measureScannerFrequency()   returns the measured resonant frequency
            
            if obj.componentExecuteFunction('measureScannerFrequency')
                
                if ~obj.active
                    obj.hCtl.resonantScannerActivate(true);
                    
                    %update parameters
                    period = obj.hAcq.stateMachineLoopRate / obj.mdfData.nominalResScanFreq;
                    obj.hAcq.hFpga.NominalResonantPeriodTicks = round(period);
                    obj.hAcq.hFpga.MaxResonantPeriodTicks = floor(period*1.1);
                    obj.hAcq.hFpga.MinResonantPeriodTicks = floor(period*0.9);
                    
                    v = obj.hCtl.resonantScannerLastWrittenValue;
                    fprintf('Measuring scanner frequency at zoom voltage of %.3fV...\n',v);
                    
                    % assumption: the scanner frequency should be settled after 2 seconds
                    obj.hCtl.resonantScannerWaitSettle(max(2,obj.mdfData.resonantScannerSettleTime));
                    
                    resFreq = obj.hAcq.calibrateResonantScannerFreq();
                    
                    if ~(obj.active || obj.keepResonantScannerOn)
                        obj.hCtl.resonantScannerActivate(false);
                    end
                    
                    if isnan(resFreq)
                        most.idioms.dispError('Failed to read scanner frequency. Period clock pulses not detected.\nVerify zoom control/period clock wiring and MDF settings.\n');
                    else
                        fprintf('Scanner Frequency calibrated: %.2fHz\n',resFreq);
                        obj.scanFreqMap(round(v*1000)/1000) = resFreq;
                        
                        if ~obj.active
                            %Side-effects
                            obj.scannerFrequency = resFreq;
                            obj.hAcq.computeMask();
                            obj.saveMaps(false,true);
                        end
                    end
                    
                elseif obj.enableContinuousFreqMeasurement
                    
                    if isempty(obj.lastLiveScannerFreqMeasTime)
                        fprintf('Continuous measurement is enabled but no reading has been made yet.\n');
                    else
                        v = obj.hCtl.resonantScannerLastWrittenValue;
                        resFreq = obj.liveScannerFreq;
                        
                        fprintf('Continuous measurement is enabled. Last sample was taken %.2f seconds ago for zoom voltage of %.3fV: %.2fHz\n',etime(clock,obj.lastLiveScannerFreqMeasTime),v,resFreq);
                        
                        obj.scanFreqMap(round(v*1000)/1000) = resFreq;
                    end
                end
            end
        end
        
        function measureScannerFrequencySweep(obj,measPoints)
            % measureScannerFrequency activates the resonant scanner and measures resonant frequency at
            %    each amplitude in measPoints; the calibration data is stored in the object
            %
            %    obj.measureScannerFrequencySweep(measPoints)   calibrates the resonant frequency for measPoints - a 1xN numeric
            %                 array with voltage amplitudes of the resonant scanner
            
            if obj.componentExecuteFunction('measureScannerFrequencySweep')
                N = numel(measPoints);
                if N > 1
                    fprintf('Measuring scanner frequency at %d points. Press ctrl+c to cancel at any time.\n', N);
                end
                
                measPoints = round(measPoints*1000)/1000;
                
                onCleanup(@()cancelFunc);
                messy = false;
                
                for i = 1:N
                    messy = true;
                    fprintf('Measuring scanner frequency at amplitude of %.3fV (point %d of %d)... ', measPoints(i), i, N);
                    
                    obj.hCtl.resonantScannerActivate(true,measPoints(i));
                    obj.hCtl.resonantScannerWaitSettle(2);
                    resFreq = obj.hAcq.calibrateResonantScannerFreq();
                    obj.hCtl.resonantScannerActivate(false);
                    
                    if isnan(resFreq)
                        most.idioms.dispError('\nFailed to read scanner frequency. Period clock pulses not detected.\nVerify zoom control/period clock wiring and MDF settings.\n');
                        messy = false;
                        return;
                    else
                        fprintf('Done. Result: %.2fHz\n', resFreq);
                        messy = false;

                        obj.scanFreqMap(measPoints(i)) = resFreq;
                        obj.saveMaps(false, true);
                    end
                end
            end
            
            function cancelFunc
                if messy
                    obj.hCtl.resonantScannerActivate(false);
                    fprintf('Cancelled.\n');
                end
            end
        end
        
        function plotFov2VoltageCurve(obj)
            % plotFov2VoltageCurve shows the resonant scanner amplitude
            %    correction curve for different zoom levels
            %
            %   obj.plotFov2VoltageCurve()  returns nothing            
            
            if obj.componentExecuteFunction('plotFov2VoltageCurve')
                if(isempty(cell2mat(obj.resFov2VoltsMap.keys)))
                    obj.clearResFov2VoltsCal();
                end
                
                if ~obj.useNonlinearResonantFov2VoltsCurve
                    most.idioms.warn('''useNonlinearResonantFov2VoltsCurve'' is turned off. This curve is not actually being used for resonant mirror control. Set ''useNonlinearResonantFov2VoltsCurve'' to true to enable.')
                end
                
                fov = obj.hCtl.nextResonantFov;
                if fov >= 1.0001
                    fov = 1;
                end
                
                if most.idioms.isValidObj(obj.hCalFig)
                    figure(obj.hCalFig);
                    set(obj.hCalPlot, 'XData', cell2mat(obj.resFov2VoltsMap.keys), 'YData', cell2mat(obj.resFov2VoltsMap.values));
                    set(obj.hCalPlotPt, 'XData', fov, 'YData', obj.zzzResonantFov2Volts(fov));
                    set(obj.hCalFig, 'Visible', 'on');
                    set(findall(obj.hCalFig,'Tag','enableCurve'),'Value',obj.useNonlinearResonantFov2VoltsCurve);
                else
                    obj.hCalFig = figure('Name','Resonant FOV to Voltage Calibration Curve','NumberTitle','off','Color','White','MenuBar','none');
                    hmain=most.idioms.uiflowcontainer('Parent',obj.hCalFig,'FlowDirection','TopDown');
                        a = axes('Parent',hmain,'FontSize',12,'FontWeight','Bold');
                        obj.hCalPlot = plot(cell2mat(obj.resFov2VoltsMap.keys), cell2mat(obj.resFov2VoltsMap.values),'k.-','Parent',a,'MarkerSize',20,'LineWidth',2);
                        hold on;
                        obj.hCalPlotPt = plot(fov, obj.zzzResonantFov2Volts(fov),'ro','MarkerSize',10,'LineWidth',2,'Parent',a);
                        title('Resonant FOV to Voltage Calibration Curve','FontSize',12,'FontWeight','Bold');

                        xlabel('FOV','FontWeight','Bold');
                        xlim(a,[-.05 1.05]);

                        ylabel('Voltage (V)','FontWeight','Bold');
                        ylim(a,[-.1 5.1]);

                        grid(a,'on');
                        
                        bottompanel=uipanel('parent',hmain,'Title','Edit curve','FontSize',10);
                                set(bottompanel,'HeightLimits',[45 45]);
                                
                                hbottom = most.idioms.uiflowcontainer('Parent',bottompanel,'FlowDirection','LeftToRight');
                                uicontrol('parent',hbottom,'style','checkbox','string','Enable','Callback',@(src,evt)toggleEnable(),'Tag','enableCurve','Value',obj.useNonlinearResonantFov2VoltsCurve);
                                
                                uicontrol('parent',hbottom,'style','pushbutton','Callback',@(src,evt)adjustZoomFactor(1),'string','Zoom +');
                                uicontrol('parent',hbottom,'style','pushbutton','Callback',@(src,evt)adjustZoomFactor(-1),'string','Zoom -');
                                
                                uicontrol('parent',hbottom,'style','pushbutton','Callback',@(src,evt)obj.clearResFov2VoltsCal(),'string','Reset');
                                uicontrol('parent',hbottom,'style','pushbutton','Callback',@(src,evt)obj.createResFov2VoltsCalControlPoint(),'string','Add Point');
                                uicontrol('parent',hbottom,'style','pushbutton','Callback',@(src,evt)obj.removeResFov2VoltsCalControlPoint(),'string','Del Point');
                                
                                ad1 = uicontrol('parent',hbottom,'style','pushbutton','Callback',@(src,evt)obj.adjustResVoltageCal(-0.03),'string',char(8650),'FontName','Arial Unicode MS');
                                ad2 = uicontrol('parent',hbottom,'style','pushbutton','Callback',@(src,evt)obj.adjustResVoltageCal(-0.005),'string',char(8595),'FontName','Arial Unicode MS');
                                ad3 = uicontrol('parent',hbottom,'style','pushbutton','Callback',@(src,evt)obj.adjustResVoltageCal(0.005),'string',char(8593),'FontName','Arial Unicode MS');
                                ad4 = uicontrol('parent',hbottom,'style','pushbutton','Callback',@(src,evt)obj.adjustResVoltageCal(0.03),'string',char(8648),'FontName','Arial Unicode MS');
                                set([ad1 ad2 ad3 ad4],'WidthLimits',[40 40]);
                end
            end
            
            function adjustZoomFactor(val)
                obj.hSI.hRoiManager.scanZoomFactor = max(1,obj.hSI.hRoiManager.scanZoomFactor + val);
            end
            
            function toggleEnable()
                obj.useNonlinearResonantFov2VoltsCurve = ~obj.useNonlinearResonantFov2VoltsCurve;
            end
        end
        
        function createResFov2VoltsCalControlPoint(obj, fov, interpRange)
            % createResFov2VoltsCalControlPoint  adds a calibration point
            %   to the curve used for correcting the resonant scanner
            %   amplitude at different zoom levels
            %
            %   obj.createResFov2VoltsCalControlPoint()     creates a calibration point on the curve at the current zoom level
            %   obj.createResFov2VoltsCalControlPoint(fov)  creates a calibration point on the curve at the amplitued given by fov
            %   obj.createResFov2VoltsCalControlPoint(fov, interpRange) creates one calibration point at fov, one at fov-interpRange and one at fov+interpRange
            
            if obj.componentExecuteFunction('createResFov2VoltsCalControlPoint')
                % if interp range is non zero, two additional control points are created at the specified distance from the main point
                % to limit the range of effect on the interpolated curve
                if nargin < 2 || isempty(fov)
                    fov = obj.hCtl.nextResonantFov;
                end
                
                if ~obj.useNonlinearResonantFov2VoltsCurve
                    most.idioms.warn('''useNonlinearResonantFov2VoltsCurve'' is turned off. This curve is not actually being used for resonant mirror control. Set ''useNonlinearResonantFov2VoltsCurve'' to true to enable.')
                end
                
                fov = round(fov*100000)/100000;
                obj.resFov2VoltsMap(fov) = obj.zzzResonantFov2Volts(fov);
                
                if nargin > 2 && ~isempty(interpRange) && interpRange > 0
                    fovh = round((fov + interpRange)*100000)/100000;
                    if fovh < obj.mdfData.resonantAngularRange * obj.mdfData.rScanVoltsPerOpticalDegree
                        obj.resFov2VoltsMap(fovh) = obj.zzzResonantFov2Volts(fovh);
                    end
                    fovl = round((fov - interpRange)*100000)/100000;
                    if fovl > 0
                        obj.resFov2VoltsMap(fovl) = obj.zzzResonantFov2Volts(fovl);
                    end
                end
                obj.updateFov2VoltageCurvePlot();
            end
        end
        
        function removeResFov2VoltsCalControlPoint(obj, fov)
            % removeResFov2VoltsCalControlPoint  removes a calibration point
            %   from the curve used for correcting the resonant scanner
            %   amplitude at different zoom levels
            %
            %   obj.removeResFov2VoltsCalControlPoint()   removes the calibration point at the current zoom level
            %   obj.removeResFov2VoltsCalControlPoint(fov)   removes the calibration point at position fov
            
            if obj.componentExecuteFunction('removeResFov2VoltsCalControlPoint')
                % if interp range is non zero, two additional control points are create at the specified distance from the main point
                % to limit the range of effect on the interpolated curve
                if nargin < 2 || isempty(fov)
                    fov = obj.hCtl.nextResonantFov;
                end
                
                if ~obj.useNonlinearResonantFov2VoltsCurve
                    most.idioms.warn('''useNonlinearResonantFov2VoltsCurve'' is turned off. This curve is not actually being used for resonant mirror control. Set ''useNonlinearResonantFov2VoltsCurve'' to true to enable.')
                end
                
                fov = round(fov*100000)/100000;
                if obj.resFov2VoltsMap.isKey(fov)
                    obj.resFov2VoltsMap.remove(fov);
                    obj.updateFov2VoltageCurvePlot();
                end
            end
        end
        
        function adjustResVoltageCal(obj, adj)
            % adjustResVoltageCal adjusts a calibration point
            %   on the curve used for correcting the resonant scanner
            %   amplitude at different zoom levels 
            %
            %   obj.adjustResVoltageCal(adj)   moves the calibration point  by fraction adj up or down
            
            if obj.componentExecuteFunction('adjustResVoltageCal')
                % adjust the voltage of the resonant scanner up or down for the
                % current desired FOV by [adj]%
                assert(logical(obj.useNonlinearResonantFov2VoltsCurve), '''useNonlinearResonantFov2VoltsCurve'' is turned off. Aspect ratio adjustment is not possible. Set ''useNonlinearResonantFov2VoltsCurve'' to true to enable.');
                
                fov = obj.hCtl.nextResonantFov;
                v = obj.zzzResonantFov2Volts(fov);
                v = v * (1+adj);
                
                if v > obj.mdfData.resonantAngularRange * obj.mdfData.rScanVoltsPerOpticalDegree
                    v = obj.mdfData.resonantAngularRange * obj.mdfData.rScanVoltsPerOpticalDegree;
                    most.idioms.warn('Adjustment out of range. Coercing to %.3fV.', v);
                end
                
                if v < 0
                    v = 0;
                    most.idioms.warn('Adjustment out of range. Coercing to %.3fV.', v);
                end
                
                fov = round(fov*100000)/100000;
                obj.resFov2VoltsMap(fov) = v;
                obj.updateLiveValues();
                obj.updateFov2VoltageCurvePlot();
            end
        end
        
        function fov2VoltageCal = exportFov2VoltageCal(obj,filename)
            % exportFov2VoltageCal exports the calibration curve used for correcting the resonant scanner
            %   amplitude at different zoom levels
            %
            %   fov2VoltageCal = obj.exportFov2VoltageCal()  returns the calibration info
            %   obj.exportFov2VoltageCal()  opens a file dialog, then exports the calibration info to the selected path
            %   obj.exportFov2VoltageCal(filename)  exports the calibration info to the path specified in 'filename'
            
            if nargin < 2
                filename = '';
            end
            
            if nargout == 0 && isempty(filename)
                [name,path] = uigetfile('.mat','Choose file to save resonant voltage cal','fov2VoltageCal.mat');
                if name==0;return;end
                filename = fullfile(path,file);
            end
            
            if ~obj.useNonlinearResonantFov2VoltsCurve
                most.idioms.warn('''useNonlinearResonantFov2VoltsCurve'' is turned off. This curve is not actually being used for resonant mirror control. Set ''useNonlinearResonantFov2VoltsCurve'' to true to enable.')
            end
            
            fov2VoltageCal.angularRange = obj.mdfData.resonantAngularRange;
            fov2VoltageCal.voltsPerOpticalDegree = obj.mdfData.rScanVoltsPerOpticalDegree;
            fov2VoltageCal.fov = cell2mat(obj.resFov2VoltsMap.keys);
            fov2VoltageCal.angle = fov2VoltageCal.fov * obj.mdfData.resonantAngularRange;
            fov2VoltageCal.volts = cell2mat(obj.resFov2VoltsMap.values);
            
            if ~isempty(filename)
                save(filename,'fov2VoltageCal','-mat');
            end
        end
        
        function importFov2VoltageCal(obj,calOrFile)
            % importFov2VoltageCal imports the calibration curve used for correcting the resonant scanner
            %   amplitude at different zoom levels from a file
            %
            %   obj.importFov2VoltageCal(calOrFile) imports the calibration info either from a structure or the filepath specified in 'calOrFile'
            
            if nargin < 2 || isempty(calOrFile)
                [filename,pathname] = uigetfile('.mat','Choose file to load resonant voltage cal','fov2VoltageCal.mat');
                if filename==0;return;end
                calOrFile = fullfile(pathname,filename);
            end
            
            if ischar(calOrFile)
                fov2VoltageCal = load(filename,'-mat','fov2VoltageCal');
            elseif isstruct(calOrFile) && all(isfield(calOrFile, {'angularRange','voltsPerOpticalDegree','fov','volts'}))
                fov2VoltageCal = calOrFile;
            else
                error('Unkown input format.');
            end
            
            if ~obj.useNonlinearResonantFov2VoltsCurve
                most.idioms.warn('''useNonlinearResonantFov2VoltsCurve'' is turned off. This curve is not actually being used for resonant mirror control. Set ''useNonlinearResonantFov2VoltsCurve'' to true to enable.')
            end
            
            assignin('base','fov2VoltageCalBak',obj.exportFov2VoltageCal);
            
            % scale if zoom level 1 is at a different voltage
            fov2VoltageCal.fov = fov2VoltageCal.fov * (fov2VoltageCal.angularRange * fov2VoltageCal.voltsPerOpticalDegree)/(obj.mdfData.resonantAngularRange * obj.mdfData.rScanVoltsPerOpticalDegree);
            
            inds = fov2VoltageCal.fov(fov2VoltageCal.fov > 1);
            fov2VoltageCal.fov(inds) = [];
            fov2VoltageCal.volts(inds) = [];
            
            obj.resFov2VoltsMap = containers.Map(fov2VoltageCal.fov,fov2VoltageCal.volts);
            obj.updateFov2VoltageCurvePlot();
        end
        
        function clearResFov2VoltsCal(obj)
            % clearResFov2VoltsCal clears the calibration curve used for correcting the resonant scanner
            %   amplitude at different zoom levels
            %
            %   obj.clearResFov2VoltsCal()
            
            if obj.componentExecuteFunction('clearResFov2VoltsCal')
                obj.resFov2VoltsMap = containers.Map([1 0],[obj.mdfData.resonantAngularRange * obj.mdfData.rScanVoltsPerOpticalDegree 0]);
                obj.updateFov2VoltageCurvePlot();
                
                if ~obj.useNonlinearResonantFov2VoltsCurve
                    most.idioms.warn('''useNonlinearResonantFov2VoltsCurve'' is turned off. This curve is not actually being used for resonant mirror control. Set ''useNonlinearResonantFov2VoltsCurve'' to true to enable.')
                end
            end
        end
        
        function clearZoomToLinePhaseCal(obj)
            % clearZoomToLinePhaseCal clears the look up table that stores
            %    the line phase for different zoom factors
            %
            %   obj.clearZoomToLinePhaseCal()
            
            obj.linePhaseMap = containers.Map('KeyType', 'double', 'ValueType', 'double');
        end
        
        function clearZoomToScanFreqCal(obj)
            % clearZoomToScanFreqCal clears the look up table that stores
            %    the resonant scanner frequency for different zoom factors
            %
            %   obj.clearZoomToLinePhaseCal()
            
            obj.scanFreqMap = containers.Map('KeyType', 'double', 'ValueType', 'double');
        end
    end
    
    %% FRIEND METHODS
    methods (Hidden)
        function periodClockInOverride(obj,val)
            obj.hTrig.overrideTriggers(end+1) = struct('trig','periodClockIn','val',val);
            obj.hTrig.periodClockIn = val;
        end
        
        function updateFov2VoltageCurvePlot(obj)
            if most.idioms.isValidObj(obj.hCalFig) && strcmp(get(obj.hCalFig, 'Visible'), 'on')
                obj.plotFov2VoltageCurve();
            end
        end
    end
    
    %% INTERNAL METHODS
    
    methods (Hidden)
        function reinitRoutes(obj)
            if obj.mdlInitialized
                obj.hTrig.reinitRoutes();
            end
        end
        
        function deinitRoutes(obj)
            if obj.mdlInitialized
                refClkTerm = obj.hTrig.referenceClockOut;
                obj.hTrig.deinitRoutes();
                obj.hTrig.referenceClockOut = refClkTerm;
            end
        end
        
        function frameAcquiredFcn(obj,src,evnt) %#ok<INUSD>
            if obj.active
                if obj.enableBenchmark
                    t = tic();
                end
                
                obj.stripeAcquiredCallback(obj,[]);
                
                if obj.enableBenchmark
                    T = toc(t);
                    obj.lastFrameAcqFcnTime = T;
                    obj.totalFrameAcqFcnTime = obj.totalFrameAcqFcnTime + T;
                    
                    benchmarkData = obj.hAcq.benchmarkData;
                    framesProcessed = obj.hAcq.framesProcessed;
                    
                    fcut = benchmarkData.frameCopierProcessTime/10e3;
                    fcutpf = fcut/benchmarkData.totalAcquiredFrames;
                    fccpucpf = benchmarkData.frameCopierCpuCycles/benchmarkData.totalAcquiredFrames;
                    
                    flut = benchmarkData.frameLoggerProcessTime/10e3;
                    flutpf = flut/benchmarkData.totalAcquiredFrames;
                    flcpucpf = benchmarkData.frameLoggerCpuCycles/benchmarkData.totalAcquiredFrames;
                    
                    faft = obj.totalFrameAcqFcnTime*1000/framesProcessed;
                    drops = benchmarkData.totalAcquiredFrames - framesProcessed;
                    pctDrop = drops * 100 / benchmarkData.totalAcquiredFrames;
                    
                    td = tic;
                    drawnow('nocallbacks');
                    td = toc(td);
                    
                    obj.totalDispUpdates = obj.totalDispUpdates + 1;
                    obj.totalDispUpdateTime = obj.totalDispUpdateTime + td;
                    
                    aveDispTime = obj.totalDispUpdateTime*1000/obj.totalDispUpdates;
                    nskipped = benchmarkData.totalAcquiredFrames-obj.totalDispUpdates;
                    pctSkipped = nskipped * 100 / benchmarkData.totalAcquiredFrames;
                    
                    fps = obj.totalDispUpdates/etime(clock,obj.hSI.acqStartTime);
                    
                    fprintf('Frm copier: %.3fms/fr, %.3f cpu clks/frm, %.3f cpu ms/frm.   Frm logger: %.3fms/fr, %.3f cpu clks/frm, %.3f cpu ms/frm.   MATLAB: %.3fms/fr, %d (%.2f%%) dropped.   Display Update: %.1fms/fr, %d (%.2f%%) skipped, %.2ffps\n',...
                        fcutpf,fccpucpf,fccpucpf*1000/obj.cpuFreq,flutpf,flcpucpf,flcpucpf*1000/obj.cpuFreq,faft,drops,pctDrop,aveDispTime,nskipped,pctSkipped,fps);
                end
            end
        end
        
        function val = zzzEstimateLinePhase(obj,resonantOutputVolts)
            %Restrict resolution of map
            resonantOutputVolts = round(resonantOutputVolts*1000)/1000;
            
            if isempty(resonantOutputVolts) || isempty(keys(obj.linePhaseMap))
                %If there are no keys in the phase map or no voltage param set, default to zero.
                val = 0;
            else
                linePhaseMapArray = cell2mat(keys(obj.linePhaseMap));
                
                if ismember(resonantOutputVolts, linePhaseMapArray)
                    %If the resonant voltage is a key in the linePhaseMap, simply return its value.
                    val = obj.linePhaseMap(resonantOutputVolts);
                else
                    %If the resonant voltage is not a key in the linePhaseMap, then
                    %interpolate (or extrapolate) value from its nearest neighbors.
                    %Find the first key below this resonant voltage level.
                    lowKey = linePhaseMapArray(find(resonantOutputVolts>linePhaseMapArray,1,'last'));
                    %Find the first key above this resonant voltage level.
                    highKey = linePhaseMapArray(find(resonantOutputVolts<linePhaseMapArray,1,'first'));
                    if isempty(lowKey)
                        %If there is no key with a lower resonant voltage than
                        %the current one, return the val corresponding to the
                        %next lower known resonant voltage.
                        val = obj.linePhaseMap(highKey);
                    elseif isempty(highKey)
                        %If there is no key with a higher resonant voltage than
                        %the current one, return the val corresponding to the
                        %next higher known resonant voltage.
                        val = obj.linePhaseMap(lowKey);
                    else
                        %The usual case: There is a defined phase for resonant
                        %voltages greater than and less than he current one.
                        switch obj.linePhaseMode
                            % High and low are swapped because zoom is inverse to voltage
                            case 'Next Lower'
                                val = obj.linePhaseMap(highKey);
                            case 'Next Higher'
                                val = obj.linePhaseMap(lowKey);
                            case 'Nearest Neighbor'
                                if (highKey - resonantOutputVolts) > (resonantOutputVolts - lowKey)
                                    val = obj.linePhaseMap(lowKey);
                                else
                                    val = obj.linePhaseMap(highKey);
                                end
                            case 'Interpolate'
                                uniqueKeyVals = unique(linspace(lowKey,highKey));
                                
                                val = interp1(uniqueKeyVals, ...
                                    linspace(obj.linePhaseMap(lowKey), ...
                                    obj.linePhaseMap(highKey),numel(uniqueKeyVals)),resonantOutputVolts);
                        end
                    end
                end
            end
        end
        
        function val = zzzEstimateScanFreq(obj,resonantOutputVolts)
            %Restrict resolution of map
            resonantOutputVolts = round(resonantOutputVolts*1000)/1000;
            
            if isempty(resonantOutputVolts) || resonantOutputVolts == 0
                val = obj.mdfData.nominalResScanFreq;
            elseif isempty(keys(obj.scanFreqMap))
                val = obj.measureScannerFrequency();
            else
                scanFreqMapArray = cell2mat(keys(obj.scanFreqMap));
                
                if ismember(resonantOutputVolts, scanFreqMapArray)
                    %If the resonant voltage is a key in the scanFreqMap, simply return its value.
                    val = obj.scanFreqMap(resonantOutputVolts);
                else
                    val = obj.measureScannerFrequency();
                end
            end
            
            if isnan(val)
                val = obj.mdfData.nominalResScanFreq;
            end
        end
        
        function val = zzzResonantFov2Volts(obj,fov)
            %Restrict resolution of map
            fov = round(fov*100000)/100000;
            assert((fov <= 1) && (fov >= 0), 'FOV out of range.');
            
            if obj.useNonlinearResonantFov2VoltsCurve
                if isempty(keys(obj.resFov2VoltsMap))
                    %If there are no keys in the phase map, return default
                    val = obj.mdfData.resonantAngularRange * obj.mdfData.rScanVoltsPerOpticalDegree * fov;
                else
                    resFov2VoltsMapArray = cell2mat(keys(obj.resFov2VoltsMap));
                    
                    if ismember(fov, resFov2VoltsMapArray)
                        %If the fov is a key in the resFov2VoltsMap, simply return its value.
                        val = obj.resFov2VoltsMap(fov);
                    else
                        %If the resonant fov is not a key in the resFov2VoltsMap, then
                        %interpolate (or extrapolate) value from its nearest neighbors.
                        
                        %Find the first key below this resonant voltage level.
                        lowKey = resFov2VoltsMapArray(find(fov>resFov2VoltsMapArray,1,'last'));
                        if isempty(lowKey)
                            lowKey = 0;
                            lowVal = 0;
                        else
                            lowVal = obj.resFov2VoltsMap(lowKey);
                        end
                        
                        %Find the first key above this resonant voltage level.
                        highKey = resFov2VoltsMapArray(find(fov<resFov2VoltsMapArray,1,'first'));
                        if isempty(highKey)
                            highKey = 1;
                            highVal = obj.mdfData.resonantAngularRange * obj.mdfData.rScanVoltsPerOpticalDegree;
                        else
                            highVal = obj.resFov2VoltsMap(highKey);
                        end
                        
                        val = interp1([lowKey highKey], [lowVal highVal], fov);
                    end
                end
            else
                val = obj.mdfData.resonantAngularRange * obj.mdfData.rScanVoltsPerOpticalDegree * fov;
            end
        end
        
        function pixPerLine = getPixPerLine(obj)
            if obj.uniformSampling
                pixPerLine = floor(0.5 * obj.sampleRate * obj.fillFractionTemporal / (obj.scannerFrequency * obj.pixelBinFactor));
            else
                pixPerLine = max(arrayfun(@(roi)maxPixelsPerLine(roi),obj.currentRoiGroup.rois));
            end
            
            function pixels = maxPixelsPerLine(roi)
                % Returns the maximum number of pixels per line in the RoiGroup.
                if ~isempty(roi.scanfields)
                    pixels = max(arrayfun(@(scanfield) scanfield.pixelResolution(1),roi.scanfields));
                else
                    pixels = 0;
                end
            end
        end
        
        function loadClassData(obj)
            ks = obj.getClassDataVar('linePhaseMap_ks',obj.classDataFileName);
            vs = obj.getClassDataVar('linePhaseMap_vs',obj.classDataFileName);
            if ~isa(ks,'double') || ~isa(vs,'double') || numel(ks) ~= numel(vs)
                most.idioms.warn('Line phase map from Class Data File contained unexpected data. Replacing with empty map.');
                obj.linePhaseMap = containers.Map('KeyType', 'double', 'ValueType', 'double');
            elseif isempty(ks)
                obj.linePhaseMap = containers.Map('KeyType', 'double', 'ValueType', 'double');
            else
                obj.linePhaseMap = containers.Map(ks,vs);
            end
            
            scanFreqNominal_ = obj.getClassDataVar('scanFreqNominal',obj.classDataFileName);
            if isempty(scanFreqNominal_) || scanFreqNominal_ == obj.mdfData.nominalResScanFreq
                ks = obj.getClassDataVar('scanFreqMap_ks',obj.classDataFileName);
                vs = obj.getClassDataVar('scanFreqMap_vs',obj.classDataFileName);
            else
                most.idioms.warn('Detected changed nominal resonant frequency. Resetting resonant frequency map.');
                ks = double([]);
                vs = double([]);
            end
            
            if ~isa(ks,'double') || ~isa(vs,'double') || numel(ks) ~= numel(vs)
                most.idioms.warn('Scan freq map from Class Data File contained unexpected data. Replacing with empty map.');
                obj.scanFreqMap = containers.Map('KeyType', 'double', 'ValueType', 'double');
            elseif isempty(ks)
                obj.scanFreqMap = containers.Map('KeyType', 'double', 'ValueType', 'double');
            else
                obj.scanFreqMap = containers.Map(ks,vs);
            end
            
            ks = obj.getClassDataVar('resFov2VoltsMap_ks',obj.classDataFileName);
            vs = obj.getClassDataVar('resFov2VoltsMap_vs',obj.classDataFileName);
            if ~isa(ks,'double') || ~isa(vs,'double') || numel(ks) ~= numel(vs)
                most.idioms.warn('Resonant voltage map from Class Data File contained unexpected data. Replacing with default map.');
                obj.resFov2VoltsMap = containers.Map([1 0],[obj.mdfData.resonantAngularRange * obj.mdfData.rScanVoltsPerOpticalDegree 0]);
            elseif isempty(ks)
                obj.resFov2VoltsMap = containers.Map([1 0],[obj.mdfData.resonantAngularRange * obj.mdfData.rScanVoltsPerOpticalDegree 0]);
            else
                nmax = obj.getClassDataVar('resFov2VoltsMap_nom_max',obj.classDataFileName);
                if obj.useNonlinearResonantFov2VoltsCurve && ~isempty(nmax) && abs(nmax - obj.mdfData.resonantAngularRange * obj.mdfData.rScanVoltsPerOpticalDegree) > 0.001
                    most.idioms.warn('The resonant scanner voltage settings have changed. The resonant calibration map must be reset for the change to take effect.');
                end
                obj.resFov2VoltsMap = containers.Map(ks,vs);
            end
            
            obj.resonantLimitedFovMode_ = obj.getClassDataVar('resonantLimitedFovMode',obj.classDataFileName);
            obj.useNonlinearResonantFov2VoltsCurve_ = obj.getClassDataVar('useNonlinearResonantFov2VoltsCurve',obj.classDataFileName);
            obj.keepResonantScannerOn = obj.getClassDataVar('keepResonantScannerOn',obj.classDataFileName);
            obj.linePhaseMode = obj.getClassDataVar('linePhaseMode',obj.classDataFileName);
            
            galvoCalibration_ = obj.getClassDataVar('galvoCalibration',obj.classDataFileName);
            if isstruct(galvoCalibration_) && isfield(galvoCalibration_,'xGalvo') && ~isempty(obj.xGalvo)
                obj.xGalvo.calibrationData = galvoCalibration_.xGalvo;
            end
            
            if isstruct(galvoCalibration_) && isfield(galvoCalibration_,'yGalvo') && ~isempty(obj.yGalvo)
                obj.yGalvo.calibrationData = galvoCalibration_.yGalvo;
            end
        end
        
        
        function saveMaps(obj,savePhaseMap,saveFreqMap,saveVoltageMap)
            
            if ~obj.numInstances
                % init did not complete successfuly
                return;
            end
            
            if nargin < 2
                savePhaseMap = true;
            end
            
            if nargin < 3
                saveFreqMap = true;
            end
            
            if nargin < 4
                saveVoltageMap = true;
            end
            
            if savePhaseMap && most.idioms.isValidObj(obj.linePhaseMap)
                obj.setClassDataVar('linePhaseMap_ks',cell2mat(obj.linePhaseMap.keys),obj.classDataFileName);
                obj.setClassDataVar('linePhaseMap_vs',cell2mat(obj.linePhaseMap.values),obj.classDataFileName);
            end
            
            if saveFreqMap
                obj.setClassDataVar('scanFreqNominal',obj.mdfData.nominalResScanFreq,obj.classDataFileName);
                obj.setClassDataVar('scanFreqMap_ks',cell2mat(obj.scanFreqMap.keys),obj.classDataFileName);
                obj.setClassDataVar('scanFreqMap_vs',cell2mat(obj.scanFreqMap.values),obj.classDataFileName);
            end
            
            if saveVoltageMap
                obj.setClassDataVar('resFov2VoltsMap_ks',cell2mat(obj.resFov2VoltsMap.keys),obj.classDataFileName);
                obj.setClassDataVar('resFov2VoltsMap_vs',cell2mat(obj.resFov2VoltsMap.values),obj.classDataFileName);
                nmax = obj.mdfData.resonantAngularRange * obj.mdfData.rScanVoltsPerOpticalDegree;
                obj.setClassDataVar('resFov2VoltsMap_nom_max',nmax,obj.classDataFileName);
            end
        end
    end
    
    methods (Hidden)%, Access = private)
        function configureFrameResolution(obj)
            zs=obj.hSI.hStackManager.zs; % generate planes to scan based on motor position etc
            
            roiGroup = obj.currentRoiGroup;
            scannerset = obj.scannerset;
            [scanLines,flybackLines] = arrayfun(@linesPerSlice,zs);
            scanLines = max(scanLines);
            flybackLines = max(flybackLines);
            
            obj.hAcq.pixelsPerLine = obj.getPixPerLine();
            obj.hAcq.linesPerFrame = scanLines;
            obj.hAcq.flybackLinesPerFrame = flybackLines;
            
            obj.hAcq.computeMask();
            obj.hAcq.flagResizeAcquisition = true;
            
            % local functions to operate on roiGroup
            function [scanLines,flybackLines] = linesPerSlice(z)
                lineMask = acqActiveLineMask(z);
                scanLines = numel(lineMask);
                [~,flybackTime] = roiGroup.transitTimes(scannerset,z);
                flybackLines = round(flybackTime * (1/scannerset.scanners{1}.scannerPeriod) * 2^scannerset.scanners{1}.bidirectionalScan);
            end
            
            function lineMask = acqActiveLineMask(z)
                scanFields = roiGroup.scanFieldsAtZ(z);
                if(~isempty(scanFields))
                    % get transitLines
                    scanFieldsWithTransit = [{NaN} scanFields]; %pre- and ap- pend "park" to the scan field sequence to transit % the FPGA clock does not tick for the frame flyback, so we do not include the global flyback here
                    transitPairs = scanimage.mroi.util.chain(scanFieldsWithTransit); %transit pairs
                    transitTimes = cellfun(@(pair) scannerset.transitTime(pair{1},pair{2}),transitPairs);
                    linePeriods  = cellfun(@(sf)scannerset.linePeriod(sf),scanFields);
                    transitLines = round(transitTimes' ./ linePeriods);
                    
                    % get scanFieldLines
                    scanFieldLines = cellfun(@(sf)sf.pixelResolution(2),scanFields);
                    
                    lineMask = [];
                    for i = 1:length(scanFields)
                        lineMask(end+1:end+transitLines(i)) = false;
                        lineMask(end+1:end+scanFieldLines(i)) = true;
                    end
                else
                    lineMask = [];
                end
            end
        end
        
        function zprvEnsureClassDataFileProps(obj)
            obj.ensureClassDataFile(struct('galvoCalibration',struct()),obj.classDataFileName);
            
            obj.ensureClassDataFile(struct('linePhaseMap_ks',double([])),obj.classDataFileName);
            obj.ensureClassDataFile(struct('linePhaseMap_vs',double([])),obj.classDataFileName);
            
            obj.ensureClassDataFile(struct('scanFreqNominal',double([])),obj.classDataFileName);
            obj.ensureClassDataFile(struct('scanFreqMap_ks',double([])),obj.classDataFileName);
            obj.ensureClassDataFile(struct('scanFreqMap_vs',double([])),obj.classDataFileName);
            
            obj.ensureClassDataFile(struct('resFov2VoltsMap_ks',double([])),obj.classDataFileName);
            obj.ensureClassDataFile(struct('resFov2VoltsMap_vs',double([])),obj.classDataFileName);
            nmax = obj.mdfData.resonantAngularRange * obj.mdfData.rScanVoltsPerOpticalDegree;
            obj.ensureClassDataFile(struct('resFov2VoltsMap_nom_max',nmax),obj.classDataFileName);
            
            obj.ensureClassDataFile(struct('resonantLimitedFovMode',true),obj.classDataFileName);
            obj.ensureClassDataFile(struct('useNonlinearResonantFov2VoltsCurve',false),obj.classDataFileName);
            obj.ensureClassDataFile(struct('keepResonantScannerOn',false),obj.classDataFileName);
            obj.ensureClassDataFile(struct('linePhaseMode','Nearest Neighbor'),obj.classDataFileName);
        end
    end
    
    %%% Abstract methods realizations (scanimage.interfaces.Scan2D)    
    methods (Hidden)
        function arm(obj)
            resAmplitude = obj.hCtl.nextResonantVoltage;
            
            if resAmplitude > 0.0001
                obj.hCtl.resonantScannerActivate(true, resAmplitude);
                
%                 if obj.hCtl.getRemainingResSettlingTime() < 0.00001
%                     newFreq = obj.hAcq.calibrateResonantScannerFreq();
%                 else
                    newFreq = obj.zzzEstimateScanFreq(resAmplitude);
%                 end
                
                % avoid pointless change
                if (abs(newFreq - obj.scannerFrequency) / obj.scannerFrequency) > 0.00001
                    obj.scannerFrequency = newFreq;
                end
            end
        end
        
        function data = acquireSamples(obj,numSamples)
            if obj.componentExecuteFunction('acquireSamples',numSamples)
                data = zeros(numSamples,obj.channelsAvailable,obj.channelsDataType); % preallocate data
                if ~obj.mdfData.photonCountingEnable
                    for i = 1:numSamples
                        data(i,:) = obj.hAcq.rawAdcOutput(1,1:obj.channelsAvailable);
                    end
                end
            end
        end
        
        function signalReadyReceiveData(obj)
            obj.hAcq.signalReadyReceiveData();
        end
                
        function [success,stripeData] = readStripeData(obj)
            % remove the componentExecute protection for performance
            %if obj.componentExecuteFunction('readStripeData')
                [success,stripeData] = obj.hAcq.readStripeData();
                if stripeData.endOfAcquisitionMode
                    obj.abort(); %self abort if acquisition is done
                end
            %end
        end
        
        function newPhase = calibrateLinePhase(obj)
            im = getImage();
            
            ff_s = obj.fillFractionSpatial;
            ff_t = obj.fillFractionTemporal;
            
            if ~obj.uniformSampling
                im = imToTimeDomain(im,ff_s,ff_t);
            end
            
            im_odd  = im(:,1:2:end);
            im_even = im(:,2:2:end);
            
            % first brute force search to find minimum
            offsets_rad = linspace(-1,1,31)*pi/8;
            ds = arrayfun(@(offset_rad)imDifference(im_odd,im_even,ff_s,ff_t,offset_rad),offsets_rad);
            [d,idx] = min(ds);
            offset_rad = offsets_rad(idx);

            % secondary brute force search to refine minimum
            offsets_rad = offset_rad+linspace(-1,1,51)*diff(offsets_rad(1:2));
            ds = arrayfun(@(offset_rad)imDifference(im_odd,im_even,ff_s,ff_t,offset_rad),offsets_rad);
            [d,idx] = min(ds);
            offset_rad = offsets_rad(idx);
            
            offsetLinePhase = offset_rad /(2*pi)/obj.scannerFrequency;
            obj.linePhase =  obj.linePhase - offsetLinePhase;
            
            newPhase = obj.linePhase;
            
            %%% Local Functions
            function [d,im] = imDifference(im_odd, im_even, ff_s, ff_t, offset_rad)                
                im_odd  = imToSpatialDomain(im_odd , ff_s, ff_t, offset_rad);
                im_even = imToSpatialDomain(im_even, ff_s, ff_t,-offset_rad);
                
                d = im_odd - im_even;
                d(isnan(d)) = []; % remove artifacts from interpolation
                d = sum(abs(d(:))) ./ numel(d); % least square difference, normalize by number of elements
                
                if nargout > 1
                    im = cat(3,im_odd,im_even);
                    im = permute(im,[1,3,2]);
                    im = reshape(im,size(im,1),[]);
                end
            end
            
            function im = imToTimeDomain(im,ff_s,ff_t)
                nPix = size(im,1);
                xx_lin = linspace(-ff_s,ff_s,nPix);
                xx_rad = linspace(-ff_t,ff_t,nPix)*pi/2;
                xx_linq = sin(xx_rad);
                
                im = interp1(xx_lin,im,xx_linq,'linear',NaN);
            end
            
            function im = imToSpatialDomain(im,ff_s,ff_t,offset_rad)
                nPix = size(im,1);
                xx_rad = linspace(-ff_t,ff_t,nPix)*pi/2+offset_rad;
                xx_lin = linspace(-ff_s,ff_s,nPix);
                xx_radq = asin(xx_lin);
                
                im = interp1(xx_rad,im,xx_radq,'linear',NaN);
            end
            
            function im = getImage()
                %get image from every roi
                roiDatas = obj.hSI.hDisplay.lastStripeData.roiData;
                for i = numel(roiDatas):-1:1
                    im = vertcat(roiDatas{i}.imageData{:});
                    
                    if ~roiDatas{i}.transposed
                        im = cellfun(@(imt){imt'},im);
                    end
                    
                    imData{i,1} = horzcat(im{:});
                end
                im = cell2mat(imData);
                
                nLines = size(im,2);
                if nLines > 1024
                    im(:,1025:end) = []; % this should be enough lines for processing
                elseif mod(nLines,2)
                    im(:,end) = []; % crop to even number of lines
                end
                
                im = single(im);
            end
        end
        
        function reloadMdf(obj,varargin)
            obj.reloadMdf@scanimage.interfaces.Component(varargin{:})
            obj.hTrig.laserTriggerIn = obj.mdfData.LaserTriggerPort;
        end
    end
    
    %%% Abstract methods realizations (scanimage.interfaces.Component)
    methods (Access = protected, Hidden)

        function componentStart(obj)
            assert(~obj.robotMode);
            obj.independentComponent = false;
            obj.totalFrameAcqFcnTime = 0;
            obj.totalDispUpdates = 0;
            obj.totalDispUpdateTime = 0;
            
            obj.configureFrameResolution();
            
            obj.hTrig.start();
            obj.hCtl.start();
            obj.hAcq.start();
            
            obj.flagZoomChanged = false;
            obj.linePhase_ = [];
        end
        
        function componentAbort(obj,soft)
            if nargin < 2 || isempty(soft)
                soft = false;
            end
            
            obj.hAcq.abort();
            obj.hCtl.stop(soft);
            obj.hTrig.stop();
            
            obj.saveMaps();
            
            obj.flagZoomChanged = false;
            obj.linePhase_ = [];
            obj.independentComponent = true;
        end
        
        
        function fillFracTemp = fillFracSpatToTemp(~,fillFracSpat)
            fillFracTemp = 2/pi * asin(fillFracSpat);
        end
        
        function fillFracSpat = fillFracTempToSpat(~,fillFracTemp)
            fillFracSpat = cos( (1-fillFracTemp) * pi/2 );
        end
    end          
    
    %% FRIEND EVENTS
    events (Hidden, ListenAccess = {?scanimage.interfaces.Class},NotifyAccess = public); % for some reason NotifyAccess = {?scanimage.components.scan2d.resscan.Control} does not work
        resonantScannerOutputVoltsUpdated;
    end
    
end

function s = zlclAppendDependsOnPropAttributes(s)
    s.useNonlinearResonantFov2VoltsCurve = struct('Classes','binaryflex');
end

function s = defaultMdfSection()
    s = [...
        makeEntry('nominalResScanFreq',7910,'[Hz] nominal frequency of the resonant scanner')...
        makeEntry('beamDaqID',[],'Numeric: ID of the beam DAQ to use with the resonant scan system')...
        makeEntry('shutterIDs',1,'Array of the shutter IDs that must be opened for resonant scan system to operate')...
        makeEntry()... % blank line
        makeEntry('digitalIODeviceName','PXI1Slot3','String: Device name of the DAQ board or FlexRIO FPGA that is used for digital inputs/outputs (triggers/clocks etc). If it is a DAQ device, it must be installed in the same PXI chassis as the FlexRIO Digitizer')...
        makeEntry()... % blank line
        makeEntry('fpgaModuleType','NI7961','String: Type of FlexRIO FPGA module in use. One of {''NI7961'' ''NI7975''}')...
        makeEntry('digitizerModuleType','NI5732','String: Type of digitizer adapter module in use. One of {''NI5732'' ''NI5734''}')...
        makeEntry('customSigCondOption','','String: Alternate signal conditioning option')...
        makeEntry('rioDeviceID','RIO0','FlexRIO Device ID as specified in MAX. If empty, defaults to ''RIO0''')...
        makeEntry('channelsInvert',false,'Logical: Specifies if the input signal is inverted (i.e., more negative for increased light signal)')...
        makeEntry()... % blank line
        makeEntry('externalSampleClock',false,'Logical: use external sample clock connected to the CLK IN terminal of the FlexRIO digitizer module')...
        makeEntry('externalSampleClockRate',[],'[Hz]: nominal frequency of the external sample clock connected to the CLK IN terminal (e.g. 80e6); actual rate is measured on FPGA')...
        makeEntry()... % blank line
        makeEntry('enableRefClkOutput',false,'Enables/disables the 10MHz reference clock output on PFI14 of the digitalIODevice')...
        makeEntry()... % blank line
        makeEntry('Galvo mirror settings')... % comment only
        makeEntry('galvoDeviceName','PXI1Slot3','String identifying the NI-DAQ board to be used to control the galvo(s). The name of the DAQ-Device can be seen in NI MAX. e.g. ''Dev1'' or ''PXI1Slot3''. This DAQ board needs to be installed in the same PXI chassis as the FPGA board specified in section')...
        makeEntry('galvoAOChanIDX',[],'The numeric ID of the Analog Output channel to be used to control the X Galvo. Can be empty for standard Resonant Galvo scanners.')...
        makeEntry('galvoAOChanIDY',1,'The numeric ID of the Analog Output channel to be used to control the Y Galvo.')...
        makeEntry()... % blank line
        makeEntry('galvoAIChanIDX',[],'The numeric ID of the Analog Input channel for the X Galvo feedback signal.')...
        makeEntry('galvoAIChanIDY',[],'The numeric ID of the Analog Input channel for the Y Galvo feedback signal.')...
        makeEntry()... % blank line
        makeEntry('xGalvoAngularRange',15,'max range in optical degrees (pk-pk) for x galvo if present')...
        makeEntry('yGalvoAngularRange',15,'max range in optical degrees (pk-pk) for y galvo')...
        makeEntry()... % blank line
        makeEntry('galvoVoltsPerOpticalDegreeX',1.0,'galvo conversion factor from optical degrees to volts (negative values invert scan direction)')...
        makeEntry('galvoVoltsPerOpticalDegreeY',1.0,'galvo conversion factor from optical degrees to volts (negative values invert scan direction)')...
        makeEntry()... % blank line
        makeEntry('galvoParkDegreesX',-8,'Numeric [deg]: Optical degrees from center position for X galvo to park at when scanning is inactive')...
        makeEntry('galvoParkDegreesY',-8,'Numeric [deg]: Optical degrees from center position for Y galvo to park at when scanning is inactive')...
        makeEntry()... % blank line
        makeEntry('Resonant mirror settings')... % comment only
        makeEntry('resonantZoomDeviceName','','String identifying the NI-DAQ board to host the resonant zoom analog output. Leave empty to use same board as specified in ''galvoDeviceName''')...
        makeEntry('resonantZoomAOChanID',0,'resonantZoomAOChanID: The numeric ID of the Analog Output channel to be used to control the Resonant Scanner Zoom level.')...
        makeEntry('resonantEnableTerminal',[],'(optional) The PFI line on the resonantZoomDevice that enables/disables the resonant scanner. Example: 13   Not required for Thorlabs BSCope')...
        makeEntry()... % blank line
        makeEntry('resonantAngularRange',26,'max range in optical degrees (pk-pk) for resonant')...
        makeEntry('rScanVoltsPerOpticalDegree',0.19230769,'resonant scanner conversion factor from optical degrees to volts')...
        makeEntry()... % blank line
        makeEntry('resonantScannerSettleTime',0.5,'[seconds] time to wait for the resonant scanner to reach its desired frequency after an update of the zoomFactor')...
        makeEntry()... % blank line
        makeEntry('Advanced/Optional')... % comment only
        makeEntry('PeriodClockDebounceTime', 100e-9,'[s] time the period clock has to be stable before a change is registered')...
        makeEntry('TriggerDebounceTime', 500e-9,'[s] time acquisition, stop and next trigger to be stable before a change is registered')...
        makeEntry('reverseLineRead', false,'flips the image in the resonant scan axis')...
        makeEntry()... % blank line
        makeEntry('Aux Trigger Recording, Photon Counting, and I2C are mutually exclusive')...
        makeEntry()... % blank line
        makeEntry('Aux Trigger Recording')... % comment only
        makeEntry('auxTriggersEnable', true)...
        makeEntry('auxTriggersTimeDebounce', 1e-6,'[s] time an aux trigger needs to be high for registering an edge (seconds)')...
        makeEntry('auxTriggerLinesInvert', false(4,1), '[logical] 1x4 vector specifying polarity of aux trigger inputs')...
        makeEntry()... % blank line
        makeEntry('Photon Counting')... % comment only
        makeEntry('photonCountingEnable', false)...
        makeEntry('photonCountingDisableAveraging', [],'disable averaging of samples into pixels; instead accumulate samples')...
        makeEntry('photonCountingScaleByPowerOfTwo', 8,'for use with photonCountingDisableAveraging == false; scale count by 2^n before averaging to avoid loss of precision by integer division')...
        makeEntry('photonCountingDebounce', 25e-9,'[s] time the TTL input needs to be stable high before a pulse is registered')...
        makeEntry()... % blank line
        makeEntry('I2C')... % comment only
        makeEntry('I2CEnable', false)...
        makeEntry('I2CAddress', uint8(0),'[byte] I2C address of the FPGA')...
        makeEntry('I2CDebounce', 500e-9,'[s] time the I2C signal has to be stable high before a change is registered')...
        makeEntry('I2CStoreAsChar', false,'if false, the I2C packet bytes are stored as a uint8 array. if true, the I2C packet bytes are stored as a string. Note: a Null byte in the packet terminates the string')...
        makeEntry('I2CDisableAckOutput', false, 'the FPGA confirms each packet with an ACK bit by actively pulling down the SDA line. I2C_DISABLE_ACK_OUTPUT = true disables the FPGA output')...
        makeEntry()... % blank line
        makeEntry('Laser Trigger')... % comment only
        makeEntry('LaserTriggerPort', '','Port on FlexRIO AM digital breakout (DIO0.[0:3]) where laser trigger is connected.')...
        makeEntry('LaserTriggerFilterTicks', 0)...
        makeEntry('LaserTriggerSampleMaskEnable', false)...
        makeEntry('LaserTriggerSampleWindow', [0 1])...
        ];
    
    function se = makeEntry(name,value,comment,liveUpdate)
        if nargin == 0
            name = '';
            value = [];
            comment = '';
        elseif nargin == 1
            comment = name;
            name = '';
            value = [];
        elseif nargin == 2
            comment = '';
        end
        
        if nargin < 4
            liveUpdate = false;
        end
        
        se = struct('name',name,'value',value,'comment',comment,'liveUpdate',liveUpdate);
    end
end


%--------------------------------------------------------------------------%
% ResScan.m                                                                %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
