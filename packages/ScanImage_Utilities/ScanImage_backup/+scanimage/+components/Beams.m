classdef Beams < scanimage.interfaces.Component & most.HasMachineDataFile
    %% Beams Component
    % Manages properties and functionality related to beam power modulation.

    %% USER PROPS
    properties (SetObservable)
        flybackBlanking = true;     % [Logical] Indicates whether to blank beam outside of fill fraction and during galvo flyback
        interlaceDecimation = 1;    % [Numeric] 1xN array indicating for each beam that beam should only be on every n'th line
        interlaceOffset = 0;        % [Numeric] 1xN array indicating for each beam the offset line to start interlace
        
        stackStartPower=nan;        % [Numeric] 1xN array indicating for each beam the power at the start of the stack
        stackEndPower=nan;          % [Numeric] 1xN array indicating for each beam the power at the end of the stack
        stackUseStartPower=false;   % [Logical] Indicates that the setting in stackStartPower should be used at the start of the stack instead of the currently set power level
        stackUserOverrideLz=false;  % [Logical] Override the set length constant with a value computed using the start and end power and depth
        
        powers = 10;                % [Numeric] 1xN array containing power values for each beam
        powerLimits = 100;          % [Numeric] 1xN array containing power limit for each beam
        pzAdjust = false;           % [Logical] 1xN array indicating whether power/z adjustment is enabled for each beam
        lengthConstants = inf;      % [Numeric] 1xN array containing length constant for each beam, to use for power adjustment during Z stacks
        
        enablePowerBox = false;     % [Logical] Enables the power box feature
        powerBoxes = struct('rect', [.25 .25 .5 .5], 'powers', NaN, 'name', '','oddLines',true,'evenLines',true); % Array of structures containing parameters for each power box.
                                    % Contains the following fields:
                                    %  - rect:      [Numeric] 1x4 array indicating the left, top, width, and height of the power box expressed as fraction of the scanfield
                                    %  - powers:    [Numeric] 1xN array indicating the power for each laser within the box
                                    %  - name:      [string] a name for the power box for display purposes
                                    %  - oddLines:  [Logical] indicates if the box should be on for even scan lines
                                    %  - evenLines: [Logical] indicates if the box should be on for odd scan lines
                                    
        powerBoxStartFrame = 1;     % [Numeric] Specifies what frame the power box should turn on at
        powerBoxEndFrame = inf;     % [Numeric] Specifies what frame the power box should turn off at
        
        pzCustom = {[]};            % Variable Cell Array with num elements = num beams. Element type indicates how power depth adjustment is handled for that beam.
    end
    
    properties (SetObservable, Transient)
        directMode  = false;        % [Logical] Enables laser output immediately to the set power, even when image acuisition is inactive
    end
    
    properties (SetObservable, SetAccess=private, Transient)
        beamStatus;                 % [Numeric] Indicates current power transmission for each beam
        beamCalibratedStatus;       % [Logical] Indicates for each beam if it was calibrated successfully
    end
    
    %% FRIEND PROPS
    properties (Hidden, SetObservable)
        voltageRanges;          % Nbeam x 1 numeric. Maximum voltage for each beam.
        externalBeamDAQReq = repmat(struct('src',[],'daq',[]),1,0);
    end
    
    %% INTERNAL PROPS
    properties (Hidden,SetAccess=?most.Model,Dependent)
        stackStartEndPointsDefined;
        stackStartEndPowersDefined;                 %logical; if true, stackZStartPower, stackZEndPower are defined
        hasPowerBoxes;
    end
    
    %Fudge-factors
    properties (Hidden,SetAccess=private)
        calibrationLUTSize = 1e3;                   %number of steps in calibration LUT
        calibrationNumVoltageSteps = 100;           %number of beam voltage steps to use (during beam calibration)
        calibrationNumPasses = 5;                   %number of voltage sweeps to perform
        calibrationIntercalibrationZeros = 4;       %number of zero voltage samples to apply between calibration sweeps
        calibrationOutputRate = 1e5;                %output sample rate of beam/beamCal tasks during calibration
        calibrationIntercalibrationPauseTime = 0.2; %(seconds) pause time between calibration sweeps
        calibrationOffsetNumSamples = 1e4;          % Number of samples to take when measuring calibration offset
        calibrationNoisyOffsetThreshold = 0.15;     %Warning thrown if stddev/mean > (this ratio) while measuring photodiode offset
        calibrationFluctuationThreshold = 0.35;     %(dimensionless) warn if the std_dev/max of the beamCal signal exceeds this threshold
        calibrationMinThreshold = 0.15;             %(dimensionless) warn if min/max of the beamCal signal exceeds this threshold
    end
    
    properties (Hidden,SetAccess=private)
        hTask = {};
        hPark = {};                         %Task used for static power control adjustments
        hCals = {};                         %Array of AI Tasks for beam modulation calibration (e.g. with photodiodes)
        hDaqDevice;
        hRouteRegistry;                     %Handle to DAQmx route registry
        hCalibFig;                          %Handle to calibration figure
        flybackBlankData;                   %Array of beam output data for each scanner period for flyback blanking mode. Array has one column for each beam.
        flybackBlankDataMask;               %Mask representation of flybackBlankData, with 1 values representing beam ON and NaN representing beam OFF.
        calibrationLUT;                     %calibrationLUTSize x numBeams array. lut(i,j) gives the beam voltage necessary to achieve the fraction (i/calibrationLUTSize) of the maximum beam power for beam j.
        calibrationMinCalVoltage;           %1 x numBeams array. Gives the minimum beam calibration voltage encountered during calibration for each beam.
        calibrationMaxCalVoltage;           %1 x numBeams array. Gives the maximum beam calibration voltage encountered during calibration for each beam.
        calibrationMinAchievablePowerFrac;  %1 x numBeams array. Gives the minimum achievable power fraction for each beam
        cancelCalibration = false;          %Logical set/polled if user cancels during beam calibration.
        powersNominal;                      %Last-set values of beamPowers, which may be at higher precision than calibration-constrained beamPowers value
        internalSetFlag = false;            %Flag signifying that a public property set is happening internally, rather than by external class user
        sliceUpdateFlag = false;
        maxSampleRate;
        
        extLineClockTerminal_ = {};
        extFrameClockTerminal_ = {};
        extReferenceClock_ = {};
        lastScannerCfgd = {};
        
        daqNumBeams;                % array specifying the number of beams in each beam DAQ
        totalNumBeams = 0;          % array specifying the number of beams in each beam DAQ
        daqBeamIDs;                 % cell array containing the global indices of beams for a given beam DAQ
        globalID2Daq = [];          % array containing the DAQ ID for each beam by global ID
        globalID2DaqID = [];        % array containing the local ID on its DAQ for each beam by global ID
        activeBeamDaqID;            % ID of the DAQ currently being used for imaging
        sharingScannerDaq = false;  % indicates the active acquisition is using the galvo DAQ for beam output. Possible for linear scanning
    end
    
    properties (Hidden,SetObservable,SetAccess=private)
        acqPowersStackStart;        % Beam powers at last start of stack
        acqLengthConstants;         % Beam power length constants for use in actual acquistion; can differ from beamLengthConstants due to stackOverrideLz, etc
        displayNames;               % cell array containing display names for all beams
    end
    
    properties (Hidden,SetObservable,Dependent,SetAccess=?most.Model)
        stackStartPowerDefined;
        stackEndPowerDefined;
    end
    
    properties (Hidden,SetAccess=private)
        beamBufferUpdatingAsyncRetries = 0;
        beamBufferUpdatingAsyncNow = false;
        beamBufferNeedsUpdateAsync = false;
        beamBufferNeedsUpdateRegenerate = false;
    end
    
    properties (Hidden)
        streamingBuffer;
        aoSlices;
        nominalStreamingBufferTime = 1;
        streamingBufferFrames;
        streamingBufferSamples;
        frameSamps;
        samplesWritten;
        samplesGenerated;
        framesGenerated;
        framesWritten;
        nSampCbN;
    end
    
    %%% ABSTRACT PROPERTY REALIZATIONS (most.HasMachineDataFile)
    properties (Constant,Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'Beams';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
    end
    
    %%% ABSTRACT PROPERTY REALIZATION (most.Model)
    properties (Hidden,SetAccess=protected)
        mdlPropAttributes = ziniInitPropAttributes();
        mdlHeaderExcludeProps = {'beamStatus'};
    end
    
    %%% ABSTRACT PROPERTY REALIZATION (scanimage.interfaces.Component)
    properties (SetAccess = protected, Hidden)
        numInstances = 0;
    end
    
    properties (Constant, Hidden)
        COMPONENT_NAME = 'Beams';                       %[char array] short name describing functionality of component e.g. 'Beams' or 'FastZ'
        PROP_TRUE_LIVE_UPDATE = ...                     %Cell array of strings specifying properties that can be set while the component is active
            {'powers' 'directMode' 'flybackBlanking' 'interlaceDecimation' 'interlaceOffset' 'enablePowerBox' 'powerBoxes' 'powerBoxStartFrame' 'powerBoxEndFrame'};
        PROP_FOCUS_TRUE_LIVE_UPDATE = {};               % Cell array of strings specifying properties that can be set while focusing
        DENY_PROP_LIVE_UPDATE = {};                     %Cell array of strings specifying properties for which a live update is denied (during acqState = Focus)
        FUNC_TRUE_LIVE_EXECUTION = {'beamsOn','beamsOff','updateStaticBeams','beamsShowCalibrationCurve','beamComputeOverrideLzs'};         % Cell array of strings specifying functions that can be executed while the component is active
        FUNC_FOCUS_TRUE_LIVE_EXECUTION = {};            % Cell array of strings specifying functions that can be executed while focusing
        DENY_FUNC_LIVE_EXECUTION = {'beamsCalibrate','beamsMeasureCalOffset'};                  % Cell array of strings specifying functions for which a live execution is denied (during acqState = Focus)
    end
    
    %% LIFECYCLE
    methods (Hidden)
        function obj = Beams(hSI)
            obj = obj@scanimage.interfaces.Component(hSI,[]);
            import dabs.ni.daqmx.*
            obj.hRouteRegistry = dabs.ni.daqmx.util.triggerRouteRegistry();

            try
                tfBeamsFeatureOn = ~isempty(obj.mdfData.beamDaqDevices) && ...
                    ~isempty(horzcat(obj.mdfData.beamDaqs(:).chanIDs));
                
                if ~tfBeamsFeatureOn
                    obj.ziniDisableBeamsFeature();
                    fprintf(1,'No beams device or channels specified in Machine Data File. Feature disabled.\n');
                    return;
                end
                
                
                obj.zprvMDFVerify('beamDaqDevices',{},@(x)iscellstr(x));
                obj.numInstances = numel(obj.mdfData.beamDaqDevices);
                
                bmCtr = 1;
                
                for i = 1:obj.numInstances
                    daqData = obj.mdfData.beamDaqs(i);

                    % beamDaqDevices
                    obj.hDaqDevice{i} = dabs.ni.daqmx.Device(obj.mdfData.beamDaqDevices{i});
                   
                    % chanIDs
                    v = daqData.chanIDs;
                    zzVerifyValue('chanIDs',v,{{'numeric'},{'integer' 'vector' 'nonnegative'}},[]);
                    obj.daqNumBeams(i) = numel(v);
                    obj.daqBeamIDs{i} = bmCtr:(bmCtr + obj.daqNumBeams(i) - 1);
                    bmCtr = bmCtr + obj.daqNumBeams(i);
                    obj.globalID2Daq(end+1:end+obj.daqNumBeams(i)) = i;
                    obj.globalID2DaqID(end+1:end+obj.daqNumBeams(i)) = 1:obj.daqNumBeams(i);

                    % displayNames
                    if isempty(daqData.displayNames)
                        obj.displayNames = vertcat(obj.displayNames,arrayfun(@(x)sprintf('Beam %d',x),obj.daqBeamIDs{i},'UniformOutput',false));
                    else
                        obj.displayNames = vertcat(obj.displayNames,daqData.displayNames');
                    end
                    zzVerifyValue('displayNames',obj.displayNames(obj.daqBeamIDs{i}),{},@(x)iscellstr(x)&&numel(x)==obj.daqNumBeams(i));
                    
                    % voltageRanges
                    v = zzValueScalarExpand(daqData.voltageRanges,obj.daqNumBeams(i));
                    zzVerifyValue('voltageRanges',v,{{'numeric'},{'real' 'vector' '>=' 0.0}},@(x)numel(x)==obj.daqNumBeams(i));
                    obj.voltageRanges(obj.daqBeamIDs{i}) = v;
                    
                    % calInputChanIDs
                    if isempty(daqData.calInputChanIDs)
                        daqData.calInputChanIDs = nan(1,obj.daqNumBeams(i));
                    end
                    daqData.calInputChanIDs = zzValueScalarExpand(daqData.calInputChanIDs,obj.daqNumBeams(i));
                    zzVerifyValue('calInputChanIDs',daqData.calInputChanIDs,{{'numeric'},{'vector'}},@(x)numel(x)==obj.daqNumBeams(i));

                    % calOffsets
                    if isempty(daqData.calOffsets)
                        daqData.calOffsets = zeros(1,obj.daqNumBeams(i));
                    end
                    zzVerifyValue('calOffsets',daqData.calOffsets,{{'numeric'},{'vector'}},@(x)numel(x)==obj.daqNumBeams(i));

                    % calUseRejectedLight
                    daqData.calUseRejectedLight = zzValueScalarExpand(daqData.calUseRejectedLight,obj.daqNumBeams(i));
                    zzVerifyValue('calUseRejectedLight',daqData.calUseRejectedLight,{{'numeric' 'logical'},{'binary' 'vector'}},@(x)numel(x)==obj.daqNumBeams(i));

                    % calOpenShutterIDs
                    zzVerifyValue('calOpenShutterIDs',daqData.calOpenShutterIDs,{{'numeric'},{'positive'}},[]);


                    % create Beam/BeamCal/BeamPark Tasks
                    obj.hTask{i} = most.util.safeCreateTask(sprintf('Beam DAQ %d Modulation',i));
                    obj.hPark{i} = most.util.safeCreateTask(sprintf('Beam DAQ %d Modulation Park',i));
                    
                    %make props exist
                    get(obj.hTask{i}, 'writeRelativeTo');
                    get(obj.hTask{i}, 'writeOffset');
                    
                    for j=1:obj.daqNumBeams(i)
                        idString = obj.displayNames{obj.daqBeamIDs{i}(j)};

                        %Create AO chan for beam 'parking' (static AO control)
                        obj.hPark{i}.createAOVoltageChan(obj.hDaqDevice{i}.deviceName,daqData.chanIDs(j),sprintf('%s Park',idString));

                        %Create AO chans for beam
                        obj.hTask{i}.createAOVoltageChan(obj.hDaqDevice{i}.deviceName,daqData.chanIDs(j),idString);
                        
                        %Create AI tasks for beam calibration
                        calChanID = daqData.calInputChanIDs(j);
                        if isnan(calChanID)
                            obj.hCals{end+1} = [];
                        else
                            obj.hCals{end+1} = most.util.safeCreateTask([idString ' Calibration']);
                            obj.hCals{end}.createAIVoltageChan(obj.hDaqDevice{i}.deviceName,calChanID);
                            obj.hCals{end}.set('readReadAllAvailSamp',1); %Paradoxically, this is required for X series AI Tasks to correctly switch between finite acquisitions of varying duration
                        end
                    end
                    
                    supportedSampleRate = scanimage.util.daqTaskGetMaxSampleRate(obj.hTask{i},obj.daqNumBeams(i));
                    obj.hTask{i}.cfgSampClkTiming(supportedSampleRate,'DAQmx_Val_FiniteSamps');
                    obj.maxSampleRate(i) = obj.hTask{i}.sampClkRate; % read back actual sample rate
                    
                    obj.mdfData.beamDaqs(i) = daqData;
                end
                
                obj.totalNumBeams = sum(obj.daqNumBeams);
                obj.beamStatus = nan(1,obj.totalNumBeams);
                obj.beamCalibratedStatus = false(1,obj.totalNumBeams);
                
                obj.calibrationLUT = nan(obj.calibrationLUTSize,obj.totalNumBeams);
                obj.calibrationMinCalVoltage = nan(1,obj.totalNumBeams);
                obj.calibrationMaxCalVoltage = nan(1,obj.totalNumBeams);
                obj.calibrationMinAchievablePowerFrac = zeros(1,obj.totalNumBeams);
                obj.pzAdjust = zeros(1,obj.totalNumBeams);
                obj.directMode = zeros(1,obj.totalNumBeams);
                obj.powers = ones(1,obj.totalNumBeams);
                obj.interlaceDecimation = ones(1,obj.totalNumBeams);
                obj.interlaceOffset = zeros(1,obj.totalNumBeams);
                obj.extLineClockTerminal_ = cell(1,obj.numInstances);
                obj.extFrameClockTerminal_ = cell(1,obj.numInstances);
                obj.extReferenceClock_ = cell(1,obj.numInstances);
                obj.lastScannerCfgd = cell(1,obj.numInstances);
                
                obj.pzCustom = repmat(obj.pzCustom, 1, obj.totalNumBeams);
            catch ME
                most.idioms.dispError('Error occurred while initializing ''beams''. Incorrect MachineDataFile settings likely cause. Error stack:\n');
                most.idioms.reportError(ME);
                most.idioms.dispError('Disabling beams feature.\n');
                obj.ziniDisableBeamsFeature();
            end
            
            function zzVerifyValue(mdfVarName,val,validAttribArgs,assertFcn)
                try
                    if ~isempty(validAttribArgs)
                        validateattributes(val,validAttribArgs{:});
                    end
                    if ~isempty(assertFcn)
                        assert(assertFcn(val));
                    end
                catch ME
                    error('SI:MDFVerify','Invalid value for MachineDataFile variable ''%s''.',mdfVarName);
                end
            end
            
            function v = zzValueScalarExpand(v,N)
                if isscalar(v)
                    v = repmat(v,1,N);
                end
            end
        end
        
        function delete(obj)
            obj.ziniDeleteTasks();
            most.idioms.safeDeleteObj(obj.hRouteRegistry);
            most.idioms.safeDeleteObj(obj.hCalibFig);
        end
    end
    
    %% PROP ACCESS
    %%% Ancillary methods for Getter/Setter methods
    methods
        function val = get.acqLengthConstants(obj)
            lc = inf(obj.totalNumBeams,1);
            lc(logical(obj.pzAdjust)) = obj.lengthConstants(logical(obj.pzAdjust));

            if obj.stackUserOverrideLz && obj.stackStartEndPointsDefined && obj.stackStartEndPowersDefined && ~obj.hSI.hFastZ.enable
                lc = obj.beamComputeOverrideLzs(false);
            end
            
            val = lc;
        end
        
        function set.stackStartPower(obj,val)
            % TODO: Property validation
            if obj.componentUpdateProperty('stackStartPower',val)
                val = obj.zprpBeamScalarExpandPropValue(val,'stackStartPower');
                obj.stackStartPower = val;
            end
        end
        
        function set.stackEndPower(obj,val)
            % TODO: Property validation
            if obj.componentUpdateProperty('stackEndPower',val)
                val = obj.zprpBeamScalarExpandPropValue(val,'stackEndPower');
                obj.stackEndPower = val;
            end
        end
        
        function v = get.stackStartEndPointsDefined(obj)
            v = (~isnan(obj.hSI.hStackManager.stackZStartPos) && ~isnan(obj.hSI.hStackManager.stackZEndPos));
        end
        
        function v = get.stackStartPowerDefined(obj)
            v = true;
            for beamIndex = 1:obj.numInstances
                v = v && (~isnan(obj.stackStartPower(beamIndex)));
            end
        end
        
        function v = get.stackEndPowerDefined(obj)
            v = true;
            for beamIndex = 1:obj.numInstances
                v = v && (~isnan(obj.stackEndPower(beamIndex)));
            end
        end
        
        function set.stackUseStartPower(obj,val)
            val = obj.validatePropArg('stackUseStartPower',val);
            if obj.componentUpdateProperty('stackUseStartPower',val)
                obj.stackUseStartPower = val;
            end
        end
        
        function v = get.stackStartEndPowersDefined(obj)
            %TODO: this is beam-idxed
            %Ed: Initially, the model has been to use the number of
            %elements in the stackstartpower and stackendpower values to
            %determine the number of beams. This is problematic if there
            %are no beams because ~isnan of an empty array is an empty
            %array, and performing the logical && for two empty arrays
            %results in an error in matlab.
            %
            %So first check to see if obj.stackStartPower and
            %obj.stackEndPower are defined.
            v = true;
            for beamIndex = 1:obj.numInstances
                v = v && (~isnan(obj.stackStartPower(beamIndex)) && ~isnan(obj.stackEndPower(beamIndex)));
            end
        end
        
        function set.directMode(obj,val)
            val = logical(obj.validatePropArg('directMode',val));
            if obj.componentUpdateProperty('directMode',val)
                obj.directMode = val;
                obj.updateStaticBeams();
            end
        end
        
        function set.interlaceDecimation(obj,val)
            val = obj.validatePropArg('interlaceDecimation',val);
            if obj.componentUpdateProperty('interlaceDecimation',val)
                val = obj.zprpBeamScalarExpandPropValue(val,'interlaceDecimation');
                obj.interlaceDecimation = val;
                if obj.hSI.active
                    obj.updateBeamBufferAsync(true);
                end
            end
        end
        
        function set.interlaceOffset(obj,val)
            val = obj.validatePropArg('interlaceOffset',val);
            if obj.componentUpdateProperty('interlaceOffset',val)
                val = obj.zprpBeamScalarExpandPropValue(val,'interlaceOffset');
                obj.interlaceOffset = val;
                if obj.hSI.active
                    obj.updateBeamBufferAsync(true);
                end
            end
        end
        
        function set.flybackBlanking(obj,val)
            val = obj.validatePropArg('flybackBlanking',val);
            if obj.componentUpdateProperty('flybackBlanking',val)
                obj.flybackBlanking = val;
                if obj.hSI.active
                    obj.updateBeamBufferAsync(true);
                end
            end
        end
        
        function set.lengthConstants(obj,val)
            val = obj.validatePropArg('lengthConstants',val);
            if obj.componentUpdateProperty('lengthConstants',val)
                val = obj.zprpBeamScalarExpandPropValue(val,'lengthConstants');
                obj.lengthConstants = val;
            end
        end
         
        function set.powers(obj,val)
            val = obj.validatePropArg('powers',val);
            if obj.internalSetFlag || obj.componentUpdateProperty('powers',val)
                %TODO: SI4 code was checking for acq state of hLSM object, but acqState var should hold this data regardless.
                val = obj.zprpBeamScalarExpandPropValue(val,'powers');
                
                %Set nominal and resolution-constrained value
                val = obj.zprvBeamEnforcePowerLimits(val);
                obj.powersNominal = val;
                
                factor = obj.calibrationLUTSize/100;
                val = max(round(factor*val),1)/factor; %Only allow precision to 0.1
                
                obj.powers = val;
                
                %Side effects
                
                % handle imaging live update
                if ~obj.hSI.active || strcmpi(obj.hSI.acqState,'point')
                    % handle direct mode
                    obj.updateStaticBeams();
                else
                    if ~obj.sliceUpdateFlag
                        obj.updateBeamBufferAsync(true);
                    end
                end
            end
        end
        
        function set.powerLimits(obj,val)
            val = obj.validatePropArg('powerLimits',val);
            if obj.componentUpdateProperty('powerLimits',val)
                val = obj.zprpBeamScalarExpandPropValue(val,'powerLimits');
                
                validateattributes(val,{'numeric'},{'>=',0,'<=',100});
                obj.powerLimits = val;
                
                %Side-effects
                obj.powers = obj.zprvBeamEnforcePowerLimits(obj.powers);
            end
        end
        
        function set.stackUserOverrideLz(obj,val)
            val = obj.validatePropArg('stackUserOverrideLz',val);
            if obj.componentUpdateProperty('stackUserOverrideLz',val)
                obj.stackUserOverrideLz = val;
                if val && ~obj.stackUseStartPower
                    warning('SI:stackUserOverrideLzWithoutStackUseStartPower',...
                        'StackUseStartPower is currently false.');
                end
                
                %Side effects
                obj.stackUserOverrideLz = val;
            end
        end
        
        function set.pzAdjust(obj,val)
            val = obj.validatePropArg('pzAdjust',val);
            if obj.componentUpdateProperty('pzAdjust',val)
                val = obj.zprpBeamScalarExpandPropValue(val,'pzAdjust');
                obj.pzAdjust = logical(val);
            end
        end
        
        function set.enablePowerBox(obj,val)
            val = obj.validatePropArg('enablePowerBox',val);
            if obj.componentUpdateProperty('enablePowerBox',val)
                obj.enablePowerBox = logical(val);
                
                if obj.hSI.active
                    if obj.enablePowerBox && ~obj.streamingBuffer && ((obj.powerBoxStartFrame > 1) || (~isinf(obj.powerBoxEndFrame)))
                        most.idioms.warn('Cannot change to a time varying power box mid-acquisition. Power box will be always on');
                    end
                    obj.updateBeamBufferAsync(true);
                end
            end
        end
        
        function set.powerBoxes(obj,val)
            assert(all(isfield(val, {'rect' 'powers'})), 'Invalid powerbox format.');
            if ~isfield(val, 'oddLines')
                val = arrayfun(@(s)setfield(s,'oddLines',true),val);
            end
            if ~isfield(val, 'evenLines')
                val = arrayfun(@(s)setfield(s,'evenLines',true),val);
            end
            
            for i = 1:numel(val)                
                val(i).powers = obj.zprpBeamScalarExpandPropValue(val(i).powers,'powerBoxes.powers');
                if length(val(i).rect) ~= 4;
                    most.idioms.dispError('WARNING: Powerbox rect has to be defined by 4 points');
                    return
                end
                
                if any(val(i).rect(3:4)<0)
                    most.idioms.dispError('WARNING: Powerbox rect width and height needs to be positive');
                    return
                end
                
                r = min(1,max(0,[val(i).rect([1 2]) val(i).rect([3 4])+val(i).rect([1 2])]));
                val(i).rect = [r([1 2]) r([3 4])-r([1 2])];
            end
            
            powers_ = vertcat(val.powers);
            if any(powers_(:)<0) || any(powers_(:)>100)
                most.idioms.dispError('WARNING: Powerbox power values have to lie between 0 and 100%%');
                return
            end
            
            if obj.componentUpdateProperty('powerBoxes',val)
                obj.powerBoxes = val;
                if obj.hSI.active
                    obj.updateBeamBufferAsync(true);
                end
            end
        end
        
        function set.powerBoxStartFrame(obj,val)
            val = obj.validatePropArg('powerBoxStartFrame',val);
            if obj.componentUpdateProperty('powerBoxStartFrame',val)
                obj.powerBoxStartFrame = val;
                if obj.hSI.active
                    if obj.enablePowerBox && ~obj.streamingBuffer && ((obj.powerBoxStartFrame > 1) || (~isinf(obj.powerBoxEndFrame)))
                        most.idioms.warn('Cannot change to a time varying power box mid-acquisition. Power box will be always on');
                    end
                    obj.updateBeamBufferAsync(true);
                end
            end
        end
        
        function set.powerBoxEndFrame(obj,val)
            val = obj.validatePropArg('powerBoxEndFrame',val);
            if obj.componentUpdateProperty('powerBoxEndFrame',val)
                obj.powerBoxEndFrame = val;
                if obj.hSI.active
                    if obj.enablePowerBox && ~obj.streamingBuffer && ((obj.powerBoxStartFrame > 1) || (~isinf(obj.powerBoxEndFrame)))
                        most.idioms.warn('Cannot change to a time varying power box mid-acquisition. Power box will be always on');
                    end
                    obj.updateBeamBufferAsync(true);
                end
            end
        end
        
        function v = get.hasPowerBoxes(obj)
            v = obj.enablePowerBox && numel(obj.powerBoxes);
        end
         
        function set.pzCustom(obj,val)
            % add validation here
            obj.pzCustom = val;
        end
    end
    
    %% USER METHODS
    methods 
        function beamsShowCalibrationCurve(obj,beamIdx)
            % hSI.hBeams.beamsShowCalibrationCurve(beamIdx)
            %
            % Plots the calibration curve for the beam indicated by beamIdx
            %
            % Arguments
            %  - beamIdx: [Numeric] Beam to plot
            
            if obj.componentExecuteFunction('beamsShowCalibrationCurve',beamIdx)
                validateattributes(beamIdx,{'numeric'},{'scalar','integer','>=',1,'<=',obj.totalNumBeams});
                chart_title = sprintf('Look Up Table (%s)', obj.displayNames{beamIdx});
                
                most.idioms.safeDeleteObj(obj.hCalibFig)
                obj.hCalibFig = figure('NumberTitle','off','DoubleBuffer','On','Name',chart_title,'Color','White');
          
                a = axes('Parent',obj.hCalibFig);
                plot(obj.calibrationLUT(:,beamIdx),(1:obj.calibrationLUTSize)'/obj.calibrationLUTSize*100,...
                    'Marker','o','MarkerSize',2,'LineStyle','none','Parent',a,...
                    'MarkerFaceColor',[0 0 0],'color',[0 0 0]);
                title(chart_title,'FontSize',12,'FontWeight','Bold','Parent',a);
                ylabel('Percent of Maximum Power','Parent',a,'FontWeight','bold');
                xlabel('Modulation Voltage [V]','Parent',a,'FontWeight','bold');
                
                axisRange = axis;
                lblXPos = axisRange(1) + (axisRange(2)-axisRange(1))/3;
                lblYPos = axisRange(3) + (axisRange(4)-axisRange(3))*92/100;
                minCalV = obj.calibrationMinCalVoltage(beamIdx);
                maxCalV = obj.calibrationMaxCalVoltage(beamIdx);
                
                extRatio = maxCalV/minCalV;
                if extRatio > 1000
                    extRatio = '>1000';
                end
                
                calOffset = obj.mdfData.beamDaqs(obj.globalID2Daq(beamIdx)).calOffsets(obj.globalID2DaqID(beamIdx));
                zlclAddQuantityAnnotations(a,lblXPos,lblYPos,...
                    {'Cal. Offset';'Min Cal. Voltage';'Max Cal. Voltage';'Max Extinction Ratio'},...
                    {calOffset;minCalV;maxCalV;extRatio},'FontWeight','bold','FontSize',9);
                % TODO are these figHandles going somewhere
            end
        end
        
        function beamsCalibrate(obj,beamIDs,showShutterWarning)
            % hSI.hBeams.beamsCalibrate(beamIDs,showShutterWarning)
            %
            % Run calibration of beam modulation device. Sets the properties calibrationLUT, and beamCalibrationMin/MaxCalVoltage for beamIdx'th beam.
            % Note: This is the only safe way to set any of these three properties.
            %
            % Arguments
            %  - beamIDs:            [Numeric] 1xN array of beams to calibrate
            %  - showShutterWarning: [Numeric] set to false to suppress warning about shutters that need to open for calibration. Note: this will allow shutters to open without warning!
            
            if nargin < 2 || isempty(beamIDs)
                beamIDs = 1:obj.totalNumBeams;
            end
            
            if nargin < 3 || isempty(showShutterWarning)
                showShutterWarning = true;
            end
            
            if obj.componentExecuteFunction('beamsCalibrate',beamIDs,showShutterWarning)
                validateattributes(beamIDs,{'numeric'},{'vector','integer','>=',1,'<=',obj.totalNumBeams});
                openShutter = ~showShutterWarning;
                
                for i = unique(obj.globalID2Daq(beamIDs))
                    % Global IDs of beams to cal on DAQ i
                    globalIDs = beamIDs(obj.globalID2Daq(beamIDs) == i);
                    
                    try
                        if ~isempty(obj.mdfData.beamDaqs(i).calOpenShutterIDs) && ~isempty(obj.hCals{i})
                            for bIdx = globalIDs
                                obj.beamsMeasureCalOffset(bIdx,true);
                            end
                            
                            if showShutterWarning
                                answ = questdlg('Warning: Specified shutters will open for pockels calibration.','Beam Calibration','OK','Cancel','OK');
                                openShutter = strcmp(answ, 'OK');
                                showShutterWarning = false;
                            end
                            
                            if openShutter
                                obj.hSI.hShutters.shuttersTransition(obj.mdfData.beamDaqs(i).calOpenShutterIDs, true);
                            else
                                most.idioms.dispError('Unable to collect beam calibration data for beam DAQ %d. Using naive calibration for all beams on beam DAQ %d.\n',i,i);
                                
                                for bIdx = globalIDs
                                    localID = obj.globalID2DaqID(bIdx);
                                    rejectedLight = obj.mdfData.beamDaqs(i).calUseRejectedLight(localID);
                                    beamVoltage = obj.zprvBeamCalGetNaiveBeamVoltage(bIdx);
                                    [lut,beamCalMinVoltage,beamCalMaxVoltage] = obj.zprvBeamsPerformNaiveCalibration(beamVoltage,rejectedLight);
                                    obj.zprvBeamsSetCalibrationInfo(bIdx,lut,beamCalMinVoltage,beamCalMaxVoltage);
                                end
                                
                                continue;
                            end
                        end
                        
                        for bIdx = globalIDs
                            localID = obj.globalID2DaqID(bIdx);
                            
                            rejectedLight = obj.mdfData.beamDaqs(i).calUseRejectedLight(localID);
                            [tfSuccess,beamCalVoltage,beamVoltage] = obj.zprvBeamsGetCalibrationData(bIdx);
                            
                            if tfSuccess
                                if isempty(beamCalVoltage) %No calibration chan for this beam
                                    [lut,beamCalMinVoltage,beamCalMaxVoltage] = ...
                                        obj.zprvBeamsPerformNaiveCalibration(beamVoltage,rejectedLight);
                                        tfSuccess = false;
                                else
                                    [lut,beamCalMinVoltage,beamCalMaxVoltage,tfSuccess] = ...
                                        obj.zprvBeamsProcessCalibrationData(beamVoltage,beamCalVoltage,obj.mdfData.beamDaqs(i).calOffsets(localID),rejectedLight,bIdx);
                                end
                            else
                                most.idioms.dispError('WARNING: Unable to collect beam calibration data for ''%s''. Using naive calibration.\n',obj.displayNames{bIdx});
                                [lut,beamCalMinVoltage,beamCalMaxVoltage] = ...
                                    obj.zprvBeamsPerformNaiveCalibration(beamVoltage,rejectedLight);
                            end
                            
                            %Update beam calibration properties
                            obj.zprvBeamsSetCalibrationInfo(bIdx,lut,beamCalMinVoltage,beamCalMaxVoltage,tfSuccess);
                        end
                        
                        obj.hSI.hShutters.shuttersTransition([], false);
                    catch ME
                        obj.hSI.hShutters.shuttersTransition([], false);
                        rethrow(ME);
                    end
                end
            end
        end
        
        function beamsOn(obj,varargin)
            % hSI.hBeams.beamsOn(beamIDs)
            %
            % Immediately enables the selected beams to the set output power.
            %
            % Arguments
            %  - beamIDs: [Numeric] 1xN array of beams to enable
            
            if obj.componentExecuteFunction('beamsOn',varargin{:})
                if nargin < 2
                    % turn on all beams
                    beams = 1:obj.totalNumBeams;
                else
                    beams = varargin{1};
                end
                
                most.idioms.warn('Use direct mode to turn beams on while not scanning.');                
                
                for beamIdx = 1:obj.totalNumBeams
                    if ismember(beamIdx,beams)
                        beamPowerFracs(beamIdx) = obj.powers(beamIdx)./100;
                        beamPowerVoltages(beamIdx) = obj.zprpBeamsPowerFractionToVoltage(beamIdx,beamPowerFracs(beamIdx)/100);
                    else
                        beamPowerFracs(beamIdx) = 0;
                        beamPowerVoltages(beamIdx) = obj.zprpBeamsPowerFractionToVoltage(beamIdx,beamPowerFracs(beamIdx));
                    end
                end
                
                for i = 1:obj.numInstances
                    if (isempty(obj.activeBeamDaqID) || i ~= obj.activeBeamDaqID) && ~any([obj.externalBeamDAQReq.daq] == i)
                        obj.hTask{i}.abort();
                        obj.hTask{i}.control('DAQmx_Val_Task_Unreserve');
                        beamIDs = obj.daqBeamIDs{i};
                        voltages = beamPowerVoltages(beamIDs);
                        powerFracs = beamPowerFracs(beamIDs);
                        obj.updateBeamStatusFrac(beamIDs,NaN);
                        obj.hPark{i}.writeAnalogData(voltages);
                        obj.updateBeamStatusFrac(beamIDs,powerFracs); % just in case the following call throws an error
                    end
                end
            end
        end
        
        function updateBeamStatusFrac(obj,beamIDs,frac)
            if isempty(beamIDs)
                return
            end
            
            if nargin <  3 || isempty(frac)
                frac = ones(1,numel(beamIDs));
            end
            
            if isnan(frac)
                frac = repmat(frac,size(beamIDs));
            end
            
            assert(size(frac,2)==numel(beamIDs));
            
            frac = max(frac,[],1,'includenan');
            frac(frac>1) = 1;
            frac(frac<0) = 0;
            
            obj.beamStatus(beamIDs) = frac * 100;
        end
        
        function beamsOff(obj)
            % hSI.hBeams.beamsOff()
            %
            % Immediately disables output for all beams.
            
            if obj.componentExecuteFunction('beamsOff')
                if any(obj.directMode)
                    most.idioms.warn('Direct mode for one or more beams is on. Disable to prevent beams from turning back on.');
                end
                
                for i = 1:obj.numInstances
                    if (isempty(obj.activeBeamDaqID) || i ~= obj.activeBeamDaqID) && ~any([obj.externalBeamDAQReq.daq] == i)
                        obj.hTask{i}.abort();
                        obj.hTask{i}.control('DAQmx_Val_Task_Unreserve'); %should flush data
                        obj.updateBeamStatusFrac(obj.daqBeamIDs{i},NaN);
                        beamIDs = obj.daqBeamIDs{i};
                        obj.updateBeamStatusFrac(beamIDs,NaN);
                        obj.hPark{i}.writeAnalogData(obj.zprpBeamsPowerFractionToVoltage(beamIDs,zeros(1,numel(beamIDs))));
                        obj.updateBeamStatusFrac(beamIDs,0);
                    end
                end
            end
        end
        
        function offset = beamsMeasureCalOffset(obj,beamIdx,tfWriteToMDF)
            % hSI.hBeams.beamsMeasureCalOffset(beamIdx,tfWriteToMDF)
            %
            % Measures and updates stored offset value for beam calibration device (e.g. photodiode) to improve subsequent calibration accuracy.
            % This should be done when the laser is completely shuttered so that no laser light is reaching the calibration device.
            %
            % Arguments
            %  - beamIdx:      [Numeric] beams to measure offset for
            %  - tfWriteToMDF: [Logical] indicates if new value should be saved to machine data file
            %
            % Return values
            %  - offset:       [Numeric] Measured offset
            
            if nargin < 3 || isempty(tfWriteToMDF)
                tfWriteToMDF = false;
            end
            
            offset = NaN;
            
            if obj.componentExecuteFunction('beamsMeasureCalOffset',beamIdx,tfWriteToMDF)
                validateattributes(beamIdx,{'numeric'},{'scalar','integer','>=',1,'<=',obj.totalNumBeams});
                
                daqID = obj.globalID2Daq(beamIdx);
                localID = obj.globalID2DaqID(beamIdx);
                
                beamCalTask = obj.hCals{beamIdx};
                if isempty(beamCalTask)
                    most.idioms.dispError('WARNING: Unable to measure beam calibration offset for ''%s''. No calibration input channel defined in MDF. \n',obj.displayNames{beamIdx});
                    offset = NaN;
                    return
                end
                
                beamCalTask.control('DAQmx_Val_Task_Unreserve');
                beamCalTask.cfgSampClkTiming(obj.calibrationOutputRate,'DAQmx_Val_FiniteSamps',obj.calibrationOffsetNumSamples);
                beamCalTask.set('startTrigRetriggerable',false);
                beamCalTask.disableStartTrig();
                
                if ~isempty(obj.mdfData.beamDaqs(daqID).calOpenShutterIDs)
                    % shutter should probably already be off, but anyway
                    obj.hSI.hShutters.shuttersTransition([], false);
                else
                    uiwait(msgbox(sprintf('Turn off laser for ''%s''.',obj.displayNames{beamIdx}),'Alert','modal'));
                end
                
                beamCalTask.start;
                data = beamCalTask.readAnalogData(obj.calibrationOffsetNumSamples);
                beamCalTask.stop();
                
                offset = mean(data);
                sig = std(data);
                if sig/offset > obj.calibrationNoisyOffsetThreshold
                    most.idioms.warn(['Noisy photodiode offset measured for ''' obj.displayNames{beamIdx} '''.']);
                end
                
                assert(numel(obj.mdfData.beamDaqs(daqID).calOffsets)==obj.daqNumBeams(daqID));
                obj.mdfData.beamDaqs(daqID).calOffsets(localID) = offset;
                
                if tfWriteToMDF
                    mdf = most.MachineDataFile.getInstance();
                    if mdf.isLoaded
                        %Load all existing beam cal offsets from MDF file.
                        allOffsets = obj.mdfData.beamDaqs(daqID).calOffsets;
                        %No matter what the orientation of the existing beam
                        %cal offsets is, force into a 1xN matrix.
                        allOffsets = reshape(allOffsets,1,obj.daqNumBeams(daqID));
                        %Write back beam cal offsets into MDF file.
                        mdf.writeVarToHeading('Beams',sprintf('beamDaqs(%d).calOffsets',daqID),allOffsets);
                    end
                end
            end 
        end
        
        function acqLzs = beamComputeOverrideLzs(obj,verbose)
            % hSI.hBeams.beamComputeOverrideLzs(verbose)
            %
            % Calculates length constants for each beam based on the current settings for stack start and end power and depth.
            %
            % Arguments
            %  - verbose: [Logical] if true results are printed to the command window
            %
            % Return values
            %  - acqLzs:       [Numeric] 1xN array of length constants for each beam
            
            Nbeam = obj.totalNumBeams;
            beamLz = obj.lengthConstants;
            
            assert(~isnan(obj.hSI.hStackManager.stackZStartPos),'Stack start position must be set to compute override Lz''s.');
            assert(~isnan(obj.hSI.hStackManager.stackZEndPos),'Stack end position must be set to compute override Lz''s.');
            assert(isequal(numel(beamLz),numel(obj.stackEndPower),numel(obj.stackStartPower),Nbeam));
            
            dz = obj.hSI.hStackManager.stackZEndPos-obj.hSI.hStackManager.stackZStartPos;
            acqLzs = inf(Nbeam,1);
            
            for c = 1:Nbeam
                Pratio = obj.stackEndPower(c)/obj.stackStartPower(c);
                acqLzs(c) = dz/log(Pratio);
                
                if nargin < 2 || isempty(verbose) || verbose
                    fprintf(1,'Beam %d: Lz=%.2f\n',c,acqLzs(c));
                end
            end
        end
    end
    
    %% FRIEND METHODS
    methods (Hidden)
        function updateStaticBeams(obj)
            for beamIdx = 1:obj.totalNumBeams
                if obj.directMode(beamIdx)
                    beamPowerFracs(beamIdx) = obj.powers(beamIdx)/100;
                    beamPowerVoltages(beamIdx) = obj.zprpBeamsPowerFractionToVoltage(beamIdx,beamPowerFracs(beamIdx));
                else
                    beamPowerFracs(beamIdx) = 0;
                    beamPowerVoltages(beamIdx) = obj.zprpBeamsPowerFractionToVoltage(beamIdx,beamPowerFracs(beamIdx));
                end
            end
            
            for i = 1:obj.numInstances
                if (isempty(obj.activeBeamDaqID) || i ~= obj.activeBeamDaqID) && ~any([obj.externalBeamDAQReq.daq] == i)
                    obj.hTask{i}.abort();
                    obj.hTask{i}.control('DAQmx_Val_Task_Unreserve');
                    obj.hPark{i}.control('DAQmx_Val_Task_Unreserve');
                    obj.hPark{i}.writeAnalogData(beamPowerVoltages(obj.daqBeamIDs{i}));
                    obj.updateBeamStatusFrac(obj.daqBeamIDs{i},beamPowerFracs(obj.daqBeamIDs{i}))
                end
            end
        end
        
        function zprvResetHome(obj)
            %Reset home beam position
            obj.acqPowersStackStart = [];
        end
        
        function zprvSetHome(obj)
            %Cache home beam position
            obj.acqPowersStackStart = obj.powers;
        end
        
        function zprvGoHome(obj)
            %Go to home motor/fastZ/beam positions/powers, as applicable
            if ~isempty(obj.acqPowersStackStart)
                % obj.zprvSetInternal('powers', obj.acqPowersStackStart);
            end
        end
        
        function s = scanner(obj,daqId,sampleRate,linePhase,beamClockDelay,beamClockExtend)
            if obj.numInstances > 0 && ~isempty(daqId)
                if isempty(sampleRate)
                    sampleRate = obj.maxSampleRate(daqId);
                end
                
                if obj.enablePowerBox
                    pbxs =obj.powerBoxes;
                else
                    pbxs = [];
                end

                s = scanimage.mroi.scanners.Beams(obj.daqBeamIDs{daqId},...
                        sampleRate,...
                        obj.powers,...
                        obj.powerLimits,...
                        obj.flybackBlanking,...
                        obj.pzAdjust,...
                        obj.acqLengthConstants',...
                        obj.interlaceDecimation,...
                        obj.interlaceOffset,...
                        @(id,pf)obj.zprpBeamsPowerFractionToVoltage(id,pf),...
                        @obj.zprvBeamsDepthPowerCorrection,...
                        linePhase,...
                        beamClockDelay,...
                        beamClockExtend,...
                        pbxs);
            else
                s = [];
            end
        end
        
        function updateSliceAO(obj)
            if ~isempty(obj.activeBeamDaqID) && ~obj.sharingScannerDaq
                obj.sliceUpdateFlag = true;
                
                try
                    obj.hTask{obj.activeBeamDaqID}.abort();
                    
                    if any(obj.pzAdjust)
                        % dont need to regenerate the AO here!
                        zPowerReference = obj.hSI.hStackManager.zPowerReference;
                        slc = obj.hSI.hStackManager.slowStackSlicesDone + 1;
                        z = obj.hSI.hStackManager.zs(slc);
%                         obj.zprvBeamsDepthPowerCorrection(zPowerReference,z,obj.acqLengthConstants);
                    end
                    
                    % update the ao
                    obj.samplesGenerated = 0;
                    obj.samplesWritten = 0;
                    obj.framesGenerated = 0;
                    obj.framesWritten = 0;
                    obj.updateBeamBufferAsync(false, 3);
                    if ~obj.hSI.mdfData.simulated
                        obj.hTask{obj.activeBeamDaqID}.start();
                    end
                    obj.sliceUpdateFlag = false;
                catch ME
                    obj.sliceUpdateFlag = false;
                    ME.rethrow();
                end
            end
        end
        
        function updateBeamBufferAsync(obj, reGenerateAO, timeout)
            if nargin < 3 || isempty(timeout)
                timeout = nan;
            end
            
            if obj.sharingScannerDaq
                %hScan2D.updateLiveValues always updates AO so disregards
                %the reGenerateAO parameter
                obj.hSI.hScan2D.updateLiveValues();
            else
                if obj.beamBufferUpdatingAsyncNow
                    % async call currently in progress. schedule update after current update finishes
                    obj.beamBufferNeedsUpdateAsync = true;
                    obj.beamBufferNeedsUpdateRegenerate = obj.beamBufferNeedsUpdateRegenerate || reGenerateAO;
                else
                    if reGenerateAO
                        obj.hSI.hWaveformManager.updateWaveforms();
                    end

                    obj.beamBufferNeedsUpdateAsync = false;
                    obj.beamBufferNeedsUpdateRegenerate = false;
                    
                    if ~isempty(obj.activeBeamDaqID)
                        beamCfg = obj.hSI.hScan2D.scannerset.beamsTriggerCfg();
                        if strcmpi(beamCfg.triggerType,'static');
                            framesToWrite = 1;
                            aoVolts = obj.hSI.hWaveformManager.scannerAO.ao_volts.B;
                            pathFOV = obj.hSI.hWaveformManager.scannerAO.pathFOV.B;
                            
                            % all sample points have to be the same
                            assert(size(unique(aoVolts,'rows'),1)==1);
                            assert(size(unique(pathFOV,'rows'),1)==1);
                            
                            aoVolts = aoVolts(1,:);
                            pathFOV = pathFOV(1,:);
                            
                            bufsz = obj.streamingBufferSamples; % make sure we write data for the entire buffer
                            aoVolts = repmat(aoVolts,bufsz,1); % can't write a single point to the output buffer
                        elseif obj.streamingBuffer
                            framesToWrite = obj.streamingBufferFrames + obj.framesGenerated - obj.framesWritten;
                            startFrame = obj.framesWritten + 1;
                            
                            obj.hTask{obj.activeBeamDaqID}.writeRelativeTo = 'DAQmx_Val_CurrWritePos';
                            obj.hTask{obj.activeBeamDaqID}.writeOffset = 0;
                            if framesToWrite > 0
                                [aoVolts,pathFOV] = obj.calcStreamingBuffer(startFrame, framesToWrite);
                            end
                        else
                            framesToWrite = 1;
                            obj.hTask{obj.activeBeamDaqID}.writeRelativeTo = 'DAQmx_Val_FirstSample';
                            obj.hTask{obj.activeBeamDaqID}.writeOffset = 0;
                            
                            if obj.hasPowerBoxes
                                aoVolts = obj.hSI.hWaveformManager.scannerAO.ao_volts.Bpb;
                                pathFOV = obj.hSI.hWaveformManager.scannerAO.pathFOV.Bpb;
                            else
                                aoVolts = obj.hSI.hWaveformManager.scannerAO.ao_volts.B;
                                pathFOV = obj.hSI.hWaveformManager.scannerAO.pathFOV.B;
                            end
                        end
                        
                        if framesToWrite > 0
                            beamIDs = obj.daqBeamIDs{obj.activeBeamDaqID};
                            obj.updateBeamStatusFrac(beamIDs,NaN);
                            if ~obj.hSI.mdfData.simulated
                                obj.beamBufferUpdatingAsyncNow = true;
                                obj.hTask{obj.activeBeamDaqID}.writeAnalogDataAsync(aoVolts,[],[],[],@(src,evt)obj.updateBeamBufferAsyncCallback(src,evt));
                            end
                            obj.updateBeamStatusFrac(beamIDs,pathFOV);
                        end
                    end
                end
                
                if ~isnan(timeout)
                    t = tic;
                    while obj.beamBufferUpdatingAsyncNow
                        pause(.01);
                        assert(toc(t) < timeout, 'Beam buffer write timed out.');
                    end
                end
            end
        end
        
        function updateBeamBufferAsyncCallback(obj,~,evt)
            obj.beamBufferUpdatingAsyncNow = false; % this needs to be the first call in the function in case there are errors below
            
            if obj.streamingBuffer
                obj.samplesWritten = obj.samplesWritten + evt.sampsWritten;
                obj.framesWritten = obj.samplesWritten / obj.frameSamps;
            end
            
            if evt.status ~= 0 && evt.status ~= 200015 && obj.active
                fprintf(2,'Error updating beams buffer: %s\n%s\n',evt.errorString,evt.extendedErrorInfo);
                
                if ~obj.streamingBuffer && (obj.beamBufferUpdatingAsyncRetries < 3 || obj.beamBufferNeedsUpdateAsync)
                    obj.beamBufferUpdatingAsyncRetries = obj.beamBufferUpdatingAsyncRetries + 1;
                    fprintf(2,'Scanimage will retry update...\n');
                    obj.updateBeamBufferAsync(obj.beamBufferNeedsUpdateRegenerate);
                else
                    obj.beamBufferUpdatingAsyncRetries = 0;
                end
            else
                obj.beamBufferUpdatingAsyncRetries = 0;

                if obj.beamBufferNeedsUpdateAsync
                    obj.updateBeamBufferAsync(obj.beamBufferNeedsUpdateRegenerate);
                end
            end
        end
        
        function [aoVolts,pathFOV] = calcStreamingBuffer(obj, bufStartFrm, nFrames)
            bufEndFrm = (bufStartFrm+nFrames-1);
            
            if obj.aoSlices > 1
                % the generated AO is for multiple slices. for each frame we
                % need to extract the correct slice from the correct buffer
                frms = bufStartFrm:(bufStartFrm+nFrames-1);
                for ifr = numel(frms):-1:1
                    ss = 1 + (ifr-1)*obj.frameSamps;
                    es = ifr*obj.frameSamps;
                    
                    slcInd = mod(frms(ifr)-1,obj.aoSlices)+1;
                    aoSs = 1 + (slcInd-1)*obj.frameSamps;
                    aoEs = slcInd*obj.frameSamps;
                    
                    if (frms(ifr) >= obj.powerBoxStartFrame) && (frms(ifr) <= obj.powerBoxEndFrame) && obj.hasPowerBoxes
                        aoVolts(ss:es,:) = obj.hSI.hWaveformManager.scannerAO.ao_volts.Bpb(aoSs:aoEs,:);
                        pathFOV(ss:es,:) = obj.hSI.hWaveformManager.scannerAO.pathFOV.Bpb(aoSs:aoEs,:);
                    else
                        aoVolts(ss:es,:) = obj.hSI.hWaveformManager.scannerAO.ao_volts.B(aoSs:aoEs,:);
                        pathFOV(ss:es,:) = obj.hSI.hWaveformManager.scannerAO.pathFOV.B(aoSs:aoEs,:);
                    end
                end
            else
                if (bufStartFrm >= obj.powerBoxStartFrame) && (bufEndFrm <= obj.powerBoxEndFrame) && obj.hasPowerBoxes
                    % power box is on the whole time
                    aoVolts = repmat(obj.hSI.hWaveformManager.scannerAO.ao_volts.Bpb, nFrames, 1);
                    pathFOV = repmat(obj.hSI.hWaveformManager.scannerAO.pathFOV.Bpb,  nFrames, 1);
                else
                    aoVolts = repmat(obj.hSI.hWaveformManager.scannerAO.ao_volts.B, nFrames, 1);
                    pathFOV = repmat(obj.hSI.hWaveformManager.scannerAO.pathFOV.B, nFrames, 1);
                    if (bufStartFrm <= obj.powerBoxEndFrame) && (bufEndFrm >= obj.powerBoxStartFrame) && obj.hasPowerBoxes
                        % power box is on at lease some of the time
                        onStartFr = max(bufStartFrm, obj.powerBoxStartFrame);
                        onEndFr = min(bufEndFrm, obj.powerBoxEndFrame);
                        ss = (onStartFr-bufStartFrm)*length(obj.hSI.hWaveformManager.scannerAO.ao_volts.B) + 1;
                        se = (onEndFr-bufStartFrm+1)*length(obj.hSI.hWaveformManager.scannerAO.ao_volts.B);
                        aoVolts(ss:se,:) = repmat(obj.hSI.hWaveformManager.scannerAO.ao_volts.Bpb, onEndFr-onStartFr+1, 1);
                        pathFOV(ss:se,:) = repmat(obj.hSI.hWaveformManager.scannerAO.pathFOV.Bpb, onEndFr-onStartFr+1, 1);
                    end
                end
            end
        end
        
        function voltage = zprpBeamsPowerFractionToVoltage(obj,beamIdxs,powerFracs)
            % Use the calibration LUT to look up the beam voltage needed to
            % achieve a certain beam power fraction.
            % powerFrac: real number vector on [0,1].
            % voltage: beam voltage vector that will achieve powerFrac
            
            validateattributes(beamIdxs,{'numeric'},{'vector','integer','>=',1,'<=',obj.totalNumBeams});
            if isscalar(powerFracs)
                powerFracs = repmat(powerFracs,1,numel(beamIdxs));
            end
            validateattributes(powerFracs,{'numeric'},{'ncols',numel(beamIdxs),'>=',0});
            
            for idx = 1:length(beamIdxs)
                powerFracs(:,idx) = max(powerFracs(:,idx),obj.calibrationMinAchievablePowerFrac(beamIdxs(idx)));
            end
            
            cappedIdxs = find(powerFracs > 1);
            
            cappedBeamIdxs = any(cappedIdxs,1);
            if any(cappedBeamIdxs)
                most.idioms.dispError('WARNING(%s): A power fraction > 1.0 was requested for beams %s (''%s''). Power capped at maximum value determined during last calibration.\n',class(obj),num2str(beamIdxs(cappedBeamIdxs)),strjoin(obj.displayNames(beamIdxs(cappedBeamIdxs))));
            end
            
            powerFracs(cappedIdxs) = 1.0;
            
            % use ceil for now, minimum value of 1
            lutIdxs = max(1,ceil(powerFracs.*obj.calibrationLUTSize));
            
            voltage = zeros(size(lutIdxs));
            
            for idx = 1:numel(beamIdxs)
               voltage(:,idx) = obj.calibrationLUT(lutIdxs(:,idx),beamIdxs(idx));
            end
%             % interpolated version.
%             lutx = max(1/obj.calibrationLUTSize,powerFrac);
%             voltage = interp1(linspace(1/obj.calibrationLUTSize,1,obj.calibrationLUTSize),obj.calibrationLUT(:,beamIdx),lutx);
        end
        
        function makeExtDaqReq(obj, src, daqId)
            obj.externalBeamDAQReq(end+1) = struct('src',src,'daq',daqId);
        end
        
        function clearExtDaqReqs(obj, src)
            del = logical([]);
            for req = obj.externalBeamDAQReq
                del(end+1) = logical(req.src == src);
            end
            obj.externalBeamDAQReq(del) = [];
            obj.updateStaticBeams();
        end
    end
    
    methods (Hidden)
        
        %This needs to know the beam ID in order to know which cell of
        %pzCustom to reference. pzCustom{2}(R,C) for LUT Matrix
        function powers = zprvBeamsDepthPowerCorrection(obj,beamIdx,startPower,zPowerReference,z,lz)
            if obj.numInstances > 0
                if(isempty(obj.pzCustom{beamIdx}))
                    powers = (startPower.*exp((z-zPowerReference)./lz));
                elseif(isa(obj.pzCustom{beamIdx}, 'function_handle'))
                    powers = obj.pzCustom{beamIdx}(startPower,zPowerReference,z,lz);
                elseif(ismatrix(obj.pzCustom{beamIdx}) && ~isempty(obj.pzCustom{beamIdx}))
                    powers = interp1(obj.pzCustom{beamIdx}(:,1), obj.pzCustom{beamIdx}(:,2), z,'spline', 10);
                else
                    disp('Error! Invalid Parameter pzCustom!');
                    powers = obj.powers;
                end
            end
        end
        
        function val = getExtLineClockTerminal(obj, daqID)
            % This routine configures the start trigger for hTask
            % it first tries to connect the start trigger to the internal
            % beamsclock output of Scan2D. If this route fails, it uses the
            % external trigger terminal configured in the MDF
            
            if isempty(obj.extLineClockTerminal_{daqID}) && ~isempty(obj.hTask{daqID})
                try
                    % Try internal routing
                    pxiTrig = obj.hSI.hScan2D.trigBeamClkOutInternalTerm;
                    obj.hTask{daqID}.cfgDigEdgeStartTrig(pxiTrig);
                    obj.hTask{daqID}.control('DAQmx_Val_Task_Reserve'); % if no internal route is available, this call will throw an error
                    obj.hTask{daqID}.control('DAQmx_Val_Task_Unreserve');
                    val = pxiTrig;
                    % fprintf('Beams: internal modified line clock trigger route found: %s\n',val);
                catch ME
                    % Error -89125 is expected: No registered trigger lines could be found between the devices in the route.
                    % Error -89139 is expected: There are no shared trigger lines between the two devices which are acceptable to both devices.
                    if isempty(strfind(ME.message, '-89125')) && isempty(strfind(ME.message, '-89139')) % filter error messages
                        rethrow(ME)
                    end
                    
                    % No internal route available - use MDF settings
                    val = obj.mdfData.beamDaqs(daqID).modifiedLineClockIn;
                    assert(~isempty(val), 'Beams: modifiedLineClockIn was empty for beam DAQ %d and no internal trigger route was found.', daqID);
                    % fprintf('Beams: no internal trigger route found. Using MDF settings for modified line clock: %s\n',val);
                end
                obj.extLineClockTerminal_{daqID} = val;
            else
                val = obj.extLineClockTerminal_{daqID};
            end
        end
        
        function val = getExtFrameClockTerminal(obj, daqID)
            % This routine configures the start trigger for hTask
            % it first tries to connect the start trigger to the internal
            % framesclock output of Scan2D. If this route fails, it uses the
            % external trigger terminal configured in the MDF
            
            if isempty(obj.extFrameClockTerminal_{daqID}) && ~isempty(obj.hTask{daqID})
                try
                    % Try internal routing
                    internalTrigTerm = obj.hSI.hScan2D.trigFrameClkOutInternalTerm;
                    obj.hTask{daqID}.cfgDigEdgeStartTrig(internalTrigTerm);
                    obj.hTask{daqID}.control('DAQmx_Val_Task_Reserve'); % if no internal route is available, this call will throw an error
                    obj.hTask{daqID}.control('DAQmx_Val_Task_Unreserve');
                    obj.hTask{daqID}.disableStartTrig();
                    
                    val = internalTrigTerm;
                    % fprintf('Beams: internal frame clock trigger route found: %s\n',val);
                catch ME
                    % Error -89125 is expected: No registered trigger lines could be found between the devices in the route.
                    % Error -89139 is expected: There are no shared trigger lines between the two devices which are acceptable to both devices.
                    if isempty(strfind(ME.message, '-89125')) && isempty(strfind(ME.message, '-89139')) % filter error messages
                        rethrow(ME)
                    end
                    obj.hTask{daqID}.control('DAQmx_Val_Task_Unreserve');
                    obj.hTask{daqID}.disableStartTrig();

                    % No internal route available - use MDF settings
                    val = obj.mdfData.beamDaqs(daqID).frameClockIn;
                    assert(~isempty(val), 'Beams: frameClockIn was empty for beam DAQ %d and no internal trigger route was found.', daqID);
                    % fprintf('Beams: no internal trigger route found. Using MDF settings for frame clock: %s\n',val);
                end
                obj.extFrameClockTerminal_{daqID} = val;
            else
                val = obj.extFrameClockTerminal_{daqID};
            end
        end
        
        function [term, rate] = getExtReferenceClock(obj, daqID)
            if isempty(obj.extReferenceClock_{daqID}) && ~isempty(obj.hTask{daqID})
                try
                    set(obj.hTask{daqID},'sampClkTimebaseSrc',obj.hSI.hScan2D.trigReferenceClkOutInternalTerm);
                    set(obj.hTask{daqID},'sampClkTimebaseRate',obj.hSI.hScan2D.trigReferenceClkOutInternalRate);
                    
                    obj.hTask{daqID}.control('DAQmx_Val_Task_Reserve'); % if no internal route is available, this call will throw an error
                    obj.hTask{daqID}.control('DAQmx_Val_Task_Unreserve');
                    
                    set(obj.hTask{daqID},'sampClkTimebaseSrc','');
                    
                    term = obj.hSI.hScan2D.trigReferenceClkOutInternalTerm;
                    rate = obj.hSI.hScan2D.trigReferenceClkOutInternalRate;
                catch ME
                    % Error -89125 is expected: No registered trigger lines could be found between the devices in the route.
                    % Error -89139 is expected: There are no shared trigger lines between the two devices which are acceptable to both devices.
                    if isempty(strfind(ME.message, '-89125')) && isempty(strfind(ME.message, '-89139')) % filter error messages
                        rethrow(ME)
                    end
                    obj.hTask{daqID}.control('DAQmx_Val_Task_Unreserve');
                    set(obj.hTask{daqID},'sampClkTimebaseSrc','');
                    
                    if ismember(get(obj.hDaqDevice{daqID},'busType'), {'DAQmx_Val_PXI','DAQmx_Val_PXIe'})
                        term = 'PXI_CLK10';
                        rate = 10e6;
                    else
                        term = obj.mdfData.beamDaqs(daqID).referenceClockIn;
                        if isfield(obj.mdfData.beamDaqs(daqID),'referenceClockRate') && ~isempty(obj.mdfData.beamDaqs(daqID).referenceClockRate)
                            rate = obj.mdfData.beamDaqs(daqID).referenceClockRate;
                        else 
                            rate = 10e6;
                        end
                        assert(~isempty(term), 'Beams: referenceClockIn was empty for beam DAQ %d and no internal trigger route was found.', daqID);
                    end
                end
                
                obj.extReferenceClock_{daqID} = {term rate};
            else
                term = obj.extReferenceClock_{daqID}{1};
                rate = obj.extReferenceClock_{daqID}{2};
            end
        end
        
        function zprvSetInternal(obj,propName,val)
            isf  = obj.internalSetFlag;
            obj.internalSetFlag = true;
            ME = [];
            try
                obj.(propName) = val;
            catch MEtemp
                ME = MEtemp;
            end
            obj.internalSetFlag = isf;
            
            if ~isempty(ME)
                ME.rethrow();
            end
        end
        
        function streamingBufferNSampCB(obj,~,~)
            obj.samplesGenerated = obj.samplesGenerated + obj.nSampCbN;
            obj.framesGenerated = obj.samplesGenerated / obj.frameSamps;
            obj.updateBeamBufferAsync(false);
        end
        
        function bufsz = configureStreaming(obj,sampleRate)
            if obj.enablePowerBox && ((obj.powerBoxStartFrame > 1) || (~isinf(obj.powerBoxEndFrame)))
                obj.streamingBuffer = true;
                
                if obj.hSI.hStackManager.isFastZ
                    obj.aoSlices = numel(obj.hSI.hStackManager.zs) + obj.hSI.hFastZ.numDiscardFlybackFrames;
                else
                    obj.aoSlices = 1;
                end
                L = length(obj.hSI.hWaveformManager.scannerAO.ao_volts(1).B);
                assert(mod(L,obj.aoSlices) == 0,'AO length is not divisible by number of slices.')
                obj.frameSamps = L/obj.aoSlices;
                
                frameTime = obj.frameSamps / sampleRate;
                n = ceil(obj.nominalStreamingBufferTime / frameTime);
                obj.streamingBufferFrames = ceil(n/2)*2;
                obj.streamingBufferSamples = obj.streamingBufferFrames * obj.frameSamps;
                obj.nSampCbN = obj.streamingBufferSamples / 2;
                
                obj.samplesGenerated = 0;
                obj.samplesWritten = 0;
                obj.framesGenerated = 0;
                obj.framesWritten = 0;
                
                obj.hTask{obj.activeBeamDaqID}.set('writeRegenMode','DAQmx_Val_DoNotAllowRegen');
                obj.hTask{obj.activeBeamDaqID}.registerEveryNSamplesEvent(@obj.streamingBufferNSampCB,obj.nSampCbN,false);
            else
                obj.streamingBuffer = false;
                obj.streamingBufferFrames = 1;
                obj.streamingBufferSamples = length(obj.hSI.hWaveformManager.scannerAO.ao_volts.B);
                obj.hTask{obj.activeBeamDaqID}.set('writeRegenMode','DAQmx_Val_AllowRegen');
                obj.hTask{obj.activeBeamDaqID}.registerEveryNSamplesEvent([],[],false);
            end
            
            bufsz = obj.streamingBufferSamples;
        end
        
        function rearm(obj)
            if ~isempty(obj.hSI.hScan2D.mdfData.beamDaqID)
                assert(obj.active);
                obj.beamBufferNeedsUpdateAsync = false;
                if ~obj.sharingScannerDaq && ~isempty(obj.activeBeamDaqID)
                    obj.hTask{obj.activeBeamDaqID}.abort();
                end
                obj.beamBufferUpdatingAsyncNow = false;
                
                if ~obj.sharingScannerDaq
                    obj.configureBeamsTask();
                    if ~obj.hSI.mdfData.simulated
                        obj.hTask{obj.activeBeamDaqID}.start();
                    end
                end
            end
        end
    end
    
    %% INTERNAL METHODS
    methods (Hidden, Access=private)
        function configureBeamsTask(obj)
            obj.hTask{obj.activeBeamDaqID}.abort();
            obj.hTask{obj.activeBeamDaqID}.control('DAQmx_Val_Task_Unreserve'); %should flush data
            
            beamCfg = obj.hSI.hScan2D.scannerset.beamsTriggerCfg();
            sampleRate = obj.hSI.hScan2D.scannerset.beams.sampleRateHz;
            
            if ~isempty(obj.lastScannerCfgd{obj.activeBeamDaqID}) && ~strcmp(obj.lastScannerCfgd{obj.activeBeamDaqID}, obj.hSI.hScan2D.scannerset.name)
                obj.recreateBeamDaqTask(obj.activeBeamDaqID);
            end
            obj.lastScannerCfgd{obj.activeBeamDaqID} = obj.hSI.hScan2D.scannerset.name;
            
            % set up reference clock if needed
            
            % reset sampClkTimebase to default and preconfigure
            % sampleRate. otherwise, getExtReferenceClock can throw and
            % error if sampleRate and sampClkTimebaseRate conflict
            set(obj.hTask{obj.activeBeamDaqID},'sampClkTimebaseSrc','OnboardClock');
            set(obj.hTask{obj.activeBeamDaqID},'sampClkRate',sampleRate);
            
            if beamCfg.requiresReferenceClk
                [refTerm, refRate] = obj.getExtReferenceClock(obj.activeBeamDaqID);
                if ~isempty(refTerm)                    
                    set(obj.hTask{obj.activeBeamDaqID},'sampClkTimebaseSrc',refTerm);
                    set(obj.hTask{obj.activeBeamDaqID},'sampClkTimebaseRate',refRate);
%                 else
%                     set(obj.hTask{obj.activeBeamDaqID},'sampClkTimebaseSrc','OnboardClock');
%                     most.idioms.dispError(['Beams: Warning: The beams output requires clock synchronization with the imaging system, ', ...
%                                'but no reference clock is available to synchronize the beam device clock.', ...
%                                'The beam output will drift relative to the imagefield'] );
%                     set(obj.hTask{obj.activeBeamDaqID},'sampClkTimebaseSrc','');
                end
%             else
%                 set(obj.hTask{obj.activeBeamDaqID},'sampClkTimebaseSrc','');
            end
            
            % set up trigger
            switch beamCfg.triggerType
                case 'lineClk'
                    obj.hTask{obj.activeBeamDaqID}.cfgDigEdgeStartTrig(obj.getExtLineClockTerminal(obj.activeBeamDaqID));
                    obj.hTask{obj.activeBeamDaqID}.set('startTrigRetriggerable',true);
                    sampleQuantity = 'DAQmx_Val_FiniteSamps';
                    samplesPerTrigger = obj.hSI.hWaveformManager.scannerAO.ao_samplesPerTrigger.B;
                    
                    bufsz = obj.configureStreaming(sampleRate);
                case 'frameClk'
                    obj.hTask{obj.activeBeamDaqID}.cfgDigEdgeStartTrig(obj.getExtFrameClockTerminal(obj.activeBeamDaqID));
                    obj.hTask{obj.activeBeamDaqID}.set('startTrigRetriggerable',true);
                    sampleQuantity = 'DAQmx_Val_FiniteSamps';
                    samplesPerTrigger = obj.hSI.hWaveformManager.scannerAO.ao_samplesPerTrigger.B;
                    
                    bufsz = obj.configureStreaming(sampleRate);
                case 'static'
                    obj.hTask{obj.activeBeamDaqID}.disableStartTrig;
                    obj.hTask{obj.activeBeamDaqID}.set('startTrigRetriggerable',false);
                    sampleQuantity = 'DAQmx_Val_ContSamps';
                    samplesPerTrigger = 10e3;
                    
                    assert(~obj.enablePowerBox,'Power box unsupported during static beam output');
                    obj.configureStreaming(sampleRate);
                    obj.streamingBufferSamples = 10e3;  %overwrite streamingBufferSamples
                    bufsz = obj.streamingBufferSamples;
                otherwise 
                    error('Unsupported trigger type: %s',triggerType);
            end
            
            ao = obj.hSI.hWaveformManager.scannerAO.ao_volts.B;
            assert(size(ao,1) > 0, 'AO generation error. Beams AO waveform length is zero.');
            
            if ~obj.hSI.mdfData.simulated
                obj.hTask{obj.activeBeamDaqID}.cfgSampClkTiming(sampleRate,sampleQuantity,samplesPerTrigger);
                assert(obj.hTask{obj.activeBeamDaqID}.sampClkRate == sampleRate,'Beams sample rate could not be satisfied'); % read sample clock back to verify configuration
                obj.hTask{obj.activeBeamDaqID}.cfgOutputBuffer(bufsz);
            end
            
            obj.updateBeamBufferAsync(false, 5);
            
            if ~obj.hSI.mdfData.simulated
                obj.hTask{obj.activeBeamDaqID}.control('DAQmx_Val_Task_Verify'); % verify task configuration (mostly for trigger routing)
            end
        end
        
        function recreateBeamDaqTask(obj, id)
            if most.idioms.isValidObj(obj.hTask{id})
                obj.hTask{id}.clear();
            end
            
            obj.hTask{id} = most.util.safeCreateTask(sprintf('Beam DAQ %d Modulation',id));
            
            %make props exist
            get(obj.hTask{id}, 'writeRelativeTo');
            get(obj.hTask{id}, 'writeOffset');
            
            for j=1:obj.daqNumBeams(id)
                idString = obj.displayNames{obj.daqBeamIDs{id}(j)};
                daqData = obj.mdfData.beamDaqs(id);
                obj.hTask{id}.createAOVoltageChan(obj.hDaqDevice{id}.deviceName,daqData.chanIDs(j),idString);
            end
            
            supportedSampleRate = scanimage.util.daqTaskGetMaxSampleRate(obj.hTask{id},obj.daqNumBeams(id));
            obj.hTask{id}.cfgSampClkTiming(supportedSampleRate,'DAQmx_Val_FiniteSamps');
            
            obj.extLineClockTerminal_{id} = '';
            obj.extFrameClockTerminal_{id} = '';
            obj.extReferenceClock_{id} = {};
        end
        
        function val = zprpBeamScalarExpandPropValue(obj,val,propName)
            if isempty(val)
                val = NaN;
            end
            
            if isscalar(val)
                val = repmat(val,1,obj.totalNumBeams);
            else
                assert(numel(val)==obj.totalNumBeams,...
                    'The ''%s'' value must be a vector of length %d -- one value for each beam',...
                    propName,obj.totalNumBeams);
                s = size(val);
                if s(1) > s(2)
                    val = val';
                end
            end
        end
        
        function zcbkParentUpdated(obj,src,evnt)
            propName = src.Name;
            hParent = evnt.AffectedObject;
            obj.(propName) = hParent.(propName);
        end
        
        function [lut,beamCalMinVoltage,beamCalMaxVoltage,success] = zprvBeamsProcessCalibrationData(obj,beamVoltage,beamCalVoltage,beamCalOffset,rejectedLight,beamID)
            % lut: (calibrationLUTSize x 1) numeric array, where lut(i)
            % gives beam voltage necessary to achieve
            % (i/calibrationLUTSize) fraction of maximum achieved power
            % beamCalMin/MaxVoltage: min/max beam cal voltage (averaged over
            % calibration passes) achieved during calibration sweeps
            % rejectedLight: true if rejected light is employed for calibration
            
            success = true;
            assert(isvector(beamVoltage) && size(beamCalVoltage,1)==numel(beamVoltage));
            
            bcv_mu = mean(beamCalVoltage,2);
            bcv_mu = bcv_mu - beamCalOffset;
            bcv_mu_raw = bcv_mu; %Store 'raw' value in case we need to display it later (for failed calibrations)
            
            bcv_sd = std(beamCalVoltage,1,2); % Old veej notes: Normalize by the number of calibration passes?
            bcv_mu(bcv_mu<0) = 0; %Identify negative values (likely due to incorrect offset) as 0 TODO: Better way?
            
            beamCalMinVoltage = min(bcv_mu);
            beamCalMaxVoltage = max(bcv_mu);
            
            if (beamCalMinVoltage == beamCalMaxVoltage) || (beamCalMaxVoltage == 0)
                znstWarnAndRunNaiveCalibration('Invalid data collected. The max voltage is too low.');
                return;
            end
            
            bcvNormalized = bcv_mu/beamCalMaxVoltage;
                
            % Take measurement from rejected light, if necessary.
            % TODO: Handle per-beam           
            if rejectedLight
                bcvNormalized = 1 - bcvNormalized;
                bcvNormalized = bcvNormalized/max(bcvNormalized); %Renormalize to ensure max value = 1.0
            end
            
            [~,minIdx] = min(bcvNormalized);
            [~,maxIdx] = max(bcvNormalized);
            
            avg_dev = mean(bcv_sd/beamCalMaxVoltage);
            minAchievableBeamPowerFraction = max(beamCalMinVoltage/beamCalMaxVoltage, 1/obj.calibrationLUTSize); %Enforce maximum dynamic range supported by LUT size
            
            % warnings/failures
            tfFatalFailure = false;
            
            if avg_dev > obj.calibrationFluctuationThreshold
                if beamCalMaxVoltage == 0
                    tfFatalFailure = true;
                    fatalWarnStr = 'Beam calibration data appears entirely negative-valued, unexpectedly. Connections or hardware may be faulty.';
                else
                    most.idioms.warn('SI:zprvBeamsProcessCalibrationData',...
                        'Beam calibration seems excessively noisy. Typical standard deviation per sample: %s%%.',...
                        num2str(100*avg_dev));
                    obj.zprvBeamsShowRawCalibrationData(beamVoltage, bcv_mu_raw,obj.displayNames{beamID});
                    % Continue with regular calibration
                end
            end
            
            if minAchievableBeamPowerFraction > obj.calibrationMinThreshold
                tfFatalFailure = true;
                fatalWarnStr = sprintf('Beam calibration minimum power not less than 15%% of maximum power. Min/max: %s%%',...
                    num2str(100*minAchievableBeamPowerFraction));
            end
            if beamCalMaxVoltage > 0 && minIdx >= maxIdx
                tfFatalFailure = true;
                fatalWarnStr = '';
            end
            if tfFatalFailure
                znstWarnAndRunNaiveCalibration(fatalWarnStr);
                return;
            end
   
            
            lut = zeros(obj.calibrationLUTSize,1);
            minAchievableBeamPowerLUTIdx = ceil(minAchievableBeamPowerFraction * obj.calibrationLUTSize);
            
            lut(1:minAchievableBeamPowerLUTIdx-1) = nan; % These beam power idxs are unachievable; their lut values should never be used
            % For rest of LUT, do interpolation over interval [minIdx,maxIdx]
            
            x = bcvNormalized(minIdx:maxIdx);
            y = beamVoltage(minIdx:maxIdx);
            
            % eliminate any flat zeros at beginning (these can be generated since we set all bcvNormalized values less than 0 to be 0)
            tfFlatZero = x==0;
            if any(tfFlatZero)
                flatZeroIdx = find(tfFlatZero);
                if ~isequal(flatZeroIdx,(1:numel(flatZeroIdx))')
                    % expect flat zeros only at the beginning
                    znstWarnAndRunNaiveCalibration('Unexpected flat zeros in beam calibration voltage');
                    return;
                end
                x(flatZeroIdx(1:end-1)) = []; % take last flatzero datapoint (highest beam voltage)
                y(flatZeroIdx(1:end-1)) = [];
            end
            
            x = zlclMonotonicize(x);
            y = zlclMonotonicize(y);
            
            % Check to see if any values in x are repeated. If there are any repeated values in x, then interp1 will fail, so run a naive calibration.
            if numel(unique(x)) == numel(x)
                lut(minAchievableBeamPowerLUTIdx:obj.calibrationLUTSize) = interp1(x,y,(minAchievableBeamPowerLUTIdx:obj.calibrationLUTSize)/obj.calibrationLUTSize,'pchip',nan);
            else
                znstWarnAndRunNaiveCalibration('Repeated Values Found in Beam Calibration Data.');
            end
            
            function znstWarnAndRunNaiveCalibration(warnMsg)
                most.idioms.dispError('WARNING: Beam calibration data for ''%s'' appears suspect. Using naive calibration.\n',obj.displayNames{beamID});
                if ~isempty(warnMsg)
                    most.idioms.dispError(' Explanation: %s\n',warnMsg);
                end
                obj.zprvBeamsShowRawCalibrationData(beamVoltage,bcv_mu_raw,obj.displayNames{beamID});
                [lut,beamCalMinVoltage,beamCalMaxVoltage] = ...
                    obj.zprvBeamsPerformNaiveCalibration(beamVoltage,rejectedLight);
                
                success = false;
            end
        end
        
        function [lut,beamCalMinVoltage,beamCalMaxVoltage] = zprvBeamsPerformNaiveCalibration(obj,beamVoltage,rejectedLight)
            
            if rejectedLight
                calVoltage = max(beamVoltage) - beamVoltage;
            else
                calVoltage = beamVoltage;
            end
            
            [lut,beamCalMinVoltage,beamCalMaxVoltage] = obj.zprvBeamsProcessCalibrationData(beamVoltage,calVoltage,0.0,rejectedLight,[]);
        end
        
        function zprvBeamsSetCalibrationInfo(obj,beamIdx,lut,beamCalMinVoltage,beamCalMaxVoltage,success)
            validateattributes(beamIdx,{'numeric'},{'vector','integer','>=',1,'<=',obj.totalNumBeams});
            validateattributes(lut,{'numeric'},{'size',[obj.calibrationLUTSize 1]});
            
            if nargin < 6 || isempty(success)
                success = false;
            end
            
            obj.beamCalibratedStatus(beamIdx) = success;
            
            obj.calibrationLUT(:,beamIdx) = lut;
            obj.calibrationMinCalVoltage(1,beamIdx) = beamCalMinVoltage;
            obj.calibrationMaxCalVoltage(1,beamIdx) = beamCalMaxVoltage;
            
            % round this value to the "resolution" of the LUT
            obj.calibrationMinAchievablePowerFrac(1,beamIdx) = ...
                ceil(beamCalMinVoltage/beamCalMaxVoltage*obj.calibrationLUTSize)/obj.calibrationLUTSize;
            
            obj.powers = obj.zprvBeamEnforcePowerLimits(obj.powers);
        end
        
        function zprvBeamsShowRawCalibrationData(obj,beamVoltages,beamCalVoltages,diplayname) 
            %Displays figure showing last measured raw calibration data obtained for beam modulation device of specified beamIdx
            most.idioms.safeDeleteObj(obj.hCalibFig);
            obj.hCalibFig = figure('NumberTitle','off','DoubleBuffer','On','Name','Beam Calibration Curve','Color','White');
            a = axes('Parent',obj.hCalibFig,'FontSize',12,'FontWeight','Bold');
            [beamVoltages,idxs] = sort(beamVoltages);
            plot(beamVoltages,beamCalVoltages(idxs),'Parent',a,'Color',[0 0 0],'LineWidth',2);
            if nargin < 4 || isempty(diplayname)
                title(sprintf('Raw Calibration Data'),'Parent',a,'FontWeight','bold');
            else
                title(sprintf(['Raw Calibration Data (' diplayname ')']),'Parent',a,'FontWeight','bold');
            end
            xlabel('Beam Modulation Voltage [V]','Parent',a,'FontWeight','bold');
            ylabel('Beam Calibration Voltage [V]','Parent',a,'FontWeight','bold');
            %TODO is this figHandle stored somewhere
        end
        
        function powers = zprvBeamEnforcePowerLimits(obj,powers)
            assert(numel(powers)==obj.totalNumBeams);
            
            % enforce upper limit
            maxPowers = obj.powerLimits;
            powers = min(powers,maxPowers);
            
            % enforce lower limit
            minPowers = obj.calibrationMinAchievablePowerFrac*100;
            powers = max(powers,minPowers);
        end
        
        function beamVoltage = zprvBeamCalGetBeamVoltage(obj,beamIdx)
            %Create array of modulation voltages
            % Add zeros at the end b/c "VI111010A: Add delay between
            % calibration sweeps (allows for case where slow decay in
            % transmission is seen after reaching high voltages) -- Vijay
            % Iyer 11/10/10"
            %
            % Hold each voltage step for 2 samples. We'll record input signal on 2'nd of each pair, to avoid any settling time problems.
            %
            voltageSteps = obj.zprvBeamCalGetNaiveBeamVoltage(beamIdx);
            beamVoltage = [zeros(1,2*numel(voltageSteps))  zeros(1,obj.calibrationIntercalibrationZeros)]';
            for i=1:numel(voltageSteps)
                [beamVoltage(2*i-1),beamVoltage(2*i)] = deal(voltageSteps(i));
            end
        end
        
        function beamVoltage = zprvBeamCalGetNaiveBeamVoltage(obj,beamIdx)
            voltageRange = obj.voltageRanges(beamIdx);
            beamVoltage = linspace(0,voltageRange,obj.calibrationNumVoltageSteps)';
        end
        
        function [tfSuccess,beamCalVoltage,beamVoltage] = zprvBeamsGetCalibrationData(obj,beamIdx)
            % tfSuccess: true if calibration successful.
            % beamCalVoltage: (calibrationNumVoltageSteps x
            % calibrationNumPasses) vector of beam cal voltages
            % corresponding to beamVoltage
            % beamVoltage: (calibrationNumVoltageSteps x 1) vector of beam
            % voltages
            
            validateattributes(beamIdx,{'numeric'},{'vector','integer','>=',1,'<=',obj.totalNumBeams});
            
            wb = waitbar(0,sprintf('Calibrating ''%s''...', obj.displayNames{beamIdx}),...
                'Name','Calibrating...','CreateCancelBtn','hSI.cancelCalibration = true;');
            
            beamVoltage = zprvBeamCalGetBeamVoltage(obj,beamIdx);
            NbeamVoltage = numel(beamVoltage);
            
            if isempty(obj.hCals{beamIdx})
                tfSuccess = true;
                beamCalVoltage = [];
                znstCleanup(false);
                return;
            end
            
            daqID = obj.globalID2Daq(beamIdx);
            beamLocalID = obj.globalID2DaqID(beamIdx);
            
            %Prepare hBeams and hCals
            beamTask = obj.hTask{daqID};
            assert(isscalar(beamTask));
            beamTask.control('DAQmx_Val_Task_Unreserve');
            beamTask.cfgSampClkTiming(obj.calibrationOutputRate,'DAQmx_Val_FiniteSamps',NbeamVoltage);
            beamTask.cfgOutputBuffer(NbeamVoltage);
            beamTask.set('startTrigRetriggerable',false);
            beamTask.disableStartTrig();
            beamVoltageAllChan = zeros(numel(beamVoltage),obj.daqNumBeams(daqID));
            beamVoltageAllChan(:,beamLocalID) = beamVoltage;
            obj.updateBeamStatusFrac(beamIdx,NaN);
            beamTask.writeAnalogData(beamVoltageAllChan);
            beamCalTask = obj.hCals{beamIdx};
            beamCalTask.set('startTrigRetriggerable',false);
            beamCalTask.disableStartTrig();
            beamCalTask.control('DAQmx_Val_Task_Unreserve');
            beamCalTask.cfgSampClkTiming(obj.calibrationOutputRate,'DAQmx_Val_FiniteSamps',NbeamVoltage,beamTask.get('sampClkTerm'));
            
            % calibration loop
            beamCalVoltage = zeros(NbeamVoltage,obj.calibrationNumPasses);
            
            tfSuccess = false;
            try % Why is this try/catch necessary?
                for c = 1:obj.calibrationNumPasses
                    if obj.cancelCalibration
                        znstCancelCleanup();
                        return;
                    end
                    
                    beamCalTask.start();
                    beamTask.start();
                    
                    beamCalVoltage(:,c) = beamCalTask.readAnalogData(NbeamVoltage);
                    
                    beamTask.stop();
                    beamCalTask.stop();
                    pause(obj.calibrationIntercalibrationPauseTime);
                    waitbar(c/obj.calibrationNumPasses,wb);
                end
            catch ME %#ok<NASGU>
                %Some error occurred during calibration, most likely while reading calibration data.
                %Leave to caller to generate warning/error message (since tfSuccess=false)
                znstCleanup();
                return;
            end
            
            if obj.cancelCalibration
                znstCancelCleanup();
                return;
            end
            
            znstCleanup();
            tfSuccess = true;
            
            function znstCleanup(beamCalibrated)
                
                if nargin < 1
                    beamCalibrated = true;
                end
                
                delete(wb);
                
                %Remove intercalibration zeros
                numZeros = obj.calibrationIntercalibrationZeros;
                beamVoltage(end-numZeros+1:end) = [];
                if beamCalibrated
                    beamCalVoltage(end-numZeros+1:end,:) = [];
                end
                
                %Take second of every pair of beamVoltage/beamCalVoltage values (first sample was for settling)
                beamVoltage = beamVoltage(2:2:end);
                if beamCalibrated
                    beamCalVoltage = beamCalVoltage(2:2:end,:);
                end
                
                if beamCalibrated
                    %Clean up Beam DAQ Tasks
                    beamTask.stop();
                    beamCalTask.stop();
                    beamTask.control('DAQmx_Val_Task_Unreserve');
                    beamCalTask.control('DAQmx_Val_Task_Unreserve');
                end
            end
            
            function znstCancelCleanup()
                znstCleanup();
                obj.cancelCalibration = false;
            end
        end
        
        function ziniCalibrateBeams(obj)
            try
                if obj.totalNumBeams
                    obj.beamsCalibrate();
                end
            catch ME
                most.idioms.dispError('Error occurred while preparing beams calibration. Incorrect MachineDataFile settings likely cause. Error stack:\n');
                most.idioms.reportError(ME);
                most.idioms.dispError('Disabling beams feature.\n');
                obj.ziniDisableBeamsFeature();
            end
        end
        
        function ziniDeleteTasks(obj)
            while ~isempty(obj.hTask)
                obj.hTask{1}.stop();
                delete(obj.hTask{1});
                obj.hTask(1) = [];
            end
            
            while ~isempty(obj.hPark)
                obj.hPark{1}.stop();
                delete(obj.hPark{1});
                obj.hPark(1) = [];
            end
            
            while ~isempty(obj.hCals)
                if most.idioms.isValidObj(obj.hCals{1})
                    obj.hCals{1}.stop();
                    delete(obj.hCals{1});
                end
                obj.hCals(1) = [];
            end
        end
        
        function ziniDisableBeamsFeature(obj)
            obj.numInstances = 0;
            
            obj.powers = [];
            obj.powerLimits = [];
            
            obj.ziniDeleteTasks();
        end
    end
    
    %%%Abstract method impementations (most.Model)
    methods (Access=protected, Hidden)
        function mdlInitialize(obj)
            if obj.numInstances > 0
                obj.ziniCalibrateBeams();
            end
            
            %Property eigensets
            mdlInitialize@most.Model(obj);
        end
    end
    
    %%% Abstract method implementations (scanimage.interfaces.Component)
    methods (Hidden,Access = protected)
        function componentStart(obj)
        %   Runs code that starts with the global acquisition-start command
            if ~isempty(obj.hSI.hScan2D.mdfData.beamDaqID)
                
                obj.activeBeamDaqID = obj.hSI.hScan2D.mdfData.beamDaqID;
                obj.sharingScannerDaq = isfield(obj.hSI.hScan2D.mdfData, 'deviceNameGalvo') && strcmp(obj.mdfData.beamDaqDevices{obj.activeBeamDaqID}, obj.hSI.hScan2D.mdfData.deviceNameGalvo);
                
                assert(~obj.enablePowerBox || ~obj.hSI.hStackManager.isFastZ || ~obj.sharingScannerDaq || ((obj.powerBoxStartFrame == 1) && isinf(obj.powerBoxEndFrame)),...
                    'Time varying power box is not supported with FastZ enabled when beams and galvos are on the same DAQ.');
                
                beamIDs = obj.daqBeamIDs{obj.activeBeamDaqID};
                voltages = obj.zprpBeamsPowerFractionToVoltage(beamIDs,0);
                
                obj.updateBeamStatusFrac(beamIDs,NaN);
                obj.hPark{obj.activeBeamDaqID}.writeAnalogData(voltages);
                obj.updateBeamStatusFrac(beamIDs,ones(1,numel(beamIDs)));
                
                if ~obj.sharingScannerDaq
                    obj.configureBeamsTask();
                    if ~obj.hSI.mdfData.simulated
                        obj.hTask{obj.activeBeamDaqID}.start();
                    end
                end
            end
        end
        
        function componentAbort(obj)
        %   Runs code that aborts with the global acquisition-abort command
            %Turns off beam channel(s)
            obj.beamBufferNeedsUpdateAsync = false;
            if ~obj.sharingScannerDaq && ~isempty(obj.activeBeamDaqID)
                obj.hTask{obj.activeBeamDaqID}.abort();
            end
            obj.beamBufferUpdatingAsyncNow = false;
            obj.activeBeamDaqID = [];
            obj.sharingScannerDaq = false;
            obj.directMode = false(1,obj.totalNumBeams);
        end
    end
end

%% LOCAL
% VI: Sometimes a quite-clean calibration will fail this test -- we
% should probably prevent warning in this case. Perhaps warning is never
% needed anymore?
% AL: Clean runs should not fail this test anymore. Is nonmonotonicity a
% failure condition?
function x = zlclMonotonicize(x)
assert(isnumeric(x)&&isvector(x));
d = diff(x);
if any(d<=0)
    most.idioms.warn('SI4:zlclMonotonicize','Vector not monotonically increasing.');
end
end

function zlclAddQuantityAnnotations(ax,xPos,yPos,lbls,qtys,varargin)
axes(ax); 

for c = 1:numel(lbls)
    h = text(xPos,yPos,sprintf('%s: ',lbls{c}),'HorizontalAlignment','right',varargin{:});
    qty = qtys{c};
    if isnumeric(qty)
        formatStr = '%.2f';
    else
        formatStr = '%s';
    end
    text(xPos,yPos,sprintf(formatStr,qty),'HorizontalAlignment','left',varargin{:});
    ext = get(h,'Extent');
    dyPos = ext(end);
    yPos = yPos - dyPos;
end

end

function s = ziniInitPropAttributes()

s = struct;

s.powerLimits = struct('Attributes',{{'nonnegative' 'finite' 'vector'}},'AllowEmpty',1);
s.flybackBlanking = struct('Classes','binaryflex');
s.directMode = struct('Classes','binarylogical','Attributes','vector','AllowEmpty',1);
s.interlaceDecimation = struct('Attributes',{{'positive' 'vector'}},'AllowEmpty',1);
s.interlaceOffset = struct('Attributes',{{'nonnegative' 'vector'}},'AllowEmpty',1);
s.lengthConstants = struct('Attributes',{{'positive' 'vector'}},'AllowEmpty',1);
s.pzAdjust = struct('Classes','binarylogical','Attributes','vector','AllowEmpty',1);
s.stackUseStartPower = struct('Classes','binaryflex','Attributes','scalar');
s.stackUserOverrideLz = struct('Classes','binaryflex','Attributes','scalar');
s.powerBoxes = struct();
s.enablePowerBox = struct('Classes','binaryflex');
s.powerBoxStartFrame = struct('Attributes',{{'scalar','finite','positive','integer'}});
s.powerBoxEndFrame = struct('Attributes',{{'scalar','nonnegative'}});
s.pzCustom = struct('Attributes',{{'positive' 'vector'}},'AllowEmpty',1);
end


%--------------------------------------------------------------------------%
% Beams.m                                                                  %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
