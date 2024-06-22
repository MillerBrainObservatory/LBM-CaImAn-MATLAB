classdef Scan2D < scanimage.interfaces.Component & most.HasClassDataFile 
    % Common interface for 2D scanner systems
    
    %% USER PROPS
    %%% Abstract props
    properties (Abstract, Constant)
        scannerType;                        % string describing the used scanner technology
        builtinFastZ;                       % logical, indicates if scanner has builtin FastZ support
    end
    
    properties (Hidden, Abstract, Constant)
        linePhaseUnits;                     % Line Phase Units; one of {'seconds','pixels'}
    end
    
    %%% Acquisition channel properties
    properties (SetObservable)
        channelsSubtractOffsets = true;     % [logical] 1D Array specifying for each channel if the offset is subtracted
        channelsAutoReadOffsets = true;     % [logical] automatically reads the offset at start of acquisition mode
        channelsInputRanges;                % [V] 1D cell array of [min max] input ranges for each channel
        channels = {};                      % [V] 1D cell array of channel objects.
        channelsFilter = '';                % channels filter type
    end
    
    properties (SetObservable)
        linePhase = 0.0;                    % [s] phase delay of fast mirror position
        beamClockDelay = 1.5e-6;            % [s] delay between start of line and onset of pockel cell activation; a positive value activates the pockel cell early and can compensate for the response time of the pockel cell
        beamClockExtend = 0;                % [s] delay between the end of the line and the deactivation of the pockel cell
                
        % Scanner parameters
        bidirectional          = true;      % (logical) specifies if a line is formed during fast mirror flyback
        stripingEnable         = false;     % (logical) specifies if the display is refreshed in stripes
        flybackTimePerFrame    = 1e-3;      % [s] time to allow galvos to fly back after one frame is complete
        flytoTimePerScanfield  = 1e-3;      % [s] time to allow galvos to fly from one scanfield to the next
        fillFractionSpatial    = 0.9;       % specifies the portion of the scan field to be used to form a line (spatial)
        settleTimeFraction     = 0;         % specifies the portion of fillFractionTemporal used to let the fast mirror settle
		
        % Trigger parameters
        trigNextStopEnable  = false;        % boolean, configures acquisition for next and stop triggering
        trigAcqInTerm  = '';                % string specifying the acquisition trigger input terminal
        trigNextInTerm = '';                % string specifying the next file marker input terminal
        trigStopInTerm = '';                % string specifying the stop trigger input terminal
        trigAcqEdge  = 'rising';            % string, polarity of the trigger edge; one of {'rising','falling'}
        trigNextEdge = 'rising';            % string, polarity of the trigger edge; one of {'rising','falling'}
        trigStopEdge = 'rising';            % string, polarity of the trigger edge; one of {'rising','falling'}
        
        % Logging parameters
        logAverageFactor = 1;               % number of logged frames to average together for each logged frame.
        logFramesPerFile = inf;             % integer, for split files only: how many images per file to capture before rolling over a new file.
        logOverwriteWarn = false;           % logical flag for whether SI should warn the user about possible data overwritting.
    end
    
    %These are stored in class data file, so don't cfg
    properties (SetObservable, Transient)
        scannerToRefTransform=eye(3);       % Affine transforming for registering different scanners. (default: identity)
    end
    
    properties (SetAccess=immutable)
        name;                               % Name of the Scan2D component
    end
    
    properties (Abstract, SetObservable)
        pixelBinFactor;                     % number of acquisition samples that form one pixel, only applicable in LinScan
        sampleRate;                         % [Hz] sample rate of the digitizer / mirror controls
        channelOffsets;                     % [native] 1D Array of offsets to be subtracted from image data
        keepResonantScannerOn;
    end
    
    properties (SetObservable, Transient)
        % Acquisition properties
        scanPixelTimeMean;                  % [s] mean acquisition time of one pixel
        scanPixelTimeMaxMinRatio;           % [s] ratio between max acquisition time and min acquisition time of pixels in one line
        
        % System information
        maxSampleRate;                      % [Hz] maximum sample rate of the imaging system
        channelsAvailable;                  % number of channels available on the digitizer board
        channelsAvailableInputRanges;       % [V] 1D cell array of settable [min, max] input ranges of the digitizer
        channelsAdcResolution;              % [bits] resolution of ADC
        channelsDataType;                   % [type] data type of data from ADC
        
        % Logging parameters
        logFileStem      = '';              % string, base name of the image file (without extension)
        logFileCounter   = 1;               % number to append to logging base filename.
        logFramesPerFileLock = false;       % boolean, for locking # of frames per file for split files only.
    end
    
    properties (SetObservable, Transient, Dependent)
        fillFractionTemporal;               % specifies the portion of the scan field to be used to form a line (temporal)
        
        %+++ The following is a workaround to SIDEV-194 for the sake of fast development. However, it doesn't 
        % use best practices and should be changed.
        logFilePath;                        % string, path where tif files will be written
    end

    properties (SetAccess = protected, SetObservable)
        scannerFrequency;                   % [Hz] frequency of resonant scanner
    end
    
    properties (SetAccess = protected)      % Constructor initialized properties
        simulated;                          % (logical) if true, no hardware should be required for execution and dummydata should be returned
        nominalFovCornerPoints;
        fovCornerPoints;
    end
        
    %% FRIEND PROPS
    properties (Hidden, SetAccess={?scanimage.interfaces.Class})
        logFileSubCounter = 1;              % number to append to logging filename when chunking acquisition into several subfiles, via logFramesPerFile
        logOpenModeString = 'wbn';          % standard file mode properties to be applied to logging TIF files.
        
        %TODO: Rename to logAppendAcqs & logAppendNumAcqs
        logSlowStack = false;               % boolean, if true, multiple acqs are appended into single file
        logNumSlices = 1;                   % number of acqs to append
        
        framesPerAcq = 1;                   % number of frames per acquisition trigger
        framesPerStack = 1;                 % number of frames per volume, for fastZ operation
        
        trigAcqTypeExternal = false;        % boolean, if false start acquisition with function obj.trigIssueSoftwareAcq
        trigAcqNumRepeats = 0;              % integer, specifying number of times to allow start acqusition trigger to occur (including first trigger)
       
        stripeAcquiredCallback = @(src,evnt)most.idioms.dispError('No Callback defined\n');             % handle to function executed on every acquired stripe, only settable while acquisition inactive.

        tifHeaderData = [];                 % binary data to be written at the start of each tiff file that gets written
        tifHeaderStringOffset = 0;          % offset into binary header data where string to assign to "software" tag starts
        tifRoiDataStringOffset = 0;         % offset into binary header data where string to assign to "artist" tag starts
        
        hSlmScan;
        hDataScope;                          % handle to DataScope object
    end
    
    properties (Hidden)
        displayDecimationFactor = 1; % accessed by MEX. should be removed
    end
    
    properties (Hidden, SetAccess=protected)
        trigFrameClkOutInternalTerm;        % string, internal output terminal of the frame clock
        trigBeamClkOutInternalTerm;         % string, internal output terminal of the beam clock
        trigAcqOutInternalTerm;             % string, internal output terminal of the acquisition trigger
        trigReferenceClkOutInternalTerm;    % string, internal output terminal of the reference clock
        trigReferenceClkOutInternalRate;    % numeric, specifies the rate of the clock exported on trigReferenceClkOutInternalTerm
        trigReferenceClkInInternalTerm;     % string, internal input terminal of the reference clock
        trigReferenceClkInInternalRate;     % numeric, specifies the rate of the clock imported on trigReferenceClkInInternalTerm
        
        trigAcqInTermAllowed;               % cell array of strings with allowed terminal names for the acq trigger (e.g. {'PFI1','PFI2'})
        trigNextInTermAllowed;              % cell array of strings with allowed terminal names for the acq trigger (e.g. {'PFI1','PFI2'})
        trigStopInTermAllowed;              % cell array of strings with allowed terminal names for the acq trigger (e.g. {'PFI1','PFI2'})        
    end
    
    properties (SetAccess=private, Dependent, Transient)
        currentRoiGroup = [];               % The current roiGroup used for imaging
    end
    
    properties (Hidden, Dependent, SetObservable)
        % scannerset needs to be SetObservable
        scannerset;                         % scanimage.mroi.scannerset.ScannerSet 
    end

    properties (Hidden, Dependent)
        logFullFilename;                    % Forms full filename using log file stem and path.
    end
    
    %% INTERNAL PROPS
    properties (Hidden, SetAccess=private)
        abortUpdatePixelRatioProps = false;
        classDataFileName = '';
        cdInit = false;
    end
    
%     properties (Hidden, SetObservable, Dependent)
%         channelsActive;                     % channels that are currently processed. union of channelsAcquire and logChannels
%     end
    
    %%% Constants
    properties (Hidden, Constant)
        LOG_DEFAULT_FILE_STEM = 'file';     % if no filestem is provided, this file stem is used
    end
    
    %%% Abstract properties
    properties (Abstract, Hidden, SetAccess = protected)
        linePhaseStep;                      % [s] minimum step size of the linephase
        angularRange;
        defaultRoiSize;
        supportsRoiRotation;
    end
            
    %% LIFECYCLE
    methods
        function obj = Scan2D(hSI,simulated,name,legacymode)
            if nargin > 3 && ~isempty(legacymode) && legacymode
            else
                legacymode = false;
            end
            
            obj = obj@scanimage.interfaces.Component(hSI,[],true);
            obj.name = name;
            
            if nargin < 2 || isempty(simulated)
                simulated = false;
            else
                assert(islogical(simulated) && isscalar(simulated), 'Invalid value of ''simulated'' supplied - must be a logical scalar');
            end
            obj.simulated = simulated;
            
            % Determine CDF name and path
            if isempty(obj.hSI.classDataDir)
                pth = most.util.className(class(obj),'classPrivatePath');
            else
                pth = obj.hSI.classDataDir;
            end
            classNameShort = most.util.className(class(obj),'classNameShort');
            if ~legacymode
                classNameShort = [classNameShort '_' name];
            end
            obj.classDataFileName = fullfile(pth, [classNameShort '_classData.mat']);
            
            obj.ensureClassDataFile(struct('scannerToRefTransform',eye(3)),obj.classDataFileName);
            obj.scannerToRefTransform = obj.getClassDataVar('scannerToRefTransform',obj.classDataFileName);
            
            obj.cdInit = true;
        end
    end
    
    methods (Access=protected, Hidden)
        function mdlInitialize(obj)
            mdlInitialize@most.Model(obj);
        end
    end
    
    %% PROPERTY ACCESSS METHODS
    methods            
        %TODO: Rename this to loggingFullFileNameBase & get rid of loggingFullFileName property references altogether
        function val = get.logFullFilename(obj)
            val = fullfile(obj.logFilePath,obj.logFileStem);
        end
        
        function val = get.channelsFilter(obj)
            val = obj.channelsFilter;
        end
        
        function set.channelsFilter(obj,val)
            val = obj.validatePropArg('channelsFilter',val);
            if obj.componentUpdateProperty('channelsFilter',val)
                val = obj.accessChannelsFilterPreSet(val);
                obj.channelsFilter = val;
            end            
        end
        
        function set.scannerset(obj,val)
            obj.mdlDummySetProp(val,'scannerset');
        end
        
        function val = get.scannerset(obj)
            val = obj.accessScannersetPostGet(obj);
            val.scannerToRefTransform = obj.scannerToRefTransform;
            if ~isempty(obj.hSlmScan)
                val.slm = getScan2DScannerset(obj.hSlmScan);
            end
            
            function ss = getScan2DScannerset(hObj)
                % workaround: query scannerset in a separate function to
                % avoid error message
                % 'the get method for Dependent property 'scannerset'
                % attempts to access the stored property value.
                % Dependent properties don't store a value and can't be
                % accessed from their get method.'
                ss = hObj.scannerset;
            end
        end
        
        function set.bidirectional(obj,val)
            val = obj.validatePropArg('bidirectional',val);
            if obj.componentUpdateProperty('bidirectional',val)
                val = logical(val); % convert 'binaryflex' to 'logical'
                obj.bidirectional = val;
                obj.accessBidirectionalPostSet(val);
            end
        end
        
        function set.stripingEnable(obj,val)
            val = obj.validatePropArg('stripingEnable',val);
            if obj.componentUpdateProperty('stripingEnable',val)
                val = logical(val); % convert 'binaryflex' to 'logical'
                val = obj.accessStripingEnablePreSet(val);
                obj.stripingEnable = val;
            end
        end
        
        function val = get.linePhase(obj)
            val = obj.linePhase;
            val = obj.accessLinePhasePostGet(val);
        end
        
        function set.linePhase(obj,val)
            val = obj.validatePropArg('linePhase',val);
            if obj.componentUpdateProperty('linePhase',val)
                val = obj.accessLinePhasePreSet(val);
                obj.linePhase = val;
                obj.accessLinePhasePostSet();
            end
        end
        
        function set.framesPerStack(obj,val)
            validateattributes(val,{'numeric'},{'scalar','nonnegative'});
            obj.framesPerStack = val;
            
            %Side Effects
			%+++ 
            %obj.logAverageFactor = obj.logAverageFactor; %applies constraint            
            %if obj.logFramesPerFileLock
                %obj.logFramesPerFile = val;
            %end
        end

        function set.framesPerAcq(obj,val)
            obj.framesPerAcq = val;
            
            %Side Effects
            obj.logAverageFactor = obj.logAverageFactor; %applies constraint            
            if obj.logFramesPerFileLock
                obj.logFramesPerFile = val;
            end
        end
        
        function set.beamClockDelay(obj,val)
            val = obj.validatePropArg('beamClockDelay',val);
            if obj.componentUpdateProperty('beamClockDelay',val)
                obj.beamClockDelay = val;
                obj.accessBeamClockDelayPostSet(val);
            end
        end
        
        function set.beamClockExtend(obj,val)
            val = obj.validatePropArg('beamClockExtend',val);
            if obj.componentUpdateProperty('beamClockExtend',val)
                obj.beamClockExtend = val;
                obj.accessBeamClockExtendPostSet(val);
            end
        end
        
        function set.channelsInputRanges(obj,val)
            val = obj.validatePropArg('channelsInputRanges',val);
            
            if obj.componentUpdateProperty('channelsInputRanges',val)
                val = obj.accessChannelsInputRangesPreSet(val);
                obj.channelsInputRanges = val;
            end
        end
        
        function val = get.channelsInputRanges(obj)
            val = obj.channelsInputRanges;
            val = obj.accessChannelsInputRangesPostGet(val);
        end
        
        function set.channelsAutoReadOffsets(obj,val)
            val = obj.validatePropArg('channelsAutoReadOffsets',val);
            
            if obj.componentUpdateProperty('channelsAutoReadOffsets',val)
                obj.channelsAutoReadOffsets = val;
            end
        end
        
        function set.fillFractionSpatial(obj,val)
            val = obj.validatePropArg('fillFractionSpatial',val);
            if obj.componentUpdateProperty('fillFractionSpatial',val)
                obj.fillFractionSpatial = obj.accessFillFractionSpatialPreSet(val);
                obj.accessFillFractionSpatialPostSet(val);
            end
        end
        
        function set.fillFractionTemporal(obj,val)
            if ~isnan(val)
                val = obj.validatePropArg('fillFractionTemporal',val);
                if obj.componentUpdateProperty('fillFractionTemporal',val)
                    obj.fillFractionSpatial = obj.fillFracTempToSpat(val);
                end
            end
        end
        
        function val = get.fillFractionTemporal(obj)
            val = obj.fillFracSpatToTemp(obj.fillFractionSpatial);
        end
        
        
        function set.settleTimeFraction(obj,val)
            val = obj.validatePropArg('settleTimeFraction',val);
            if obj.componentUpdateProperty('settleTimeFraction',val)
                obj.settleTimeFraction = val;
                obj.accessSettleTimeFractionPostSet(val);
            end
        end
        
        function set.flytoTimePerScanfield(obj,val)
            val = obj.validatePropArg('flytoTimePerScanfield',val);
            if obj.componentUpdateProperty('flytoTimePerScanfield',val)
                obj.flytoTimePerScanfield = val;
            end
        end
        
        function set.flybackTimePerFrame(obj,val)
            val = obj.validatePropArg('flybackTimePerFrame',val);
            if obj.componentUpdateProperty('flybackTimePerFrame',val)
                obj.flybackTimePerFrame = val;
            end
        end
        
        function v = get.flytoTimePerScanfield(obj)
            v = obj.accessFlytoTimePerScanfieldPostGet(obj.flytoTimePerScanfield);
        end
        
        function v = get.flybackTimePerFrame(obj)
            v = obj.accessFlybackTimePerFramePostGet(obj.flybackTimePerFrame);
        end
        
        function set.logAverageFactor(obj,val)
            val = obj.validatePropArg('logAverageFactor',val);
            
            if obj.componentUpdateProperty('logAverageFactor',val)
                
                %Constrain prop
                if (~isinf(obj.hSI.hStackManager.framesPerSlice) && rem(obj.hSI.hStackManager.framesPerSlice,val)) && ~obj.hSI.hConfigurationSaver.cfgLoadingInProgress
                    if val > 1
                        most.idioms.warn('Value of ''logAverageFactor'' must be integer sub-multiple of ''framesPerSlice''');
                    end
                    val = 1;
                end
                
                
                %Set prop
                obj.logAverageFactor = val;
                %JLF Tag -- Need to do this for linear acq as well. Add a
                %bunch of stuff ...
                % This line will call the same function in LinScan but that
                % function is not implemented. 
                obj.accessLogAverageFactorPostSet(val); %Send logging average factor to resonant acq.
                
                %Side-effects
                if obj.hSI.hDisplay.displayRollingAverageFactorLock
                    obj.hSI.hDisplay.zprpLockDisplayRollAvgFactor();
                end
            end 
        end
        
        % First number, Acq #
        function set.logFileCounter(obj,val)
            val = obj.validatePropArg('logFileCounter',val);
                autoVal = obj.getNextFileCounter;
                if val < autoVal && obj.logOverwriteWarn
                    decision = questdlg(['ScanImage has detected a file' ...
                        ' in the logging directory with the same basename' ...
                        ' and a lower or equal acquisition number. This may indicate' ...
                        ' that you are about to overwrite data. Do you wish to continue?'], 'Warning!');
                    if strcmp(decision, 'Yes')
                        obj.logFileCounter = val;
                        obj.accessLogFileCounterPostSet(val);
                    else
                        val = autoVal;
                        obj.logFileCounter = val;
                        obj.accessLogFileCounterPostSet(val);
%                         return
                    end
                else
                    obj.logFileCounter = val;
                    obj.accessLogFileCounterPostSet(val);
                end
        end
        
        function set.logFilePath(obj,val)
            val = obj.validatePropArg('logFilePath',val);
            if obj.componentUpdateProperty('logFilePath',val)
                %obj.logFilePath = obj.staticLogFilePath(val);
                obj.staticLogFilePath(val);
                obj.accessLogFilePathPostSet(val);
                
                % side effect
                obj.logFileStem = obj.logFileStem; % to coerce logFileCounter and signal resizeAcquisition
            end
        end
        
        function set.logFileStem(obj,val)
            val = obj.validatePropArg('logFileStem',val);
            if isempty(val)
                val = obj.LOG_DEFAULT_FILE_STEM;
            end
            
            val = regexprep(val,'(.tiff|.tif)+$','','ignorecase'); % Remove extension if provided
            
            if ~isempty(regexp(val, '[/\\\*:\?"<>\|]', 'once'))
                most.idioms.dispError('Filename contains illegal characters\n');
                return
            end
            
            
            if obj.componentUpdateProperty('logFileStem',val)
                
                oldVal = obj.logFileStem;
                obj.logFileStem = val;
                obj.accessLogFileStemPostSet(val);
                
                %Side-effects
                obj.logFileCounter = obj.getNextFileCounter();
            end
        end
        
        % This probably needs to get played with...
        function set.logFramesPerFile(obj,val)
            val = obj.validatePropArg('logFramesPerFile',val);
            if ~isinf(val)
%                assert(mod(val,1)==0 && val >= 1,'logFramesPerFile must be inf or a positive integer');
                if ~(mod(val,1)==0) || (val < 1)
                    most.idioms.dispError('The logFramesPerFile field must be Inf or a positive integer');
                    val = Inf;
                end
            end
            
            if obj.componentUpdateProperty('logFramesPerFile',val)
                if obj.logFramesPerFileLock && ~isempty(obj.hSI) && isvalid(obj.hSI)
                    val = obj.hSI.framesPerAcq; % Should be frames per slice if slice > 1
                    val = max(1,val);
                end
                
                obj.logFramesPerFile = val;
                obj.accessLogFramesPerFilePostSet(val);
            end
        end
        
        function set.logFramesPerFileLock(obj,val)
            val = obj.validatePropArg('logFramesPerFileLock',val);
            if obj.componentUpdateProperty('logFramesPerFileLock',val)
                obj.logFramesPerFileLock = val;
                accessLogFramesPerFileLockPostSet(obj,val);
                
                %Side-effects
                if val
                    obj.logFramesPerFile = obj.logFramesPerFile;  %applies constraint
                end
            end
        end
        
        function set.stripeAcquiredCallback(obj,val)
            val = obj.validatePropArg('stripeAcquiredCallback',val);
            if obj.componentUpdateProperty('stripeAcquiredCallback',val)
                obj.stripeAcquiredCallback = val;
            end
        end
        
        function set.trigAcqEdge(obj,val)
            val = obj.validatePropArg('trigAcqEdge',val);
            if obj.componentUpdateProperty('trigAcqEdge',val)
                val = obj.accessTrigAcqEdgePreSet(val);
                obj.trigAcqEdge = val;
                obj.accessTrigAcqEdgePostSet(val);
            end
        end
        
        function set.trigAcqInTerm(obj,val)
            val = obj.validatePropArg('trigAcqInTerm',val);
            %assert(isempty(val) || ismember(val,obj.trigAcqInTermAllowed),'Not a valid trigger terminal for acquisition trigger: %s',val);
            if obj.componentUpdateProperty('trigAcqInTerm',val)
                val = obj.accessTrigAcqInTermPreSet(val);
                obj.trigAcqInTerm = val;
                obj.accessTrigAcqInTermPostSet(val);
            end
        end
        
        function set.trigAcqTypeExternal(obj,val)
            val = obj.validatePropArg('trigAcqTypeExternal',val);
            if val
                assert(~isempty(obj.trigAcqInTerm),'Cannot activate external trigger. No external acquisition trigger name specified.');
            end
            
            if obj.componentUpdateProperty('trigAcqTypeExternal',val)
                val = obj.accessTrigAcqTypeExternalPreSet(val);
                obj.trigAcqTypeExternal = val;
                obj.accessTrigAcqTypeExternalPostSet(val);
            end
        end
        
        function set.trigNextEdge(obj,val)
            val = obj.validatePropArg('trigNextEdge',val);
            if obj.componentUpdateProperty('trigNextEdge',val)
                val = obj.accessTrigNextEdgePreSet(val);
                obj.trigNextEdge = val;
            end
        end
        
        function set.trigNextInTerm(obj,val)
            val = obj.validatePropArg('trigNextInTerm',val);
            %assert(isempty(val) || ismember(val,obj.trigNextInTermAllowed),'Not a valid trigger terminal for next file marker: %s',val);
            if obj.componentUpdateProperty('trigNextInTerm',val)
                val = obj.accessTrigNextInTermPreSet(val);
                obj.trigNextInTerm = val;
            end
        end
        
        function set.trigNextStopEnable(obj,val)
            val = obj.validatePropArg('trigNextStopEnable',val);
            if obj.componentUpdateProperty('trigNextStopEnable',val)
                val = logical(val); % convert 'binaryflex' to 'logcial'
                val = obj.accessTrigNextStopEnablePreSet(val);
                obj.trigNextStopEnable = val;
            end
        end
        
        function set.trigStopEdge(obj,val)
            val = obj.validatePropArg('trigStopEdge',val);
            if obj.componentUpdateProperty('trigStopEdge',val)
                val = obj.accessTrigStopEdgePreSet(val);
                obj.trigStopEdge = val;
            end
        end
        
        function set.trigStopInTerm(obj,val)
            val = obj.validatePropArg('trigStopInTerm',val);
            %assert(isempty(val) || ismember(val,obj.trigStopInTermAllowed),'Not a valid trigger terminal for stop trigger: %s',val);
            if obj.componentUpdateProperty('trigStopInTerm',val)
                val = obj.accessFunctionTrigStopInTermPreSet(val);
                obj.trigStopInTerm = val;
            end
        end
        
        function set.scannerFrequency(obj,val)
            val = obj.validatePropArg('scannerFrequency',val);
            if obj.componentUpdateProperty('scannerFrequency',val)
                obj.scannerFrequency = val;
                obj.accessScannerFrequencyPostSet(val)
            end
        end

        %function set.logFilePath(obj,val)
        function val = get.logFilePath(obj)
            val = obj.staticLogFilePath;
            %obj.accessLogFilePathPostGet(val);
        end
        
        function val = get.scannerFrequency(obj)
            val = obj.scannerFrequency;
            val = obj.accessScannerFrequencyPostGet(val);
        end
        
        function set.maxSampleRate(obj,val)
            obj.mdlDummySetProp(val,'maxSampleRate');
        end
        
        function val = get.maxSampleRate(obj)
            val = obj.maxSampleRate;
            val = obj.accessMaxSampleRatePostGet(val);
        end
   
        
        function set.channelsAvailable(obj,val)
            obj.mdlDummySetProp(val,'channelsAvailable');
        end
        
        function val = get.channelsAvailable(obj)
            val = obj.channelsAvailable;
            val = obj.accessChannelsAvailablePostGet(val);
        end
        
        function set.channelsAvailableInputRanges(obj,val)
            obj.mdlDummySetProp(val,'channelsAvailableInputRanges');
        end
        
        function val = get.channelsAvailableInputRanges(obj)
            val = obj.channelsAvailableInputRanges;
            val = obj.accessChannelsAvailableInputRangesPostGet(val);
        end
        
        
        function val = get.trigAcqInTermAllowed(obj)
            val = obj.trigAcqInTermAllowed;
            val = obj.accessTrigAcqInTermAllowedPostGet(val);
        end

     
        function val = get.trigNextInTermAllowed(obj)
            val = obj.trigNextInTermAllowed;
            val = obj.accessTrigNextInTermAllowedPostGet(val);
        end
        
        function val = get.trigStopInTermAllowed(obj)
            val = obj.trigStopInTermAllowed;
            val = obj.accessTrigStopInTermAllowedPostGet(val);            
        end
        
        function val = get.trigFrameClkOutInternalTerm(obj)
            val = obj.trigFrameClkOutInternalTerm;
            val = obj.accessTrigFrameClkOutInternalTermPostGet(val);
        end
        
        function val = get.trigBeamClkOutInternalTerm(obj)
            val = obj.trigBeamClkOutInternalTerm;
            val = obj.accessTrigBeamClkOutInternalTermPostGet(val);
        end
        
        function val = get.trigAcqOutInternalTerm(obj)
            val = obj.trigAcqOutInternalTerm;
            val = obj.accessTrigAcqOutInternalTermPostGet(val);
        end        
        
        function val = get.trigReferenceClkOutInternalTerm(obj)
            val = obj.trigReferenceClkOutInternalTerm;
            val = obj.accessTrigReferenceClkOutInternalTermPostGet(val);
        end
        
        function val = get.trigReferenceClkOutInternalRate(obj)
            val = obj.trigReferenceClkOutInternalRate;
            val = obj.accessTrigReferenceClkOutInternalRatePostGet(val);
        end
        
        function val = get.trigReferenceClkInInternalTerm(obj)
            val = obj.trigReferenceClkInInternalTerm;
            val = obj.accessTrigReferenceClkInInternalTermPostGet(val);
        end
		
        function val = get.trigReferenceClkInInternalRate(obj)
            val = obj.trigReferenceClkInInternalRate;
            val = obj.accessTrigReferenceClkInInternalRatePostGet(val);
        end
        
        function set.scanPixelTimeMean(obj,val)
            obj.mdlDummySetProp(val,'scanPixelTimeMean');
        end
        
        function val = get.scanPixelTimeMean(obj)
            val = obj.scanPixelTimeMean;
            val = obj.accessScanPixelTimeMeanPostGet(val);
        end
        
        function set.scanPixelTimeMaxMinRatio(obj,val)
            obj.mdlDummySetProp(val,'scanPixelTimeMaxMinRatio');
        end
        
        function val = get.scanPixelTimeMaxMinRatio(obj)
            val = obj.scanPixelTimeMaxMinRatio;
            val = obj.accessScanPixelTimeMaxMinRatioPostGet(val);
        end
        
        function set.channelsAdcResolution(obj,val)
            obj.mdlDummySetProp(val,'channelsAdcResolution');
        end
        
        function val = get.channelsAdcResolution(obj)
            val = obj.channelsAdcResolution;
            val = obj.accessChannelsAdcResolutionPostGet(val);
        end
        
        function set.channelsDataType(obj,val)
            obj.mdlDummySetProp(val,'channelsDataType');
        end
        
        function val = get.channelsDataType(obj)
            val = obj.channelsDataType;
            val = obj.accessChannelsDataTypePostGet(val);
        end
        
        function set.scannerToRefTransform(obj, v)
            if scanimage.mroi.util.isTransformPerspective(v)
                most.idioms.warn('Ignoring perspective matrix entries in scanfield constraints.');
            end
            
            if obj.componentUpdateProperty('scannerToRefTransform',v) || ~obj.cdInit
                v = obj.validatePropArg('scannerToRefTransform',v);
                v = obj.accessScannerToRefTransformPreSet(v);
                obj.scannerToRefTransform = v;
                
                if obj.cdInit && obj.mdlInitialized
                    obj.setClassDataVar('scannerToRefTransform',v,obj.classDataFileName);
                end
            end
        end
        
        function val = get.currentRoiGroup(obj)
            val = obj.hSI.hRoiManager.currentRoiGroup;
        end
        
        function val = get.nominalFovCornerPoints(obj)
            a = obj.angularRange/2;
            val = [-a; a.*[1 -1]; a; a.*[-1 1]];
        end
        
        function val = get.fovCornerPoints(obj)
            val = scanimage.mroi.util.xformPoints(obj.nominalFovCornerPoints,obj.scannerToRefTransform);
        end
        
        function set.channelsSubtractOffsets(obj,val)
            val = obj.validatePropArg('channelsSubtractOffsets',val);
            val = logical(val);
            
            if numel(val) < obj.channelsAvailable
                val(end+1:obj.channelsAvailable) = val(end);
            elseif numel(val) > obj.channelsAvailable
                val(obj.channelsAvailable+1:end) = [];
            end
            
            obj.channelsSubtractOffsets = val;
            obj.accessChannelsSubtractOffsetsPostSet();
        end
        
        function set.hDataScope(obj,val)
            if ~isempty(val)
                assert(isa(val,'scanimage.components.scan2d.interfaces.DataScope'),'Not a valid scanimage.components.scan2d.interfaces.DataScope');
                assert(isscalar(val),'Not a valid scanimage.components.scan2d.interfaces.DataScope');
                assert(most.idioms.isValidObj(val),'Not a valid scanimage.components.scan2d.interfaces.DataScope');
            end
            
            obj.hDataScope = val;
        end
    end
    
    %%% AccessXXX API for subclasses.
    % Allows this parent class to define part of logic, while delegating portions of logic to subclasses
    methods (Abstract, Hidden, Access = protected)
        %TODO: Alphabetize/group/etc        
        val = accessScannersetPostGet(obj,val);
        
        accessBeamClockDelayPostSet(obj,val);
        
        accessBeamClockExtendPostSet(obj,val);
        
        accessBidirectionalPostSet(obj,val);
        accessStripingEnablePreSet(obj,val);
        
        val = accessChannelsFilterPostGet(obj,val);
        val = accessChannelsFilterPreSet(obj,val);
        
        %accessChannelsAcquirePostSet(obj,val);
        
        val = accessChannelsAdcResolutionPostGet(obj,val);
        
        val = accessChannelsAvailablePostGet(obj,val);
        
        val = accessChannelsAvailableInputRangesPostGet(obj,val);
        
        val = accessChannelsDataTypePostGet(obj,val);
        
        val = accessChannelsInputRangesPreSet(obj,val);
        val = accessChannelsInputRangesPostGet(obj,val);
        
        val = accessFillFractionSpatialPreSet(obj,val);
        accessFillFractionSpatialPostSet(obj,val);      
        accessSettleTimeFractionPostSet(obj,val);
		
        val = accessFlytoTimePerScanfieldPostGet(obj,val);
        
        val = accessFlybackTimePerFramePostGet(obj,val);
        
        val = accessFunctionTrigStopInTermPreSet(obj,val);
        
        accessScannerFrequencyPostSet(obj,val);
        val = accessScannerFrequencyPostGet(obj,val);
        
        val = accessLinePhasePreSet(obj,val);
        val = accessLinePhasePostSet(obj,val);
        val = accessLinePhasePostGet(obj,val);
                
        val = accessLogAverageFactorPostSet(obj,val);
        
        val = accessLogFileCounterPostSet(obj,val);
        
        val = accessLogFilePathPostSet(obj,val);
        
        val = accessLogFileStemPostSet(obj,val);
        
        val = accessLogFramesPerFilePostSet(obj,val);
        
        val = accessLogFramesPerFileLockPostSet(obj,val);
        
        val = accessLogNumSlicesPreSet(obj,val);
        
        val = accessMaxSampleRatePostGet(obj,val);
        
        val = accessScanPixelTimeMeanPostGet(obj,val);
        
        val = accessScanPixelTimeMaxMinRatioPostGet(obj,val);
        
        val = accessTrigAcqEdgePreSet(obj,val);
        accessTrigAcqEdgePostSet(obj,val);
        
        val = accessTrigAcqInTermPreSet(obj,val);
        accessTrigAcqInTermPostSet(obj,val);
        
        val = accessTrigAcqTypeExternalPreSet(obj,val);
        accessTrigAcqTypeExternalPostSet(obj,val);
        
        val = accessTrigNextEdgePreSet(obj,val);
        
        val = accessTrigNextInTermPreSet(obj,val);
        
        val = accessTrigNextStopEnablePreSet(obj,val);
        
        val = accessTrigStopEdgePreSet(obj,val);
        
        val = accessTrigFrameClkOutInternalTermPostGet(obj,val);
        val = accessTrigBeamClkOutInternalTermPostGet(obj,val);
        val = accessTrigAcqOutInternalTermPostGet(obj,val);
        val = accessTrigReferenceClkOutInternalTermPostGet(obj,val);
        val = accessTrigReferenceClkOutInternalRatePostGet(obj,val);
        val = accessTrigReferenceClkInInternalTermPostGet(obj,val);
        val = accessTrigReferenceClkInInternalRatePostGet(obj,val);
        
        val = accessTrigAcqInTermAllowedPostGet(obj,val);
        val = accessTrigNextInTermAllowedPostGet(obj,val);
        val = accessTrigStopInTermAllowedPostGet(obj,val);
        
        val = accessScannerToRefTransformPreSet(obj,val);
        
        accessChannelsSubtractOffsetsPostSet(obj);
    end
    
    
    %% USER METHODS
    methods (Abstract)
        centerScanner(obj);                    % centers the galvos and resonant scanner by setting the output voltage to zero
        pointScanner(obj,fastDeg,slowDeg)      % points the XY scanner to a position (units: degree)
        parkScanner(obj);                      % parks the scanner, deactivates resonant scanner
        
        trigIssueSoftwareAcq(obj);             % issue software acquisition trigger
        trigIssueSoftwareNext(obj);            % issue software next file marker
        trigIssueSoftwareStop(obj);            % issue software acquisition stop trigger
    end
    
    
    methods
        function offsets = measureChannelOffsets(obj,numSamples,verbose)
            %  measureChannelOffsets    measurses the dark offset for all channels
            %
            %   offsets = obj.measureChannelOffsets()   acquires 100 samples for each channel and averages them
            %   offsets = obj.measureChannelOffsets(numSamples) acquires numSamples for each channel and averages them
            %   offsets = obj.measureChannelOffsets(numSamples,verbose) acquires numSamples for each channel and averages them; if
            %                                                           verbose == true, status messages are output in the command window
            %
            %   returns
            %       offsets  numeric array with dark offsets for all channels
            
            if nargin < 2 || isempty(numSamples)
                numSamples = 100;
            end
            if nargin < 3 || isempty(verbose)
                verbose = false;
            end
            
            validateattributes(numSamples,{'numeric'},{'positive','integer','scalar','finite'});
            
            if obj.componentExecuteFunction('measureChannelOffsets',numSamples)
                if verbose
                    fprintf('Measuring channels offsets. Averaging %d samples...\n',numSamples);
                end
                dataPoints = double(obj.acquireSamples(numSamples));
                offsets = mean(dataPoints,1);
                obj.channelOffsets = cast(offsets,obj.channelsDataType);
                if verbose
                    fprintf('Done!\n');
                end
            end
        end
    end
    
    
    %% FRIEND METHODS
    methods (Abstract, Hidden)
        arm(obj);
        signalReadyReceiveData(obj);                % signal Scan2D that caller is ready to receive data (has to be called after processing a batch)
        [success,stripeData] = readStripeData(obj); % returns stripeData of class scanimage.interfaces.StripeData
        data = acquireSamples(obj,numSamples);      % returns an 1D array of current values for all input channels
        reinitRoutes(obj);                          % reset DAQ boards and restore trigger routes
        deinitRoutes(obj);                          % clear trigger routes
        val = calibrateLinePhase(obj,chanIdx)       % automatically finds the best setting for linePhase at the current zoom level
        updateLiveValues(obj,regenAO);              % request an update of the task ao
        updateSliceAO(obj);                         % request an update of ao for next slice
    end
    
    methods (Hidden)
        function val = constraints(obj)
            val = obj.accessScannersetPostGet().CONSTRAINTS;
        end
        
        % Acq update
        function val = getNextFileCounter(obj)
            % search for files in current path that have same filestem,
            % then get filecounter value + 1
            fileList = dir([obj.logFullFilename '*']);
            fileNames = {fileList.name};
            logFileStem_ = regexptranslate('escape',obj.logFileStem);
            match = regexpi(fileNames,sprintf('(?<=^%s[^0-9a-zA-Z]?)[0-9]+',logFileStem_),'match','once');
            
            tfempty = strcmp(match,''); % filter non-matches
            match(tfempty) = [];
            
            if isempty(match)
                val = 1;
            else
                match = strjoin(match,' ');
                nums = sscanf(match,'%d'); % faster than str2double
                val = max(nums)+1;
            end
        end
    end
    
    %% INTERNAL METHODS
    %%% ABSTRACT HELPER METHODS
    methods (Abstract, Access = protected)
        fillFracTemp = fillFracSpatToTemp(obj,val)
        fillFracSpat = fillFracTempToSpat(obj,val)
    end
    
    %%% Subclass Helper methods
    methods (Hidden, Access = protected)
        function errorPropertyUnSupported(obj,propName,val,accessType)
            if nargin < 4 || isempty(accessType)
                accessType = 'setget';
            end
            
            if obj.mdlInitialized && ~obj.mdlApplyingPropSet && ~isempty(val) && (isscalar(val) && ~isnan(val)) % checking just for nan is insufficient, since val can be empty or a matrix. in this case && will cause an error
                switch accessType
                    case 'setget'
                        error('Property ''%s'' not supported for scanner type ''%s''',propName,obj.scannerType);
                    case 'set'
                        error('Property ''%s'' cannot be set for scanner type ''%s''',propName,obj.scannerType);
                    otherwise
                        error('errorPropertyUnSupported: Unsupported accessType: ''%s''',accessType);
                end
            end
        end
        
        function valCoercedWarning(~,propName,requestedVal,actualVal)
            if requestedVal ~= actualVal
                warning('Coercing property %s value to the nearest possible value. Requested: %d Actual: %d', ...
                    propName, requestedVal, actualVal);
            end
        end
        
        function safeAbortDataScope(obj)
            try
                if ~isempty(obj.hDataScope) && most.idioms.isValidObj(obj.hDataScope)
                    obj.hDataScope.abort();
                end
            catch ME
            end
        end
    end
    
    
    %% Property Attributes
    methods(Static)
        function s = scan2DPropAttributes()
            s = struct();
            
            % Live properties (changeable during an active acquisition)
            s.linePhase                 = struct('Classes','numeric','Attributes',{{'finite','scalar'}});
            
            % Acquisition parameters
            s.sampleRate              = struct('Classes','numeric','Attributes',{{'scalar','positive','finite'}});
            s.channelsSubtractOffsets = struct('Classes','binaryflex','Attributes',{{'vector'}});
            s.channelsAutoReadOffsets = struct('Classes','binaryflex','Attributes',{{'scalar'}});
            s.channelsInputRanges     = struct('Options','channelsAvailableInputRanges','List','fullVector');
            s.pixelBinFactor          = struct('Classes','numeric','Attributes',{{'integer','positive','finite','scalar'}});
            
            % Scanner parameters
            s.bidirectional         = struct('Classes','binaryflex','Attributes',{{'scalar'}});
            s.stripingEnable        = struct('Classes','binaryflex','Attributes',{{'scalar'}});
            s.flytoTimePerScanfield = struct('Classes','numeric','Attributes',{{'nonnegative','finite','scalar'}});
            s.flybackTimePerFrame   = struct('Classes','numeric','Attributes',{{'nonnegative','finite','scalar'}});
            s.fillFractionTemporal  = struct('Classes','numeric','Attributes',{{'scalar' 'positive' 'finite' '<' 1}},'DependsOn',{{'fillFractionSpatial'}});
            s.fillFractionSpatial   = struct('Classes','numeric','Attributes',{{'scalar' 'positive' 'finite' '<' 1}});
			s.settleTimeFraction    = struct('Classes','numeric','Attributes',{{'scalar' 'nonnegative' 'finite' '<=' 1}});
            
            % Trigger parameters
            s.trigAcqTypeExternal = struct('Classes','binaryflex','Attributes',{{'scalar'}});
            s.trigNextStopEnable  = struct('Classes','binaryflex','Attributes',{{'scalar'}});
            s.trigAcqInTerm       = struct('Classes','string','AllowEmpty',1);
            s.trigStopInTerm      = struct('Classes','string','AllowEmpty',1);
            s.trigNextInTerm      = struct('Classes','string','AllowEmpty',1);
            s.trigAcqEdge         = struct('Options',{{'falling';'rising'}},'AllowEmpty',0);
            s.trigNextEdge        = struct('Options',{{'falling';'rising'}},'AllowEmpty',0);
            s.trigStopEdge        = struct('Options',{{'falling';'rising'}},'AllowEmpty',0);
            
            % Logging parameters
            s.logFileStem       = struct('Classes','char','AllowEmpty',1);
            s.logFilePath       = struct('Classes','char','AllowEmpty',1);
            s.logAverageFactor  = struct('Classes','numeric','Attributes',{{'scalar','positive','integer'}});
            s.logFileCounter    = struct('Classes','numeric','Attributes',{{'finite','scalar','nonnegative','integer'}});
            s.logNumSlices      = struct('Classes','numeric','Attributes',{{'scalar','positive','integer'}});
            s.logFramesPerFile  = struct('Classes','numeric','Attributes',{{'scalar','positive'}});
            s.logFramesPerFileLock = struct('Classes','binaryflex');
            s.logAverageNumFrames = struct('Classes','numeric','Attributes',{{'scalar', 'positive', 'integer', 'finite'}});
            
            % Acquisition information
            s.scanPixelTimeMean        = struct('Classes','numeric','Attributes',{{'positive','finite','scalar'}},'DependsOn',{{'scannerset','hSI.hRoiManager.pixelsPerLine','sampleRate','scannerFrequency','fillFractionSpatial'}});
            s.scanPixelTimeMaxMinRatio = struct('Classes','numeric','Attributes',{{'positive','finite','scalar'}},'DependsOn',{{'scanPixelTimeMean'}});
            
            % Scanner information
            s.scannerFrequency        = struct('Classes','numeric','Attributes',{{'positive','finite','scalar'}});
            s.scannerToRefTransform   = struct('Classes','numeric','Attributes',{{'size',[3,3]}});
            
            % System information
            s.maxSampleRate           = struct('Classes','numeric','Attributes',{{'scalar','positive','finite'}});
            s.channelsAvailable       = struct('Classes','numeric','Attributes',{{'scalar','positive','finite'}});
            s.channelsAvailableInputRanges = struct('Classes','cell');
            s.channelsAdcResolution   = struct('Classes','numeric','Attributes',{{'scalar','positive','finite'}});
            s.channelsDataType        = struct('Classes','char');
            s.channelsFilter          = struct('Classes','string','AllowEmpty',1);
            
            s.beamClockDelay          = struct('Classes','numeric','Attributes',{{'scalar','finite'}});
            s.beamClockExtend         = struct('Classes','numeric','Attributes',{{'scalar','finite'}});
            
            % Shutter information
            s.shutterDelay = struct('Classes','numeric','Attributes',{{'nonnegative' 'scalar' 'finite'}});
            
            %programmer interface
            s.stripeAcquiredCallback = struct('Classes','function_handle');
            s.scannerset = struct('DependsOn',{{'sampleRate','bidirectional','scannerFrequency','flybackTimePerFrame','flytoTimePerScanfield','scannerToRefTransform','fillFractionSpatial'}});
        end

        function out = staticLogFilePath(in)
            persistent staticLogFilePath;
            if nargin > 0
                staticLogFilePath = in;
            end
            out = staticLogFilePath;
        end
    end
end


%--------------------------------------------------------------------------%
% Scan2D.m                                                                 %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
