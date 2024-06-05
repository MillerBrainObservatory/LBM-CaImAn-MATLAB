classdef FastZ < scanimage.interfaces.Component & most.HasMachineDataFile & most.HasClassDataFile
    %FastZ     Functionality to control volume acquisition through Fast-Z mode

    %% USER PROPS
    properties (SetObservable)
        enable = false;                 % Boolean, when true, FastZ is enabled.
        enableFieldCurveCorr = false;   % Boolean, when true use fast z to correct for scanner field curvature
        numVolumes=1;                   % Number of total FastZ volumes to capture for a given Acq.
        flybackTime = 0;                % Time, in seconds, for axial position/ramp to settle.
        volumePeriodAdjustment = -6e-4; % Time, in s, to add to the nominal volume period, when determining fastZ sawtooth period used for volume imaging
        actuatorLag = 0;                % Acquisition delay, in seconds, of fastZScanner.
        waveformType = 'sawtooth';      % Can be either 'waveform' or 'step'
        useArbitraryZs = false;         % In step/settle mode, use z's entered by user rather than num slices/steps per slice
        userZs = 0;                     % In step/settle mode, the arbitrary z series to use
        scannerBandwidth = 1000;        % [Hz] Bandwidth of the FastZ actuator
    end
    
    properties (SetObservable,SetAccess=?scanimage.interfaces.Class,Transient)
        volumesDone = 0;                % Integer, incremented every time a FastZ Volume is acquired. Only incremented when grabbing FastZ volumes. Excluded from frame header
    end
    
    properties (SetObservable,SetAccess=private)
        numFramesPerVolume;             % Number of frames per FastZ volume for current Acq & FastZ settings (includes flyback Frames)
        positionAbsolute;               % Used by parent object to get hAOTask.positionAbsolute
        hasFastZ = false;               % Indicates if the current imaging system has an associated fastz actuator
        nonblockingMoveInProgress;
    end
    
    properties (Dependent,Transient,SetObservable)
        positionTarget;                 % Used by parent object to get hAOTask.positionTarget
    end
    
    properties (Dependent,SetObservable)
        numDiscardFlybackFrames;        % Number of discarded frames for each period
        discardFlybackFrames;           % Logical indicating whether to discard frames during fastZ scanner flyback; leave this in for the moment to maintain support for openTiff
    end
    
    properties (Hidden,SetAccess=private,Transient)
        extFrameClockTerminal;          % String. External frame-clock terminal.
        homePosition;                   % Cache of the fastZ controller's position at start of acquisition mode, which should be restored at conclusion of acquisition mode
        volumePeriodAdjSamples;
        fastZCalibration;               % stores the calibration data
        scannerMapKeys = {};
        scannerMapIds = [];
        defaultScannerId = [];
    end
    
    %% INTERNAL PROPS
    properties (Hidden,SetAccess=private)
        extFrameClockTerminal_;
        extFrameClockImgSys_;
        
        hStages = scanimage.components.motors.StageController.empty;   %Handle to FastZ hardware, may be a LSC object or a PI motion controller
        hAOTasks = dabs.ni.daqmx.Task.empty;                            %Handle to DAQmx AO Task used for FastZ sweep/step control
        hScanners = scanimage.mroi.scanners.FastZ.empty;
        
        hStage = [];
        hAOTask = [];
        hScanner = [];
        
        bufferNeedsUpdateAsync = false;
        bufferUpdatingAsyncNow = false;
        
        classDataFileName;
        outputActive = false;
        sharingScannerDaq = false;
    end
    
    %%% ABSTRACT PROPERTY REALIZATIONS (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'FastZ';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
        
        mdfOptionalVars = struct( ...
            'fieldCurveZ0', 0, ...
            'fieldCurveRx0', 0, ...
            'fieldCurveRy0', 0, ...
            'fieldCurveZ1', 0, ...
            'fieldCurveRx1', 0, ...
            'fieldCurveRy1', 0 ...
            );
    end
    
    %%% ABSTRACT PROPERTY REALIZATION (most.Model)
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = ziniInitPropAttributes();
        mdlHeaderExcludeProps = {'volumesDone'}
    end
    
    %%% ABSTRACT PROPERTY REALIZATION (scanimage.interfaces.Component)
    properties (SetAccess = protected, Hidden)
        numInstances = 0;
    end
    
    properties (Constant, Hidden)
        COMPONENT_NAME = 'FastZ';                                       % [char array] short name describing functionality of component e.g. 'Beams' or 'FastZ'
        PROP_TRUE_LIVE_UPDATE = {};                                     % Cell array of strings specifying properties that can be set while the component is active
        PROP_FOCUS_TRUE_LIVE_UPDATE = {};                               % Cell array of strings specifying properties that can be set while focusing
        DENY_PROP_LIVE_UPDATE = {'enable','numVolumes'};                % Cell array of strings specifying properties for which a live update is denied (during acqState = Focus)
        FUNC_TRUE_LIVE_EXECUTION = {'setHome','resetHome',...           % Cell array of strings specifying functions that can be executed while the component is active
            'goPark','goHome'};
        FUNC_FOCUS_TRUE_LIVE_EXECUTION = {};                            % Cell array of strings specifying functions that can be executed while focusing
        DENY_FUNC_LIVE_EXECUTION = {};                                  % Cell array of strings specifying functions for which a live execution is denied (during acqState = Focus)
    end
    
    %% LIFECYCLE
    methods (Hidden)
        function obj = FastZ(hSI)
            obj = obj@scanimage.interfaces.Component(hSI,[]);
            
            if isfield(obj.mdfData,'fastZControllerType') || isempty([obj.mdfData.actuators.controllerType]);
                obj.mdfData.actuators = [];
                return;
            else
                obj.mdfData.actuators(arrayfun(@(s)isempty(s.controllerType),obj.mdfData.actuators)) = [];
            end
            
            % check for valid scanner mappings
            obj.defaultScannerId = find(arrayfun(@(s)isempty(s.affectedScanners),obj.mdfData.actuators));
            assert(numel(obj.defaultScannerId) < 2, 'Only one fast z scanner can apply to all scan systems');
            
            scannerAssignents = [obj.mdfData.actuators.affectedScanners];
            assert(numel(unique(scannerAssignents)) == numel(scannerAssignents), 'Each 2D scan system can only have one associated fast z scanner.');
            
            % Evaluate individual fastz mappings
            for i = 1:numel(obj.mdfData.actuators)
                params = obj.mdfData.actuators(i);
                obj.scannerMapKeys = [obj.scannerMapKeys params.affectedScanners];
                obj.scannerMapIds = [obj.scannerMapIds repmat(i,1,numel(params.affectedScanners))];
                
                obj.numInstances = obj.numInstances + 1;
            end
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.hStages);
            most.idioms.safeDeleteObj(obj.hAOTasks);
            most.idioms.safeDeleteObj(obj.hScanners);
        end
    end
    
    methods (Access = protected, Hidden)
        function mdlInitialize(obj)
            if isfield(obj.mdfData,'fastZControllerType')
                fprintf(2,'MDF settings for FastZ are outdated. Exit ScanImage and run the configuration editor to migrate the settings.\n');
                return;
            elseif isempty(obj.mdfData.actuators);
                fprintf('No FastZ actuators specified in Machine Data File. Feature disabled.\n');
                return;
            end
            
            % Initialize motor controller objects
            for i = 1:numel(obj.mdfData.actuators)
                params = obj.mdfData.actuators(i);
                params.dimensions = 'Z';
                
                znstInitFastZAO(params);
                znstInitFastZHardware(params);
                    
                if ~obj.hStages(i).lscErrPending
                    try
                        obj.goPark(i);
                    catch ME
                        most.idioms.warn(sprintf('Failed to park FastZ motor %d. Error:\n%s',i,ME.message));
                    end
                end
            end
            
            % Determine CDF name and path
            if isempty(obj.hSI.classDataDir)
                pth = most.util.className(class(obj),'classPrivatePath');
            else
                pth = obj.hSI.classDataDir;
            end
            classNameShort = most.util.className(class(obj),'classNameShort');
            obj.classDataFileName = fullfile(pth, [classNameShort '_classData.mat']);
            
            obj.loadClassData();
            
            mdlInitialize@scanimage.interfaces.Component(obj);
            
            % Nested functions
            function znstInitFastZHardware(params)
                obj.hStages(i) = scanimage.components.motors.StageController(params,true,sprintf('FastZ_%d',i));
                
                obj.hScanners(i) = scanimage.mroi.scanners.FastZ(obj.hStages(i).hLSC);
                obj.hScanners(i).waveformCacheBasePath = obj.hSI.hWaveformManager.waveformCacheBasePath;
                obj.hScanners(i).sampleRateHz = min(200000,obj.hAOTasks(i).get('sampClkMaxRate'));
                obj.hScanners(i).hDevice.positionMaxSampleRate = obj.hScanners(i).sampleRateHz;
                
                if isempty(params.optimizationFcn)
                    params.optimizationFcn = @scanimage.mroi.scanners.optimizationFunctions.proportionalOptimization;
                end
                obj.hScanners(i).optimizationFcn = params.optimizationFcn;
            end
            
            function znstInitFastZAO(params)
                obj.hAOTasks(i) = most.util.safeCreateTask(sprintf('FastZ_AO_%d',i));
                obj.hAOTasks(i).createAOVoltageChan(params.daqDeviceName,params.cmdOutputChanID);
                obj.hAOTasks(i).cfgSampClkTiming(min(200000,obj.hAOTasks(i).get('sampClkMaxRate')), 'DAQmx_Val_FiniteSamps');
                cfgSampClkTimebase(obj.hAOTasks(i));
            end
        end
    end
    
    %% PROP ACCESS
    methods
        function v = get.hScanner(obj)
            v = obj.hScanner;
            
            if ~isempty(v)
                prms = {'fieldCurveZ0' 'fieldCurveRx0' 'fieldCurveRy0' 'fieldCurveZ1' 'fieldCurveRx1' 'fieldCurveRy1'};
                for i = 1:numel(prms)
                    fieldCurveParams.(strrep(prms{i},'fieldCurve','')) = obj.mdfData.(prms{i});
                end
                
                v.flybackTime = obj.flybackTime;
                v.actuatorLag = obj.actuatorLag;
                v.enableFieldCurveCorr = obj.enableFieldCurveCorr;
                v.fieldCurveParams = fieldCurveParams;
            end
        end
        
        function set.enable(obj,val)
            val = obj.validatePropArg('enable',val);
            
            
            if obj.mdlInitialized
                id = obj.zScannerId();
                obj.hasFastZ = ~isempty(id);
                obj.hStage = obj.hStages(id);
                obj.hScanner = obj.hScanners(id);
                obj.hAOTask = obj.hAOTasks(id);
                
                val = val && obj.hasFastZ;
                
                if obj.componentUpdateProperty('enable',val)
                    obj.enable = val;
                    obj.hSI.hStackManager.updateZSeries();
                    
                    if val && ~obj.hSI.hRoiManager.isLineScan
                        obj.hSI.hStackManager.framesPerSlice = 1;
                    end
                end
            end
        end
        
        function set.numVolumes(obj,val)
            if ~isinf(val)
                val = obj.validatePropArg('numVolumes',val);
            else
                val = abs(val); % in case someone tried to set the value to -Inf
            end
            
            if obj.componentUpdateProperty('numVolumes',val) 
                obj.numVolumes = val;
            end
        end
        
        function val = get.numFramesPerVolume(obj)
            if obj.enable
            	val = obj.hSI.hStackManager.slicesPerAcq + obj.numDiscardFlybackFrames;
            else
                val = [];
            end
        end
        
        function val = get.positionAbsolute(obj)
            if ~isempty(obj.hStage)
                try
                    val = obj.hStage.positionAbsolute(1);
                catch ME
                    most.idioms.warn(ME.message);
                    val = NaN;
                end
            else
                val = NaN;
            end
        end
        
        function set.numDiscardFlybackFrames(obj,val)
            obj.mdlDummySetProp(val,'numDiscardFlybackFrames');
        end
        
        function val = get.numDiscardFlybackFrames(obj)
            if obj.enable && strcmp(obj.waveformType, 'sawtooth') && (obj.numVolumes > 1) && length(obj.hSI.hStackManager.zs) > 1
                %TODO: Tighten up these computations a bit to deal with edge cases
                %TODO: Could account for maximum slew rate as well, at least when 'velocity' property is available                
                
                aoOutputRate = obj.hScanner.sampleRateHz;
                settlingNumSamples = round(aoOutputRate * obj.flybackTime);
                frameNumSamples = aoOutputRate * obj.hSI.hRoiManager.scanFramePeriod;
                
                val = ceil(settlingNumSamples/frameNumSamples);
                
                if isinf(val) || isnan(val)
                    val = 0;
                end
            else
                val = 0;
            end
        end
        
        function set.discardFlybackFrames(obj,val)
            obj.mdlDummySetProp(val,'discardFlybackFrames');
        end
        
        function val = get.discardFlybackFrames(obj)
            val = obj.numDiscardFlybackFrames > 0;
        end
        
        function val = get.positionTarget(obj)
            if ~isempty(obj.hStage)
                try
                    val = obj.hStage.positionTarget(1);
                catch ME
                    if obj.hSI.mdlInitialized
                        most.idioms.warn(ME.message);
                        val = NaN;
                    else
                        val = 0;
                    end
                end
            else
                val = NaN;
            end
        end
        
        function set.positionTarget(obj,v)
            if obj.active && obj.enable
                fprintf(2,'Cannot set z position during active volume acquisition.\n');
                return;
            elseif obj.hSI.mdlInitialized
                p = [v nan nan];
                
                if obj.active && obj.enableFieldCurveCorr
                    obj.hStage.hLSC.changeRelativePositionTarget(p);
                    obj.hSI.hWaveformManager.updateWaveforms();
                    obj.liveUpdate();
                    obj.setHome(v);
                else
                    obj.hStage.moveCompleteAbsolute(p);
                end
            end
        end
        
        function set.actuatorLag(obj,val)
            if obj.componentUpdateProperty('actuatorLag',val)
                obj.actuatorLag = val;
            end
        end
        
        function set.flybackTime(obj,val)
            val = obj.validatePropArg('flybackTime',val);
            if obj.componentUpdateProperty('flybackTime',val)
                obj.flybackTime = val;
            end
        end
        
        function set.volumePeriodAdjustment(obj,val)
            if obj.componentUpdateProperty('volumePeriodAdjustment',val)
                obj.volumePeriodAdjustment = val;
            end
        end
        
        function set.waveformType(obj,val)
            if obj.componentUpdateProperty('waveformType',val)
                assert(ismember(val,{'sawtooth' 'step'}), 'Invalid selection for waveform tpye. Must be either ''sawtooth'' or ''step''.');
                obj.waveformType = val;
                obj.hSI.hStackManager.updateZSeries();
            end
        end
        
        function set.userZs(obj,v)
            if obj.componentUpdateProperty('userZs',v)
                if isempty(v)
                    v = 0;
                end
                obj.userZs = v;
                obj.hSI.hStackManager.updateZSeries();
            end
        end
        
        function set.useArbitraryZs(obj,v)
            if obj.componentUpdateProperty('useArbitraryZs',v)
                obj.useArbitraryZs = v;
                obj.hSI.hStackManager.updateZSeries();
            end
        end
        
        function val = get.extFrameClockTerminal(obj)
            % This routine configures the start trigger for hTask
            % it first tries to connect the start trigger to the internal
            % beamsclock output of Scan2D. If this route fails, it uses the
            % external trigger terminal configured in the MDF
            
            if (isempty(obj.extFrameClockTerminal_) || ~strcmp(obj.extFrameClockImgSys_,obj.hSI.imagingSystem))...
                    && ~isempty(obj.hAOTask)
                try
                    % Try internal routing
                    internalTrigTerm = obj.hSI.hScan2D.trigFrameClkOutInternalTerm;
                    obj.hAOTask.cfgDigEdgeStartTrig(internalTrigTerm);
                    obj.hAOTask.control('DAQmx_Val_Task_Reserve'); % if no internal route is available, this call will throw an error
                    obj.hAOTask.control('DAQmx_Val_Task_Unreserve');
                    
                    val = internalTrigTerm;
                    % fprintf('FastZ: internal trigger route found: %s\n',val);
                catch ME
                    % Error -89125 is expected: No registered trigger lines could be found between the devices in the route.
                    % Error -89139 is expected: There are no shared trigger lines between the two devices which are acceptable to both devices.
                    if isempty(strfind(ME.message, '-89125')) && isempty(strfind(ME.message, '-89139')) % filter error messages
                        rethrow(ME)
                    end
                    
                    % No internal route available - use MDF settings
                    val = obj.mdfData.actuators(obj.zScannerId).frameClockIn;
                    
					try
                        validateattributes(val,{'char'},{'vector'});
                    catch ME
                        fprintf(2,'FastZ cannot synchronize to scanning system. See error message below:\n\n');
                        rethrow(ME);
                    end
                end
                obj.extFrameClockTerminal_ = val;
                obj.extFrameClockImgSys_ = obj.hSI.imagingSystem;
                
            else
                val = obj.extFrameClockTerminal_;
            end
        end
        
        function set.scannerBandwidth(obj,val)
            val = obj.validatePropArg('scannerBandwidth',val);
            
            if obj.componentUpdateProperty('scannerBandwidth',val)
                if most.idioms.isValidObj(obj.hScanner)
                    obj.hScanner.bandwidth = val;
                end
            end
        end
        
        function val = get.scannerBandwidth(obj)
            if most.idioms.isValidObj(obj.hScanner)
                val = obj.hScanner.bandwidth;
            else
                val = 1000;
            end
        end
        
        function set.fastZCalibration(obj,~)
            obj.setClassDataVar('fastZCalibration',obj.fastZCalibration,obj.classDataFileName);
        end
        
        function val = get.fastZCalibration(obj)
            if ~isempty(obj.hScanner)
                val = struct('fastZScanner',obj.hScanner.calibrationData);
            else
                val = [];
            end
        end
        
        function v = get.nonblockingMoveInProgress(obj)
            v = obj.hasFastZ && obj.hStage.nonblockingMovePending;
        end
        
        function v = get.outputActive(obj)
            v = (obj.enable && (obj.hSI.hStackManager.isFastZ || obj.hSI.hRoiManager.isLineScan)) || obj.enableFieldCurveCorr;
        end
    end
    
    %% USER METHODS
    methods
        function setHome(obj,val)
            %   Set homePosition.
            if nargin < 2 || isempty(val)
                val = obj.positionTarget;
            end
            
            if obj.componentExecuteFunction('setHome',val)
                %set homePosition.
                obj.homePosition = val;
            end
        end
        
        function resetHome(obj)
        %   Reset fastZ positions
            if obj.componentExecuteFunction('resetHome')
                %Reset fastZ positions
                obj.homePosition = [];
            end
        end
        
        function goHome(obj)
        %   Goes to 'Home' fastZ position
            if obj.componentExecuteFunction('goHome')
                %Go to home fastZ position, as applicable
                if ~isempty(obj.homePosition)
                    obj.goTo(obj.homePosition);
                end
            end
        end
        
        function goPark(obj,i)
            if nargin < 2
                i = obj.zScannerId;
            end
            
            if obj.componentExecuteFunction('goPark',i)
                obj.goTo(0,i);
            end
        end
        
        function [toutput,desWvfm,cmdWvfm,tinput,respWvfm] = testActuator(obj)
            % TESTACTUATOR  Perform a test motion of the z-actuator
            %   [toutput,desWvfm,cmdWvfm,tinput,respWvfm] = obj.testActuator
            %
            % Performs a test motion of the z-actuator and collects position
            % feedback.  Typically this is displayed to the user so that they
            % can tune the actuator control.
            %
            % OUTPUTS
            %   toutput    Times of analog output samples (seconds)
            %   desWvfm    Desired waveform (tuning off)
            %   cmdWvfm    Command waveform (tuning on)
            %   tinput     Times of analog intput samples (seconds)
            %   respWvfm   Response waveform

            % TODO(doc): units on outputs
            assert(obj.numInstances > 0);
            assert(~obj.active, 'Cannot run test during active acquisition.');
            
            hWb = waitbar(0,'Preparing Waveform and DAQs...','CreateCancelBtn',@(src,evt)delete(ancestor(src,'figure')));
            obj.setHome();
            try
                %% prepare waveform
                zPowerReference = obj.hSI.hStackManager.zPowerReference;
                zs = obj.hSI.hStackManager.zs;
                fb = obj.hSI.hFastZ.numDiscardFlybackFrames;
                wvType = obj.hSI.hFastZ.waveformType;
                scannerSet = obj.hSI.hScan2D.scannerset;
                [toutput, desWvfm, cmdWvfm] = scannerSet.zWvfm(obj.hSI.hScan2D.currentRoiGroup,zPowerReference,zs,fb,wvType);
                ao = obj.hScanner.position2Volts(cmdWvfm);
                sLen = length(ao);
                testWvfm = repmat(ao,5,1);
                
                %% execute waveform test
                aoOutputRate = obj.hScanner.sampleRateHz;
                assert(most.idioms.isValidObj(hWb),'Waveform test cancelled by user');
                data = obj.hScanner.hDevice.testWaveformVolts(testWvfm,aoOutputRate,[],[],[],hWb);
                waitbar(100,hWb,'Analyzing data...');
                obj.goHome();
                
                %% parse and scale data
                sT = sLen/aoOutputRate;
                sN = ceil(sT*aoOutputRate);
                
                respWvfm = obj.hScanner.hDevice.volts2Position(data(1+sN*3:sN*4));
                tinput = (1:sN)'/aoOutputRate;
                delete(hWb)
            catch ME
                delete(hWb);
                obj.goHome();
                ME.rethrow
            end
        end
        
        function calibrateFastZ(obj,silent)
            if nargin < 2 || isempty(silent)
                silent = false;
            end
            
            if isempty(obj.hScanner) || ~isvalid(obj.hScanner)
                most.idioms.warn('FastZ is not initialized');
                return
            end
            
            if ~silent
                button = questdlg(sprintf('The FastZ actuator is going to move over its entire range.\nDo you want to continue?'));
                if ~strcmpi(button,'Yes')
                    fprintf('FastZ calibration cancelled by user.\n');
                    return
                end
            end
            
            hWb = waitbar(0,'Calibrating FastZ');
            try
                obj.hScanner.hDevice.calibrate();
                obj.fastZCalibration = []; % dummy set to store calibration
                waitbar(1,hWb);
            catch ME
                most.idioms.safeDeleteObj(hWb);
                rethrow(ME);
            end
            most.idioms.safeDeleteObj(hWb);
        end
    end
    
    %% FRIEND METHODS
    methods (Hidden)
        function hScanner = scanner(obj,name)
            if nargin < 2
                name = obj.hSI.imagingSystem;
            end
            
            hScanner = [];
            [tf, idx] = ismember(name,obj.scannerMapKeys);
            
            if tf || ~isempty(obj.defaultScannerId)
                if tf
                    zScannerID = obj.scannerMapIds(idx);
                else
                    zScannerID = obj.defaultScannerId;
                end
                
                if ~obj.hStages(zScannerID).lscErrPending
                    hScanner = obj.hScanners(zScannerID);
                    hScanner.hDevice = obj.hStages(zScannerID).hLSC;
                    
                    prms = {'fieldCurveZ0' 'fieldCurveRx0' 'fieldCurveRy0' 'fieldCurveZ1' 'fieldCurveRx1' 'fieldCurveRy1'};
                    for i = 1:numel(prms)
                        fieldCurveParams.(strrep(prms{i},'fieldCurve','')) = obj.mdfData.(prms{i});
                    end
                    
                    hScanner.flybackTime = obj.flybackTime;
                    hScanner.actuatorLag = obj.actuatorLag;
                    hScanner.enableFieldCurveCorr = obj.enableFieldCurveCorr;
                    hScanner.fieldCurveParams = fieldCurveParams;
                end
            end
        end
        
        function id = zScannerId(obj,name)
            if nargin < 2
                name = obj.hSI.imagingSystem;
            end
            
            [tf, idx] = ismember(name,obj.scannerMapKeys);
            if tf
                id = obj.scannerMapIds(idx);
            else
                id = obj.defaultScannerId;
            end
        end
        
        function moveToNextSlice(obj, pos)
            obj.hAOTask.abort();
            obj.hAOTask.control('DAQmx_Val_Task_Unreserve');
            obj.hStage.moveStartRelative([pos NaN NaN]);
        end
        
        function updateSliceAO(obj)
            % normally fast z is not active during a slow stack but if
            % field curvature correction is enabled it is.
            if obj.enableFieldCurveCorr
                % task might be running. stop it
                obj.hAOTask.abort();
                obj.hAOTask.control('DAQmx_Val_Task_Unreserve');
                
                % go to the actual start position
                ao = obj.getAO();
                aos = obj.hStage.hLSC.analogCmdVoltage2Posn(ao(1));
                obj.hStage.moveStartRelative([aos NaN NaN]);
                
                % update ao for next slice and start task
                obj.hAOTask.writeAnalogData(ao);
                obj.hAOTask.start();
            end
        end
        
        function liveUpdate(obj)
            if obj.numInstances && obj.active && obj.enableFieldCurveCorr
                if obj.sharingScannerDaq
                    obj.hSI.hScan2D.updateLiveValues(false);
                else
                    if obj.bufferUpdatingAsyncNow
                        % async call currently in progress. schedule update after current update finishes
                        obj.bufferNeedsUpdateAsync = true;
                    else
                        obj.bufferNeedsUpdateAsync = false;
                        
                        if ~obj.hScanner.simulated
                            obj.bufferUpdatingAsyncNow = true;
                            
                            [ao, ~] = getAO(obj);
                            obj.hAOTask.writeAnalogDataAsync(ao,[],[],[],@(src,evt)obj.updateBufferAsyncCallback(src,evt));
                        end
                    end
                end
            end
        end
        
        function updateBufferAsyncCallback(obj,~,evt)
            obj.bufferUpdatingAsyncNow = false;
            
            if evt.status ~= 0 && evt.status ~= 200015 && obj.active
                fprintf(2,'Error updating fastZ buffer: %s\n%s\n',evt.errorString,evt.extendedErrorInfo);
            end

            if obj.bufferNeedsUpdateAsync
                obj.liveUpdate();
            end
        end
        
        function [ao, samplesPerTrigger] = getAO(obj)
            ao = obj.hSI.hWaveformManager.scannerAO.ao_volts.Z;
            if obj.volumePeriodAdjSamples > 0
                ao(end+1:end+obj.volumePeriodAdjSamples) = ao(end);
            elseif obj.volumePeriodAdjSamples < 0
                ao(end+obj.volumePeriodAdjSamples) = ao(end);
                ao(end+obj.volumePeriodAdjSamples+1:end) = [];
            end
            samplesPerTrigger = obj.hSI.hWaveformManager.scannerAO.ao_samplesPerTrigger.Z + obj.volumePeriodAdjSamples;
        end
        
        function tf = isActiveFastZMtr(obj, hMtr)
            tf = obj.numInstances && obj.active && (obj.enable || obj.enableFieldCurveCorr) && (hMtr == obj.hStage);
        end
        
        function tf = hasFieldCurveCorrection(obj)
            tf =  (obj.mdfData.fieldCurveRx0 ~= 0) || (obj.mdfData.fieldCurveRy0 ~= 0) || ...
               (obj.mdfData.fieldCurveRx1 ~= 0) || (obj.mdfData.fieldCurveRy1 ~= 0);
        end
    end
    
    %% INTERNAL METHODS
    methods (Hidden)
        function goTo(obj,v,i)
            if nargin > 2
                hDev = obj.hStages(i);
            else
                hDev = obj.hStage;
            end
            
            hDev.moveCompleteAbsolute([v nan nan]);
        end
        
        function updateTaskConfiguration(obj)
            assert(~isempty(obj.hSI.hWaveformManager.scannerAO.ao_volts(1).Z));
            
            obj.volumePeriodAdjSamples = floor(obj.hScanner.sampleRateHz * obj.volumePeriodAdjustment);

            %Update AO Buffer
            [ao, N] = obj.getAO();
            obj.hAOTask.control('DAQmx_Val_Task_Unreserve'); %Flush any previous data in the buffer
            obj.hAOTask.cfgDigEdgeStartTrig(obj.extFrameClockTerminal, 'DAQmx_Val_Rising');
            obj.hAOTask.cfgSampClkTiming(obj.hScanner.sampleRateHz, 'DAQmx_Val_FiniteSamps', N);
            cfgSampClkTimebase(obj.hAOTask);
            
            obj.hAOTask.cfgOutputBuffer(N);
            obj.hAOTask.set('startTrigRetriggerable',true);
            if ~obj.hScanner.simulated
                obj.hAOTask.writeAnalogData(ao);
            end
            obj.hAOTask.control('DAQmx_Val_Task_Verify'); %%% Verify Task Configuration (mostly for trigger routing
        end
        
        function loadClassData(obj)
        end
    end
    
    %%% ABSTRACT METHOD Implementation (scanimage.interfaces.Component)
    methods (Hidden, Access = protected)
        function componentStart(obj)
        %   Runs code that starts with the global acquisition-start command
            if obj.outputActive
                obj.setHome();
                
                if strcmp(obj.waveformType, 'step')
                    obj.goTo(obj.hSI.hStackManager.fZs(1));
                end
                
                obj.sharingScannerDaq = isa(obj.hSI.hScan2D, 'scanimage.components.scan2d.LinScan') && strcmp(obj.hSI.hScan2D.mdfData.deviceNameGalvo,obj.hSI.hFastZ.hScanner.positionDeviceName);
                
                if ~obj.sharingScannerDaq
                    obj.updateTaskConfiguration();
                    
                    if ~obj.hScanner.simulated
                        obj.hAOTask.start();
                    end
                end
            end
        end
        
        function componentAbort(obj)
        %   Runs code that aborts with the global acquisition-abort command
            if obj.enable || obj.enableFieldCurveCorr && ~isempty(obj.hAOTask)
                obj.hAOTask.abort();
                obj.hAOTask.control('DAQmx_Val_Task_Unreserve');
                obj.bufferNeedsUpdateAsync = false;
                obj.bufferUpdatingAsyncNow = false;
                
                obj.goHome();
            end
        end
    end
end

%% LOCAL
function s = ziniInitPropAttributes()
    s = struct;
    s.volumesDone = struct('Classes','numeric','Attributes',{{'positive' 'integer' 'finite'}});
    s.enable = struct('Classes','binaryflex','Attributes','scalar');
    s.numVolumes = struct('Classes','numeric','Attributes',{{'positive' 'integer'}});
    s.numDiscardFlybackFrames = struct('DependsOn',{{'enable' 'numVolumes' 'hSI.scan2DGrabProps' 'hSI.hStackManager.slicesPerAcq' 'actuatorLag' 'flybackTime' 'hSI.hRoiManager.scanFrameRate' 'waveformType'}});
    s.discardFlybackFrames = struct('DependsOn',{{'numDiscardFlybackFrames'}});
    s.volumePeriodAdjustment = struct('Range',[-5e-3 5e-3]);
    s.flybackTime = struct('Attributes',{{'nonnegative', '<=', 1}});
    s.actuatorLag = struct('Attributes',{{'nonnegative', '<=', 1}});
    s.userZs = struct('Classes','numeric','Attributes',{{'vector' 'finite'}});
    s.scannerBandwidth = struct('Classes','numeric','Attributes',{{'scalar','positive'}});
end
        
function cfgSampClkTimebase(hTask)
    deviceName = hTask.deviceNames{1}; % to get the capitalization right
    switch get(dabs.ni.daqmx.Device(deviceName),'busType')
        case {'DAQmx_Val_PXI','DAQmx_Val_PXIe'}
            set(hTask,'sampClkTimebaseSrc',['/' deviceName '/PXI_Clk10']);
            set(hTask,'sampClkTimebaseRate',10e6);
        otherwise
            % No-Op
    end
end


%--------------------------------------------------------------------------%
% FastZ.m                                                                  %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
