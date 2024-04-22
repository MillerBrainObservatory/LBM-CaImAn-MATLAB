classdef SlmScan < scanimage.components.Scan2D & most.HasMachineDataFile
    % SlmScan - subclass of Scan2D for SLM scanning
    %   - controls a SLM for scanning XYZ points
    %   - handles data acquisition to collect data from PMT
    %   - format PMT data into images
    %   - handles acquistion timing and acquisition state
    %   - export timing signal
    
    
    %% USER PROPS
    properties (SetObservable)
        wavelength = 635e-9;            % [double] excitation wavelength in nm
        galvoReferenceAngleXY = [0,0];  % [nx2 double] XY reference angle for galvo. this is the zero point for the SLM
    end
    
    properties (SetObservable, Transient)
        sampleRate = Inf;               % [Hz] sample rate of the digitizer; cannot be set
        channelOffsets;                 % Array of integer values; channelOffsets defines the dark count to be subtracted from each channel if channelsSubtractOffsets is true
        zeroOrderBlockRadius = 0;       % [double] radius of non-addressable area at center of FOV
        lut = [];                       % [nx2 double] SLM phase to pixel value look up table for current wavelength
        wavefrontCorrectionNominal = [];       % [mxn double] SLM wavefront correction for current wavelength
        wavefrontCorrectionNominalWavelength = []; % [numeric] wavelength in meter, at which nominal wavefront correction was measured
        testPatternPixelToRefTransform = eye(3); % [3x3] transform
        zAlignment = [];
    end
    
    properties (SetObservable, Hidden)
        testPattern;                    % [mxn] array of test pattern to be written to SLM (not transposed)
        recordScannerFeedback = false;  % not used in SlmScan, but required anyway
    end
    
    properties (SetObservable, Transient, Dependent)
        focalLength = 500;              % [double] equivalent focal length of imaging system in m
        staticOffset;                   % [1x3 double] staticOffset in m
        parkPosition;                   % [1x3 double] Park Position in m
    end
    
    properties (SetObservable, Hidden)
        calibratedWavelengths;          % [1xn] array of wavelengths for which luts are available
    end
    
    properties (Constant, Hidden)
        MAX_NUM_CHANNELS = 4;
        logFilePerChannel = false;
    end
    
    properties (Hidden, Access = private)
        cancelSaveClassData = false;
    end
    
    properties (SetAccess = private)
        hZernikeGenerator;
    end
    
    properties (SetObservable,Hidden,SetAccess = private)
        alignmentPoints = cell(0,2);
        alignmentReference = [];
        hLutCalibrationTask;
    end
    
    %% FRIEND PROPS
    properties (Hidden)
        hSlm;
        hAcq;
        hLog;
        hLinScan;
    end
    
    properties (Hidden, SetAccess = protected)
        defaultRoiSize;
        angularRange;
        supportsRoiRotation = true;
        hardwareTimedAcquisition = false;
        lutMap;
    end
    
    %% Private Props
    properties (Access = private)
        channelsDataType_;
    end
    
    %%% Abstract prop realizations (most.Model)
    properties (Hidden,SetObservable)
       pixelBinFactor = 1;
       keepResonantScannerOn = false;
    end
    
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = zlclAppendDependsOnPropAttributes(scanimage.components.Scan2D.scan2DPropAttributes());
        mdlHeaderExcludeProps = {'lut','zAlignment','wavefrontCorrectionNominal'};
    end    
        
    %%% Abstract property realizations (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'SlmScan';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp; %#ok<MCCPI>
        mdfPropPrefix; %#ok<MCCPI>
        
        mdfDefault = defaultMdfSection();
    end
    
    %%% Abstract prop realization (scanimage.interfaces.Component)
    properties (SetAccess = protected, Hidden)
        numInstances = 0;
        linePhaseStep = 1;
    end        
    
    %%% Abstract property realizations (scanimage.subystems.Scan2D)
    properties (Constant, Hidden)
        scannerType = 'SLM';                % short description of the scanner type
        builtinFastZ = true;
    end
    
    properties (Constant, Hidden)
        linePhaseUnits = 'pixels';
    end
    
    %%% Constants
    properties (Constant, Hidden)        
        COMPONENT_NAME = 'SlmScan';               % [char array] short name describing functionality of component e.g. 'Beams' or 'FastZ'
        PROP_TRUE_LIVE_UPDATE = {'linePhase'}     % Cell array of strings specifying properties that can be set while the component is active
        PROP_FOCUS_TRUE_LIVE_UPDATE = {};         % Cell array of strings specifying properties that can be set while focusing
        DENY_PROP_LIVE_UPDATE = {'framesPerAcq','trigAcqTypeExternal',...  % Cell array of strings specifying properties for which a live update is denied (during acqState = Focus)
            'trigAcqTypeExternal','trigNextStopEnable','trigAcqInTerm',...
            'trigNextInTerm','trigStopInTerm','trigAcqEdge','trigNextEdge',...
            'trigStopEdge','stripeAcquiredCallback','logAverageFactor','logFilePath',...
            'logFileStem','logFramesPerFile','logFramesPerFileLock','logNumSlices'};
        
        FUNC_TRUE_LIVE_EXECUTION = {'updateLiveValues','readStripeData'}; % Cell array of strings specifying functions that can be executed while the component is active
        FUNC_FOCUS_TRUE_LIVE_EXECUTION = {};           % Cell array of strings specifying functions that can be executed while focusing
        DENY_FUNC_LIVE_EXECUTION = {'pointScanner','parkScanner','centerScanner'};  % Cell array of strings specifying functions for which a live execution is denied (during acqState = Focus)
    end    
    
    %% Lifecycle
    methods
        function obj = SlmScan(hSI, simulated, name, legacymode)
            % SlmScan constructor for scanner object
            %  obj = SlmScan(hSI)                 
            %  obj = SlmScan(hSI, simulated)
            %  obj = SlmScan(hSI, simulated, name)
            %  obj = SlmScan(hSI, simulated, name, legacymode)
            
            if nargin < 2 || isempty(simulated)
                simulated = false;
            end
            
            if nargin < 3 || isempty(name)
                name = 'Slm';
            end
            
            if nargin > 3 && ~isempty(legacymode) && legacymode
                custMdfHeading = 'SlmScan';
            else
                legacymode = false;
                custMdfHeading = ['SlmScan (' name ')'];
            end
            
            obj = obj@scanimage.components.Scan2D(hSI,simulated,name,legacymode);
            obj = obj@most.HasMachineDataFile(true, custMdfHeading);
            
            if isempty(obj.mdfData.channelIDs)
                obj.mdfData.channelIDs = 0:3;
            end
            
            %Construct sub-components
            assert(ischar(obj.mdfData.slmType) && ~isempty(obj.mdfData.slmType),'Invalid value for MDF entry slmType: ''%s''',obj.mdfData.slmType);
            slmInfo = scanimage.components.scan2d.slmscan.SlmRegistry.getSlmInfo(obj.mdfData.slmType);
            
            assert(~isempty(slmInfo),'SLM Type ''%s'' not found in SLM Registry',obj.mdfData.slmType);
            obj.hSlm = eval([slmInfo.Class '()']);
            
            if ~isempty(obj.mdfData.deviceNameAux) && ~isempty(obj.mdfData.slmUpdateTriggerOutputTerm)
                obj.hSlm.slmUpdateTriggerOutputTerm = ['/' obj.mdfData.deviceNameAux '/' obj.mdfData.slmUpdateTriggerOutputTerm];
            end
            
            if ~isempty(obj.mdfData.deviceNameAux) && ~isempty(obj.mdfData.slmUpdateTriggerInputTerm)
                obj.hSlm.slmUpdateTriggerInputTerm = ['/' obj.mdfData.deviceNameAux '/' obj.mdfData.slmUpdateTriggerInputTerm];
            end
            
            obj.focalLength = obj.mdfData.focalLength / 1e3; % conversion from mm to m
            obj.zeroOrderBlockRadius = obj.mdfData.zeroOrderBlockRadius / 1e3;
            
            obj.hAcq = scanimage.components.scan2d.slmscan.Acquisition(obj);
            obj.setupRoutes();
            
            obj.hLog = scanimage.components.scan2d.linscan.Logging(obj);
            
            obj.ziniExpandChannelsInvert();
            
            obj.numInstances = 1; % This has to happen _before_ any properties are set
            
            %Initialize Scan2D props (not initialized by superclass)
            obj.channelsInputRanges = repmat({[-1,1]},1,obj.channelsAvailable);
            obj.channelOffsets = zeros(1, obj.channelsAvailable);
            obj.channelsSubtractOffsets = true(1, obj.channelsAvailable);
            
            obj.lutMap = containers.Map('KeyType','double','ValueType','any');
            
            obj.zAlignment = []; %initialize zAlignment
                        
            %Verify mdf settings
            assert(isempty(obj.mdfData.beamDaqID) || (obj.mdfData.beamDaqID <= obj.hSI.hBeams.numInstances), 'ResScan: Invalid value for beamDaqID');
            
            %Initialize class data file (ensure props exist in file)
            obj.zprvEnsureClassDataFileProps();
            
            %Initialize the scan maps (from values in Class Data File)
            obj.loadClassData();
            
            obj.parkScanner();
            
            if ~isempty(obj.mdfData.lutCalibrationDaqDevice) && ~isempty(obj.mdfData.lutCalibrationChanID)
                validateattributes(obj.mdfData.lutCalibrationDaqDevice,{'char'},{'nonempty'});
                validateattributes(obj.mdfData.lutCalibrationChanID,{'numeric'},{'integer','nonnegative'});
                obj.hLutCalibrationTask = most.util.safeCreateTask(sprintf('%s Lut Calibration Task',obj.name));
                obj.hLutCalibrationTask.createAIVoltageChan(obj.mdfData.lutCalibrationDaqDevice,obj.mdfData.lutCalibrationChanID);
            end
            
            obj.hZernikeGenerator = scanimage.util.ZernikeGenerator(obj.hSlm,false);
        end
        
        function delete(obj)
            obj.saveClassData();
            most.idioms.safeDeleteObj(obj.hZernikeGenerator);
            most.idioms.safeDeleteObj(obj.hAcq);
            most.idioms.safeDeleteObj(obj.hSlm);
            most.idioms.safeDeleteObj(obj.hLog);
            most.idioms.safeDeleteObj(obj.hLutCalibrationTask);
        end
    end
    
    methods (Access=protected, Hidden)
        function mdlInitialize(obj)
            mdlInitialize@scanimage.components.Scan2D(obj);
            if ~isempty(obj.mdfData.linearScannerName)
                hLinScan_ = obj.hSI.hScanner(obj.mdfData.linearScannerName);
                if isempty(hLinScan_)
                    most.idioms.warn('SlmScan: Scanner ''%s'' is not available in ScanImage',obj.mdfData.linearScannerName);
                    return
                end
                
                linScanClass = 'scanimage.components.scan2d.LinScan';
                if ~isa(hLinScan_,linScanClass)
                    most.idioms.warn('SlmScan: Cannot link to scanner ''%s'' of type ''%s''. Ensure to select a scanner of type ''%s''.',...
                        obj.mdfData.linearScannerName,class(hLinScan_),linScanClass);
                    return
                end
                
                obj.hLinScan = hLinScan_;
                obj.hLinScan.hSlmScan = obj;
            end
        end
    end
    
    methods (Hidden)    
        function updateLiveValues(obj,regenAO)
            if nargin < 2
                regenAO = true;
            end
            
            if obj.active && obj.componentExecuteFunction('updateLiveValues')
                if regenAO
                    obj.hSI.hWaveformManager.updateWaveforms();
                end
                
                if strcmpi(obj.hSI.acqState,'focus')
                    obj.hAcq.bufferAcqParams();
                end
            end
        end
        
        function updateSliceAO(obj)
            error('UpdateSliceAO currently unsupported');
        end
    end
    
    %% PROP ACCESS METHODS
    methods
        function set.zAlignment(obj,val)
            if isempty(val)
                val = scanimage.mroi.util.zAlignmentData();
            end
            
            assert(isa(val,'scanimage.mroi.util.zAlignmentData'));
            obj.hSlm.zAlignment = val;
        end
        
        function val = get.zAlignment(obj)
            val = obj.hSlm.zAlignment;
        end
        
        function set.testPattern(obj,val)
            slmRes = obj.hSlm.pixelResolutionXY;
            
            assert(isempty(val) || (size(val,2)==slmRes(1) && size(val,1)==slmRes(2)),...
                'testPattern must be of size [%d,%d]',slmRes(1),slmRes(2));
            
            obj.testPattern = val;
        end
        
        function set.testPatternPixelToRefTransform(obj,val)
            validateattributes(val,{'numeric'},{'nonnan','finite','size',[3,3]});
            obj.testPatternPixelToRefTransform = val;
            obj.saveClassData();
        end
        
        function set.recordScannerFeedback(obj,val)
            % Unsupported in SlmScan
        end
        
        function set.focalLength(obj,val)
            val = obj.validatePropArg('focalLength',val);
            obj.hSlm.focalLength = val;
            
            % write setting to MDF
            focalLength_mm = val * 1e3; % conversion from m to mm
            obj.writeVarToHeading('focalLength',focalLength_mm);
        end
        
        function val = get.focalLength(obj)
            val = obj.mdfData.focalLength / 1e3; % conversion from mm to m
        end
        
        function set.zeroOrderBlockRadius(obj,val)
            val = obj.validatePropArg('zeroOrderBlockRadius',val);
            
            obj.zeroOrderBlockRadius = val;
            obj.hSlm.zeroOrderBlockRadius = val;
        end
        
        function set.wavelength(obj,val)
            val = obj.validatePropArg('wavelength',val);
            
            val = round(val * 10e12)/10e12; % round to picometer
            
            obj.wavelength = val;
            obj.hSlm.wavelength = val;
            lut_ = obj.retrieveLutFromCache(obj.wavelength);
            obj.lut = lut_;
            
            obj.saveClassData();
        end
        
        function set.parkPosition(obj,val)
             val = obj.validatePropArg('parkPosition',val);
             obj.hSlm.parkPosition = val;
             
             parkPosition_um = val * 1e6; % conversion from m to um
             obj.writeVarToHeading('parkPosition',parkPosition_um);
        end
        
        function val = get.parkPosition(obj)
             val = obj.mdfData.parkPosition / 1e6; % conversion from um to m
        end
        
        function set.staticOffset(obj,val)
            val = obj.validatePropArg('staticOffset',val);
            
            staticOffset_um = val * 1e6; % conversion from m to um
            obj.writeVarToHeading('staticOffset',staticOffset_um);
        end
        
        function val = get.staticOffset(obj)
             val = obj.mdfData.staticOffset / 1e6; % conversion from um to m
        end
        
        function set.lut(obj,val)
            val = obj.validatePropArg('lut',val);
            
            obj.hSlm.lut = val;
            obj.lut = val;
            
            keys = obj.lutMap.keys();
            
            if ~isempty(val)
                assert(issorted(val(:,1)),'First column in LUT needs to be strictly monotonically increasing');
                
                obj.lutMap(obj.wavelength) = val;
                obj.saveClassData();
            elseif obj.lutMap.isKey(obj.wavelength)
                obj.lutMap.remove(obj.wavelength);
            end
        end
        
        function set.wavefrontCorrectionNominal(obj,val)
            val = obj.validatePropArg('wavefrontCorrectionNominal',val);
            
            obj.hSlm.wavefrontCorrectionNominal = val;
            obj.wavefrontCorrectionNominal = val;
            
            obj.saveClassData();
        end
        
        function set.wavefrontCorrectionNominalWavelength(obj,val)
            val = obj.validatePropArg('wavefrontCorrectionNominalWavelength',val);
            obj.wavefrontCorrectionNominalWavelength = val;
            
            obj.hSlm.wavefrontCorrectionNominalWavelength = val;
            obj.wavefrontCorrectionNominalWavelength = val;
            
            obj.saveClassData();
        end
        
        function set.channelOffsets(obj,val)
            obj.channelOffsets = val;
        end        
        
        function set.sampleRate(obj,val)
            validateattributes(val,{'numeric'},{'scalar','positive','nonnan'});
            val = min(val,obj.hSlm.maxRefreshRate);
            obj.sampleRate = val;
        end        
        
        function sz = get.defaultRoiSize(obj)
            % the way this is calculated is not very principled at this
            % point. set to inf for the moment to ignore this setting
            %sz = min(obj.angularRange .* abs(obj.scannerToRefTransform([1 5])));
            sz = Inf;
        end
        
        function range = get.angularRange(obj)
            range = obj.scannerset.angularRange;
        end
        
        function val = get.calibratedWavelengths(obj)
            val = cell2mat(obj.lutMap.keys);
            val = unique(val);
        end
    end
      
    %%% Abstract method implementations (scanimage.components.Scan2D)
    % AccessXXX prop API for Scan2D
    methods (Access = protected, Hidden)        
        function val = fillFracTempToSpat(obj,val)
        end
        
        function val = fillFracSpatToTemp(obj,val)
        end
    
        function val = accessScannersetPostGet(obj,val)
            % Define beam hardware
            if obj.hSI.hBeams.numInstances && ~isempty(obj.mdfData.beamDaqID)
                beams = obj.hSI.hBeams.scanner(obj.mdfData.beamDaqID,[],obj.linePhase,obj.beamClockDelay,obj.beamClockExtend);
            else
                beams = [];
            end
            
            val = scanimage.mroi.scannerset.SLM(obj.name,obj.hSlm,beams,obj.zAlignment,obj.staticOffset);
            val.galvoReferenceAngleXY = obj.galvoReferenceAngleXY;
        end
        
        function accessBidirectionalPostSet(obj,~)
            obj.hSlm.bidirectionalScan = obj.bidirectional;
        end
        
        function val = accessStripingEnablePreSet(~,val)
            % unsupported in SlmScan
            val = false;
        end
        
        function val = accessLinePhasePreSet(obj,val)
        end
        
        function accessLinePhasePostSet(obj)
        end
        
        function val = accessLinePhasePostGet(obj,val)
        end
        
        function val = accessChannelsFilterPostGet(~,val)
        end
        
        function val = accessChannelsFilterPreSet(obj,val)
        end
        
        function accessBeamClockDelayPostSet(obj,~)
        end
        
        function accessBeamClockExtendPostSet(obj,~)
        end
        
        function accessChannelsAcquirePostSet(obj,~)
        end
        
        function val = accessChannelsInputRangesPreSet(obj,val)
            val = obj.hAcq.hAI.setInputRanges(val);
        end
        
        function val = accessChannelsInputRangesPostGet(obj,val)
            val = obj.hAcq.hAI.getInputRanges();
        end
        
        function val = accessChannelsAvailablePostGet(obj,val)
            val = obj.hAcq.hAI.getNumAvailChans;
        end
        
        function val = accessChannelsAvailableInputRangesPostGet(obj,val)
            val = obj.hAcq.hAI.getAvailInputRanges();
        end
                     
        function val = accessFillFractionSpatialPreSet(obj,val)
        end
                     
        function accessFillFractionSpatialPostSet(obj,~)
        end
        
        function val = accessSettleTimeFractionPostSet(obj,val)
        end
        
        function val = accessFlytoTimePerScanfieldPostGet(obj,val)
            val = 0;
        end
        
        function val = accessFlybackTimePerFramePostGet(obj,val)
            val = 0;
        end
        
        function accessLogAverageFactorPostSet(obj,~)
        end
        
        function accessLogFileCounterPostSet(obj,~)
        end
        
        function accessLogFilePathPostSet(obj,~)
        end
        
        function accessLogFileStemPostSet(obj,~)
        end
        
        function accessLogFramesPerFilePostSet(obj,~)
        end
        
        function accessLogFramesPerFileLockPostSet(obj,~)
        end
        
        function val = accessLogNumSlicesPreSet(obj,val)
        end
        
        function val = accessTrigFrameClkOutInternalTermPostGet(obj,val)
        end
        
        function val = accessTrigBeamClkOutInternalTermPostGet(obj,val)
        end
        
        function val = accessTrigAcqOutInternalTermPostGet(obj,val)
        end
        
        function val = accessTrigReferenceClkOutInternalTermPostGet(obj,val)
        end
        
        function val = accessTrigReferenceClkOutInternalRatePostGet(obj,val)
        end
        
        function val = accessTrigReferenceClkInInternalTermPostGet(obj,val)
        end
        
        function val = accessTrigReferenceClkInInternalRatePostGet(obj,val)
        end
        
        function val = accessTrigAcqInTermAllowedPostGet(obj,val)
            val = {''};
        end
        
        function val = accessTrigNextInTermAllowedPostGet(obj,val)
            val = {''};
        end
        
        function val = accessTrigStopInTermAllowedPostGet(obj,val)
            val = {''};
        end
             
        function val = accessTrigAcqEdgePreSet(obj,val)
        end
        
        function accessTrigAcqEdgePostSet(~,~)
        end
        
        function val = accessTrigAcqInTermPreSet(obj,val)
        end
        
        function accessTrigAcqInTermPostSet(~,~)
        end
        
        function val = accessTrigAcqInTermPostGet(obj,val)
        end
        
        function val = accessTrigAcqTypeExternalPreSet(obj,val)
            if val
                error('SlmScan does not support external triggering.');
            end
        end
        
        function accessTrigAcqTypeExternalPostSet(~,~)
        end
        
        function val = accessTrigNextEdgePreSet(obj,val)
        end
        
        function val = accessTrigNextInTermPreSet(obj,val)
        end
        
        function val = accessTrigNextStopEnablePreSet(obj,val)
        end
        
        function val = accessTrigStopEdgePreSet(obj,val)
        end
        
        function val = accessFunctionTrigStopInTermPreSet(obj,val)
        end
        
        function val = accessMaxSampleRatePostGet(obj,val)
        end
        
        function accessScannerFrequencyPostSet(obj,~)
        end
        
        function val = accessScannerFrequencyPostGet(~,val)
        end

        function val = accessScanPixelTimeMeanPostGet(obj,val)
        end
        
        function val = accessScanPixelTimeMaxMinRatioPostGet(obj,val)
        end
        
        function val = accessChannelsAdcResolutionPostGet(obj,~)
            % assume all channels on the DAQ board have the same resolution
            val = obj.hAcq.hAI.adcResolution;
        end
        
        function val = accessChannelsDataTypePostGet(obj,~)
            if isempty(obj.channelsDataType_)
                singleSample = obj.acquireSamples(1);
                val = class(singleSample);
                obj.channelsDataType_ = val;
            else
                val = obj.channelsDataType_;
            end
        end
        
        % Component overload function
        function val = componentGetActiveOverride(obj,val)
        end
        
        function val = accessScannerToRefTransformPreSet(obj,val)
        end
        
        function accessChannelsSubtractOffsetsPostSet(obj)
        end
    end
    
    %% USER METHODS
    
    %%% Abstract methods realizations (scanimage.interfaces.Scan2D)
    methods
        % showZernikeGenerator(obj) opens the Zernike Generator GUI
        function showZernikeGenerator(obj)
            obj.hZernikeGenerator.showGUI();
        end
        
        % methods to issue software triggers
        % these methods should only be effective if specified trigger type
        % is 'software'
        function trigIssueSoftwareAcq(obj)
            obj.hAcq.trigIssueSoftwareAcq();
        end
        
        function trigIssueSoftwareNext(obj)
            errror('Next Trigger is unsupported in SLMScan');
        end
        
        function trigIssueSoftwareStop(obj)
            errror('Stop Trigger is unsupported in SLMScan');
        end
        
        % point SLM to position
        function pointScanner(obj,fastDeg,slowDeg,z)
            if nargin < 4 || isempty(z)
                z = 0;
            end
            
            if obj.componentExecuteFunction('pointScanner',fastDeg,slowDeg,z)
                obj.pointSlm([fastDeg,slowDeg,z]);
                
                if ~isempty(obj.hLinScan)
                    obj.hLinScan.pointScanner(obj.galvoReferenceAngleXY(1),obj.galvoReferenceAngleXY(2));
                end
            end
        end
        
        % center SLM
        function centerScanner(obj)
            if obj.componentExecuteFunction('centerScanner')
                obj.pointScanner(0,0,0);
            end
        end
        
        % park SLM
        function parkScanner(obj)
            if obj.componentExecuteFunction('parkScanner')
                obj.hSlm.parkScanner();
                
                if ~isempty(obj.hLinScan)
                    obj.hLinScan.parkScanner();
                end
            end
        end
        
        function pointSlm(obj,point)
            assert(length(point)==3);
            point = point + obj.staticOffset;
            point = obj.zAlignment.compensateScannerZ(point);
            obj.pointSlmRaw(point);
        end
        
        function pointSlmRaw(obj,point)
            obj.hSlm.pointScanner(point);
        end
        
        % load LUT for current wavelength from file
        % usage:
        %    obj.loadLutFromFile(fileName)
        %    obj.loadLutFromFile(fileName)
        function lut = loadLutFromFile(obj,fileName)
            if nargin < 2 || isempty(fileName)
                fileName = [];
            end
            
            lut = obj.hSlm.loadLutFromFile(fileName);
            
            if isempty(lut)
                return
            end
            
            obj.plotLut(lut);
            
            button = questdlg('Do you want to use this look up table?');
            if strcmpi(button,'Yes')
                obj.lut = lut;
                obj.parkScanner();
            end
        end
        
        % save current SLM LUT to file
        % usage:
        %   obj.saveLutToFile()
        %   obj.saveLutToFile(fileName)
        function saveLutToFile(obj,fileName)
            if nargin < 2 || isempty(fileName)
                fileName = [];
            end
            
            obj.hSlm.saveLutToFile(fileName);
        end
        
        % plot SLM LUT
        % usage:
        %   obj.plotLut()                 plots lut for current wavelength
        %   obj.plotLut(lut,wavelength)   where lut is a nx2 array
        function plotLut(obj,lut,wavelength)
            if nargin < 2 || isempty(lut)
                lut = obj.hSlm.lut;
            end
            
            if nargin < 3 || isempty(wavelength)
                wavelength = obj.hSlm.wavelength;
            end
            
            hFig = figure();
            hAx = axes('Parent',hFig,'Box','on');
            plot(hAx,lut(:,1),lut(:,2));
            hAx.XTick = min(lut(:,1)):(.25*pi):max(lut(:,1));
            
            l = arrayfun(@(v){sprintf('%g\\pi',v)}, round(hAx.XTick/pi,2));
            l(lut(:,1) == 0) = {'0'};
            hAx.XTickLabel = strrep(l,'1\pi','\pi');
            
            hAx.XLim = [min(lut(:,1)) max(lut(:,1))];
            hAx.YLim = [0 2^obj.hSlm.pixelBitDepth-1];
            title(hAx,sprintf('SLM Lut at %.1fnm',wavelength*1e9));
            xlabel(hAx,'Phase');
            ylabel(hAx,'Pixel Value');
            grid(hAx,'on');
        end
        
        % get SLM LUT from cache
        % usage:
        %   lut = obj.retrieveLutFromCache()              get LUT for current wavelength
        %   lut = obj.retrieveLutFromCache(wavelength)    get LUT for specified wavelength
        %
        %   if no lut for specified wavelength is in cache, return value is
        %   empty array
        function lut = retrieveLutFromCache(obj,wavelength)
            if nargin < 2 || isempty(wavelength)
                wavelength = obj.wavelength;
            end
            
            lut = [];
            
            if obj.lutMap.isKey(wavelength)
                lut = obj.lutMap(wavelength);
            end
        end
        
        
        % load Wavefront Correction for current wavelength from file
        % usage:
        %    obj.loadWavefrontCorrectionFromFile(fileName)
        %    obj.loadWavefrontCorrectionFromFile(fileName)
        function wc = loadWavefrontCorrectionFromFile(obj,fileName)
            if nargin < 2 || isempty(fileName)
                fileName = [];
            end
            
            [wc,wavelength_] = obj.hSlm.loadWavefrontCorrectionFromFile(fileName);
            
            if isempty(wc)
                return
            end
            
            obj.wavefrontCorrectionNominal = wc;
            obj.wavefrontCorrectionNominalWavelength = wavelength_;
            obj.parkScanner();
            obj.plotWavefrontCorrection();
        end
        
        % plot SLM Wavefront Correction
        % usage:
        %   obj.plotLut()                 plots lut for current wavelength
        %   obj.plotLut(lut,wavelength)   where lut is a nx2 array
        function plotWavefrontCorrection(obj,wc,wl,wcNominal,wlNominal)
            if nargin < 4 || isempty(wcNominal)
                wc = obj.hSlm.wavefrontCorrectionCurrentWavelength;
            end
            
            if nargin < 5 || isempty(wlNominal)
                wl = obj.hSlm.wavelength;
            end
            
            if nargin < 4 || isempty(wcNominal)
                wcNominal = obj.hSlm.wavefrontCorrectionNominal;
            end
            
            if nargin < 5 || isempty(wlNominal)
                wlNominal = obj.hSlm.wavefrontCorrectionNominalWavelength;
            end
            
            if isempty(wcNominal) || isempty(wc)
                return
            end
            
            hFig = figure('NumberTitle','off','Name','Wavefront Correction');
            
            tabgp = uitabgroup(hFig);
            tabCurrentWl     = uitab(tabgp,'Title','Current Wavelength');
            tabCalibrationWl = uitab(tabgp,'Title','Calibration Wavelength');
            
            hAxCurrentWl = axes('Parent',tabCurrentWl,'Box','on');
            imagesc('Parent',hAxCurrentWl,'CData',wc);
            axis(hAxCurrentWl,'image');
            box(hAxCurrentWl,'on');
            view(hAxCurrentWl,0,-90);
            hCb1 = colorbar(hAxCurrentWl);
            
            hAxCalibrationWl = axes('Parent',tabCalibrationWl,'Box','on');
            imagesc('Parent',hAxCalibrationWl,'CData',wcNominal);
            axis(hAxCalibrationWl,'image');
            box(hAxCalibrationWl,'on');
            view(hAxCalibrationWl,0,-90);
            hCb2 = colorbar(hAxCalibrationWl);
            
            minWc = min([wc(:);wcNominal(:)]);
            maxWc = max([wc(:);wcNominal(:)]);
            
            range = [min(0,floor(minWc/(2*pi))*2*pi) max(ceil(maxWc/(2*pi))*2*pi,2*pi)];
            
            hAxCurrentWl.CLim = range;
            hAxCalibrationWl.CLim = range;
            
            ticks = linspace(range(1),range(2),round(diff(range)/(2*pi))*2+1);
            tickLabels = sprintf('%.1f\\pi\n',ticks/pi);
            set([hCb1,hCb2],'Ticks',ticks,'TickLabels',tickLabels);
            
            title(hAxCurrentWl,sprintf('SLM Wavefront Correction (Radians) at %.1fnm',wl*1e9));
            xlabel(hAxCurrentWl,'x');
            ylabel(hAxCurrentWl,'y');
            
            title(hAxCalibrationWl,sprintf('SLM Wavefront Correction (Radians) at %.1fnm',wlNominal*1e9));
            xlabel(hAxCalibrationWl,'x');
            ylabel(hAxCalibrationWl,'y');
        end
        
        function showPhaseMaskDisplay(obj)
            obj.hSlm.showPhaseMaskDisplay = true;
        end
        
        function writePhaseMask(obj,phaseMask_)
            slmRes = obj.hSlm.pixelResolutionXY;
            
            assert(isequal(size(phaseMask_),fliplr(slmRes)),...
                'testPattern must be of size [%d,%d]',slmRes(2),slmRes(1));
            
            if obj.hSlm.computeTransposedPhaseMask
                phaseMask_ = phaseMask_';
            end
            
            obj.hSlm.writePhaseMaskRad(phaseMask_);
        end
        
        function writeTestPattern(obj,testPattern_)
            if nargin < 2 || isempty(testPattern_)
                testPattern_ = obj.testPattern;
            else
                obj.testPattern = testPattern_;
            end
            
            slmRes = obj.hSlm.pixelResolutionXY;
            
            assert(size(testPattern_,2)==slmRes(1) && size(testPattern_,1)==slmRes(2),...
                'testPattern must be of size [%d,%d]',slmRes(1),slmRes(2));
            
            if obj.hSlm.computeTransposedPhaseMask
                testPattern_ = testPattern_';
            end
            
            obj.hSlm.writePhaseMaskRaw(testPattern_);
        end
        
        %%% Alignment routines
        function setAlignmentReference(obj,slmPosition)
            obj.abortAlignment();
            assert(~isempty(obj.hLinScan),'Cannot use this alignment method without a linear scanner defined');
            assert(strcmpi(obj.hSI.acqState,'focus'),'SLM alignment is only available during active Focus');
            assert(obj.hSI.hScan2D == obj.hLinScan,'Wrong scanner selected. Select linear scanner (galvo-galvo) for imaging, that is in path with SLM');
            
            if nargin < 2 || isempty(slmPosition)
                slmPosition = obj.hSlm.lastWrittenPoint;
            end
            
            obj.hSI.hMotionManager.activateMotionCorrectionSimple();
            obj.alignmentReference = slmPosition;
        end
        
        function addAlignmentPoint(obj,slmPosition, motion)
            assert(~isempty(obj.hLinScan),'Cannot use this alignment method without a linear scanner defined');
            assert(~isempty(obj.alignmentReference),'Set alignment reference first.');
            
            if nargin < 2 || isempty(slmPosition)
                slmPosition = obj.hSlm.lastWrittenPoint;
            end
            
            if nargin < 3 || isempty(motion)
                assert(strcmpi(obj.hSI.acqState,'focus'),'SLM alignment is only available during active Focus');
                assert(obj.hSI.hScan2D == obj.hLinScan,'Wrong scanner selected. Select linear scanner (galvo-galvo) for imaging, that is in path with SLM');
                
                if ~obj.hSI.hMotionManager.enable
                    assert(~isempty(obj.hSI.hChannels.channelDisplay),'Cannot activate motion correction if no channels are displayed.');
                    obj.hSI.hMotionManager.activateMotionCorrectionSimple();
                end
                
                assert(~isempty(obj.hSI.hMotionManager.motionHistory(end)),'Cannot add alignment point because the motion history is empty.');
                motion = obj.hSI.hMotionManager.motionHistory(end).drRef;
                assert(~any(isnan(motion(1:2))),'Cannot add alignment point because the motion vector is invalid');
            end
            
            obj.alignmentPoints(end+1,:) = {slmPosition, motion(1:2)};
            
            pts = vertcat(obj.alignmentPoints{:,1});
            d = max(pts(:,3:end),[],1)-min(pts(:,3:end),[],1);
            
            if any(d > 1)
                warning('SLM alignment points are taken at different z depths.');
            end
        end
        
        function createAlignmentMatrix(obj)
            assert(~isempty(obj.hLinScan),'Cannot calculate alignment matrix without a linear scanner defined');
            assert(~isempty(obj.alignmentReference),'No alignment reference has been set');
            assert(size(obj.alignmentPoints,1)>=3,'At least three points are needed to perform the alignment');
            
            slmPoints = vertcat(obj.alignmentPoints{:,1});
            if size(slmPoints,2) >= 3
                assert(all(abs(slmPoints(:,3)-slmPoints(1,3)) < 1),'All points for alignment need to be taken on the same z plane and at the same rotation');
            end
            
            slmPoints = slmPoints(:,1:2);
            motionPoints = obj.alignmentPoints(:,2);
            motionPoints = -vertcat(motionPoints{:});
            
            slmPoints(:,3) = 1;
            motionPoints(:,3) = 1;
            
            T = motionPoints' * pinv(slmPoints');
            
            tAlignmentReference = eye(3);
            tAlignmentReference(7:8) = obj.alignmentReference(1:2);
            
            TLinScan = eye(3);
            TLinScan(7:8) = obj.hLinScan.scannerToRefTransform(7:8);
            
            obj.scannerToRefTransform = TLinScan*T*tAlignmentReference;
            
            obj.abortAlignment();
        end
        
        function abortAlignment(obj)
            obj.alignmentReference = [];
            obj.alignmentPoints = cell(0,2);
        end
    end
    
    %% INTERNAL METHODS
    methods (Hidden)
        function setupRoutes(obj)            
            if isempty(obj.mdfData.deviceNameAux) || isempty(obj.mdfData.slmUpdateTriggerInputTerm)
                obj.hardwareTimedAcquisition = false;
            else
                obj.hAcq.hAI.sampClkSrc = sprintf('/%s/%s',obj.mdfData.deviceNameAux,obj.mdfData.slmUpdateTriggerInputTerm);
                obj.hAcq.hAI.sampClkPolarity = obj.mdfData.slmUpdateTriggerPolarity;
                obj.hardwareTimedAcquisition = true;
            end
        end
        
        function reinitRoutes(obj)
            % no-op
        end
        
        function deinitRoutes(obj)
            obj.abort();
        end
        
        function frameAcquiredFcn(obj,src,evnt) %#ok<INUSD>
            if obj.active
                obj.stripeAcquiredCallback(obj,[]);
            end
        end
        
        function ziniExpandChannelsInvert(obj)
            if isscalar(obj.mdfData.channelsInvert)
                obj.mdfData.channelsInvert = repmat(obj.mdfData.channelsInvert,1,obj.channelsAvailable);
            else
                assert(isvector(obj.mdfData.channelsInvert));
                assert(numel(obj.mdfData.channelsInvert) == obj.channelsAvailable,...
                    'MDF invalid setting: If providing a vector for MDF entry ''channelsInvert'', provide a value for each channel in the task.');
            end
        end
    end
    
    %%% Abstract methods realizations (scanimage.interfaces.Scan2D)    
    methods (Hidden)
        function calibrateLinePhase(obj,varargin)
            msgbox('Auto adjusting the line phase is unsupported in SlmScan','Unsupported','error');
            error('Calibrating the line phase is unsupported in SlmScan');
        end
        
        function arm(obj,activateStaticScanners)
        end
        
        function data = acquireSamples(obj,numSamples)
            data = obj.hAcq.acquireSamples(numSamples);
        end
        
        function data = acquireLutCalibrationSample(obj,nSamples)
            if nargin < 1 || isempty(nSamples)
                nSamples = 1; 
            end
                
            if isempty(obj.hLutCalibrationTask) || ~isvalid(obj.hLutCalibrationTask)
                data = obj.acquireSamples(nSamples); % use digitizer
            else
                data = obj.hLutCalibrationTask.readAnalogData(nSamples); % use dedicated Task
            end
        end
        
        function signalReadyReceiveData(obj)
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
    end
    
    %% Abstract methods realizations (scanimage.interfaces.Component)
    methods (Access = protected, Hidden)
        function componentStart(obj,varargin)
            assert(~obj.robotMode);
            %assert(~obj.hSI.hChannels.loggingEnable,'Currently Logging is not supported in SlmScan');
            
            if ~isempty(obj.hLinScan)
                obj.hLinScan.pointScanner(obj.galvoReferenceAngleXY(1),obj.galvoReferenceAngleXY(2));
            end
            obj.hLog.start();
            obj.hAcq.start();
        end
        
        function componentAbort(obj,varargin)
            obj.hAcq.abort();
            obj.hLog.abort();
            obj.parkScanner();
        end
    end
    
    %% Private methods
    methods (Access = private)
        function zprvEnsureClassDataFileProps(obj)
            obj.ensureClassDataFile(struct('lutMap',struct('keys',{{}},'values',{{}})),obj.classDataFileName);
            obj.ensureClassDataFile(struct('wavefrontCorrectionNominal',[]),obj.classDataFileName);
            obj.ensureClassDataFile(struct('wavefrontCorrectionNominalWavelength',[]),obj.classDataFileName);
            obj.ensureClassDataFile(struct('wavelength',double(635e-9)),obj.classDataFileName);
            obj.ensureClassDataFile(struct('testPatternPixelToRefTransform',eye(3)),obj.classDataFileName);
            obj.ensureClassDataFile(struct('zAlignment',struct()),obj.classDataFileName);
        end
        
        function loadClassData(obj)
            try
                obj.cancelSaveClassData = true;
                
                lutMapStruct = obj.getClassDataVar('lutMap',obj.classDataFileName);
                if ~isempty(lutMapStruct.keys)
                    lutMap_ = containers.Map('KeyType','double','ValueType','any');
                    for idx = 1:length(lutMapStruct.keys)
                        lutMap_(lutMapStruct.keys{idx}) = lutMapStruct.values{idx};
                    end
                    obj.lutMap = lutMap_;
                end
                
                obj.wavefrontCorrectionNominal = obj.getClassDataVar('wavefrontCorrectionNominal',obj.classDataFileName);
                obj.wavefrontCorrectionNominalWavelength = obj.getClassDataVar('wavefrontCorrectionNominalWavelength',obj.classDataFileName);
                obj.wavelength = obj.getClassDataVar('wavelength',obj.classDataFileName);
                obj.testPatternPixelToRefTransform = obj.getClassDataVar('testPatternPixelToRefTransform',obj.classDataFileName);
                obj.zAlignment = scanimage.mroi.util.zAlignmentData(obj.getClassDataVar('zAlignment',obj.classDataFileName));
                
                obj.cancelSaveClassData = false;
            catch ME
                obj.cancelSaveClassData = false;
                rethrow(ME);
            end
        end
        
        function saveClassData(obj)
            if obj.cancelSaveClassData
                return
            end
            
            lutMapStruct = struct('keys',{obj.lutMap.keys},'values',{obj.lutMap.values});
            obj.setClassDataVar('lutMap',lutMapStruct,obj.classDataFileName);
            obj.setClassDataVar('wavefrontCorrectionNominal',obj.wavefrontCorrectionNominal,obj.classDataFileName);
            obj.setClassDataVar('wavefrontCorrectionNominalWavelength',obj.wavefrontCorrectionNominalWavelength,obj.classDataFileName);
            obj.setClassDataVar('wavelength',obj.wavelength,obj.classDataFileName);
            obj.setClassDataVar('testPatternPixelToRefTransform',obj.testPatternPixelToRefTransform,obj.classDataFileName);
            obj.setClassDataVar('zAlignment',obj.zAlignment.toStruct(),obj.classDataFileName);
        end
    end
end

function s = zlclAppendDependsOnPropAttributes(s)
    s.wavelength            = struct('Classes','numeric','Attributes',{{'positive','finite','scalar','<',2e-6}});
    s.focalLength           = struct('Classes','numeric','Attributes',{{'positive','finite','scalar'}});
    s.zeroOrderBlockRadius  = struct('Classes','numeric','Attributes',{{'nonnegative','finite','scalar'}});
    s.lut                   = struct('Classes','numeric','Attributes',{{'ncols',2}},'AllowEmpty',1);
    s.wavefrontCorrectionNominal = struct('Classes','numeric','Attributes',{{'2d'}},'AllowEmpty',1);
    s.wavefrontCorrectionNominalWavelength = struct('Classes','numeric','Attributes',{{'positive','finite','scalar'}},'AllowEmpty',1);
    s.parkPosition          = struct('Classes','numeric','Attributes',{{'row','numel',3}});
    s.staticOffset          = struct('Classes','numeric','Attributes',{{'row','numel',3}});
end

function s = defaultMdfSection()
    s = [...
        makeEntry('slmType','','one of {''dummy'',''generic'',''meadowlark.ODP'',''meadowlark.1920''}')...
        makeEntry()... % blank line
        makeEntry('linearScannerName','','Name of galvo-galvo-scanner (from first MDF section) to use in series with the SLM. Must be a linear scanner')...
        makeEntry('deviceNameAcq','','String identifying NI DAQ board for PMT channels input')...
        makeEntry('deviceNameAux','','String identifying NI DAQ board where digital triggers are wired')...
        makeEntry()... % blank line
        makeEntry('channelIDs',[],'Array of numeric channel IDs for PMT inputs. Leave empty for default channels (AI0...AIN-1)')...
        makeEntry('channelsInvert',false,'Scalar or vector identifiying channels to invert. if scalar, the value is applied to all channels')...
        makeEntry()... % blank line
        makeEntry('slmUpdateTriggerInputTerm','','Terminal on aux device, to which the SLM updated trigger is connected (e.g. ''PFI1''). Leave empty if SLM does not provide this trigger.')...
        makeEntry('slmUpdateTriggerPolarity','rising','Trigger polarity of the SLM updated trigger one of {''rising'',''falling''}')...
        makeEntry()... % blank line
        makeEntry('slmUpdateTriggerOutputTerm','','Terminal on aux device, to which the SLM update trigger is connected (e.g. ''PFI1''). Leave empty if SLM does not use this trigger')...
        makeEntry()... % blank line
        makeEntry('shutterIDs',[],'Array of the shutter IDs that must be opened for linear scan system to operate')...
        makeEntry('beamDaqID',[],'Numeric: ID of the beam DAQ to use with the linear scan system')...
        makeEntry()... % blank line
        makeEntry('focalLength',100,'[mm] Effective focal length of the optical path')...
        makeEntry('zeroOrderBlockRadius',0.1,'[mm] Radius of area at center of SLM FOV that cannot be excited, usually due to presence of zero-order beam block')...
        makeEntry()... % blank line
        makeEntry('parkPosition',[0 0 0],'[x,y,z] SLM park position in microns')...
        makeEntry('staticOffset',[0 0 0],'[x,y,z] Offset applied to SLM coordinates in microns')...
        makeEntry()... % blank line
        makeEntry('lutCalibrationDaqDevice','','Name of NI DAQ for measuring intensity of zero order spot for LUT calibration (e.g. ''PXI1Slot4''). If empty, channels from ''deviceNameAcq'' are used')...
        makeEntry('lutCalibrationChanID',[],'DAQ channel for measuring intensity of zero order spot for LUT calibration (e.g. 1)')...
        makeEntry()... % blank line
        makeEntry('Advanced/Optional')...
        makeEntry('secondaryFpgaFifo',false)...
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
% SlmScan.m                                                                %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
