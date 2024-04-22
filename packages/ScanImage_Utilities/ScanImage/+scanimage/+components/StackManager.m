classdef StackManager < scanimage.interfaces.Component
    % StackManager
    % Manages properties and functionality for volume configurations and acquisitions

    %% USER PROPS
    properties (SetObservable)
        framesPerSlice = 1;                 % Number of frames to acquire at each z-depth during each acquistion for a slow stack
        numSlices = 1;                      % Number of independent z-depths to image during each acquisition

        stackZStepSize=1;                   % distance in microns to travel for each stack step. Used for slow stack and FastZ volumes
        stackReturnHome=true;               % if true, motor returns to original z-position after stack
        stackStartCentered=false;           % if true, the current z-position is considered the stack center rather than the stack beginning.
        stackZStartPos=nan;                 % z-position from Motor::stack panel; does NOT apply to all acqs. This position is _relative to hMotor's relative origin_. It is _not_ in absolute coords.
        stackZEndPos=nan;                   % z-position from Motor::stack panel; does NOT apply to all acqs. This position is _relative to hMotor's relative origin_. It is _not_ in absolute coords.
            
        shutterCloseMinZStepSize = 0;       % Minimum stackZStepSize, in um, above which shutter will be closed while waiting for move to complete.
        stageDependentZs = false;           % Include the motor state position in computing of z series
        slowStackWithFastZ = false;         % Use the has z actuator for slow stacks
        
        stepSizeLock = false;
    end
    
    properties (SetObservable)
        zPowerReference = 0;                % z, where the beam power was defined. This z is regarded as point 0 for pzAdjust
        zs = 0;                             % Array indicating what z depths will be imaged for the next volume acquisition
    end
    
    properties (SetObservable, Transient)
        stackSlicesDone = 0;                % Number of slices completed in current acquisition
    end
    
    %% FRIEND PROPS
    properties (SetObservable, Dependent, Hidden)
        slicesPerAcq;                       % Number of independent z-depths that will be imaged during each acquisition
    end
    
    %% INTERNAL PROPS
    %%% ABSTRACT PROPERTY REALIZATION (most.Model)
    properties (Hidden,SetAccess=protected)
        mdlPropAttributes = ziniInitPropAttributes();
        mdlHeaderExcludeProps = {};
    end
    
    %%% ABSTRACT PROPERTY REALIZATION (scanimage.interfaces.Component)
    properties (SetAccess = protected, Hidden)
        numInstances = 1;                   % StackManager manages FastZ and Motors. 
    end
    
    properties (Constant, Hidden)
        COMPONENT_NAME = 'StackManager';                 % [char array] short name describing functionality of component e.g. 'Beams' or 'FastZ'
        PROP_TRUE_LIVE_UPDATE = {};                      % Cell array of strings specifying properties that can be set while the component is active
        PROP_FOCUS_TRUE_LIVE_UPDATE = {'stackZStartPos','stackZEndPos','zs','zPowerReference'};                % Cell array of strings specifying properties that can be set while focusing
        DENY_PROP_LIVE_UPDATE = {'numSlices','slicesPerAcq','stackZStepSize','framesPerSlice',...
                                 'stackReturnHome','stackStartCentered','stackZStepSize'}; % Cell array of strings specifying properties for which a live update is denied (during acqState = Focus)
        FUNC_TRUE_LIVE_EXECUTION = {};                   % Cell array of strings specifying functions that can be executed while the component is active
        FUNC_FOCUS_TRUE_LIVE_EXECUTION = {};             % Cell array of strings specifying functions that can be executed while focusing
        DENY_FUNC_LIVE_EXECUTION = {};                   % Cell array of strings specifying functions for which a live execution is denied (during acqState = Focus)
    end
    
    %%%
    properties (Hidden)
        slowZCachedStartPosition;
        stackSlowArmed=false;                   % True if slow stack armed, false if not (used by timerfcn).
        stackLastStartEndPositionSet = nan;     % Cache of last position set to stackZStartPos/stackZEndPos. Used to throw warning re: running stack with possibly stale start/end pos.
    end
    
    properties (Hidden, SetAccess=private)
        fZs;
        hMtrListener;
    end

    properties (Hidden, Dependent)
        isSlowZ;                            % logical; if true, current props specify a slow stack acquisition on GRAB/LOOP
        isFastZ;                            % logical; if true, current props specify a fast stack acquisition on GRAB/LOOP
        stackStartEndPointsDefined;         % logical; if true, stackZStartPos, stackZEndPos are defined (non-nan)
        slowStackSlicesDone;
    end
    
    %% LIFECYCLE
    methods
        function obj = StackManager(hSI)
            obj = obj@scanimage.interfaces.Component(hSI);
        end
        
        function delete(obj)
            delete(obj.hMtrListener);
        end
    end
    
    methods (Access = protected, Hidden)
        function mdlInitialize(obj)
            mdlInitialize@most.Model(obj);
            
%             obj.hMtrListener = addlistener(obj.hSI.hMotors,'motorPosition','PostGet',@(varargin)obj.motorPosChanged);
        end
    end
    
    %% PROP ACCESS
    methods        
        function set.zs(obj,val)
            val = obj.validatePropArg('zs',val);
            
            if obj.componentUpdateProperty('zs',val)
                obj.zs = val;
            end
        end
        
        function set.zPowerReference(obj,val)
            val = obj.validatePropArg('zPowerReference',val);
            
            if obj.componentUpdateProperty('zPowerReference',val)
                obj.zPowerReference = val;
            end
        end
                
        function val = get.isFastZ(obj)
            val = obj.hSI.hFastZ.enable && ~obj.hSI.hRoiManager.isLineScan; % GJ: removed condition obj.slicesPerAcq>1 && ~strcmpi(obj.hSI.acqState,'focus') to enable motion correction using FastZ on a single slice
        end
        
        function val = get.isSlowZ(obj)
            val = obj.slicesPerAcq > 1 && ~obj.hSI.hFastZ.enable && ~strcmpi(obj.hSI.acqState,'focus') && ~obj.hSI.hRoiManager.isLineScan;
        end
        
        function set.framesPerSlice(obj,val)
            if ~isinf(val) || val < 0
                val = obj.validatePropArg('framesPerSlice',val);
            end
            
            if obj.componentUpdateProperty('framesPerSlice',val)
                if obj.hSI.hFastZ.enable && ~obj.hSI.hRoiManager.isLineScan
                    val = 1;
                end
                
                obj.framesPerSlice = val;
                obj.hSI.hScan2D.logAverageFactor = obj.hSI.hScan2D.logAverageFactor;
                obj.hSI.framesPerAcq = nan;
            end
            
            obj.updateZSeries();
        end
        
        function v = get.slicesPerAcq(obj)
            if obj.hSI.hFastZ.enable && strcmp(obj.hSI.hFastZ.waveformType,'step') && obj.hSI.hFastZ.useArbitraryZs
                v = numel(obj.hSI.hFastZ.userZs);
            else
                v = obj.numSlices;
            end
        end
        
        function set.slicesPerAcq(obj,val)
            if isnan(val)
                return;
            elseif obj.hSI.hFastZ.enable && strcmp(obj.hSI.hFastZ.waveformType,'step') && obj.hSI.hFastZ.useArbitraryZs
                if obj.mdlInitialized
                    most.idioms.warn('Arbitrary Zs are specified. To change the number of slices, change the z series.');
                end
            else
                obj.numSlices = val;
                obj.hSI.framesPerAcq = nan;
            end
        end
        
        function set.numSlices(obj,val)
            val = obj.validatePropArg('numSlices',val);
            
            if obj.componentUpdateProperty('numSlices',val)
                if isnan(val)
                    val = 1;
                end
                
                obj.numSlices = val;
                
                %Side effects
                if obj.stackStartEndPointsDefined && ~obj.hSI.hFastZ.enable && val >= 2
                    % Don't set stepsize to Inf if numSlices==1, this is
                    % potentially dangerous. Leave it at its previous value.
                    if obj.stepSizeLock
                        desiredNumSlices = obj.zprpStackComputeNumSlices;
                        if val ~= desiredNumSlices
                           obj.numSlices = desiredNumSlices;
                        end
                    else
                        stepsize = obj.zprpStackComputeZStepSize();
                        if ~isequaln(stepsize,obj.stackZStepSize)
                            obj.stackZStepSize = stepsize;
                        end
                    end
                end
                
                obj.updateZSeries();
            end
        end
        
        function set.stageDependentZs(obj,v)
            v = obj.validatePropArg('stageDependentZs',v);
            if obj.componentUpdateProperty('stageDependentZs',v)
                obj.stageDependentZs = v;
                obj.updateZSeries();
            end
        end
        
        function v = get.stackStartEndPointsDefined(obj)
            v = ~isnan(obj.stackZStartPos) & ~isnan(obj.stackZEndPos);
        end
        
        function set.stackZStartPos(obj,val)
            val = obj.validatePropArg('stackZStartPos',val);
            if obj.componentUpdateProperty('stackZStartPos',val)
                obj.stackZStartPos = val;
                if obj.stackStartEndPointsDefined && ~obj.hSI.hFastZ.enable && obj.slicesPerAcq >= 2
                    if obj.stepSizeLock
                         obj.numSlices = obj.zprpStackComputeNumSlices();
                    else
                        obj.stackZStepSize = obj.zprpStackComputeZStepSize();
                    end
                end
                obj.stackLastStartEndPositionSet = val; % does the right thing if val is nan (val==nan functionally means "clear the starting pos")
            end
            
            obj.updateZSeries();
        end
        
        function set.stackZEndPos(obj,val)
            val = obj.validatePropArg('stackZEndPos',val);
            if obj.componentUpdateProperty('stackZEndPos',val)
                obj.stackZEndPos = val;
                if obj.stackStartEndPointsDefined && ~obj.hSI.hFastZ.enable && obj.slicesPerAcq >= 2
                    if obj.stepSizeLock
                        obj.numSlices = obj.zprpStackComputeNumSlices();
                    else
                        obj.stackZStepSize = obj.zprpStackComputeZStepSize();
                    end
                end
                obj.stackLastStartEndPositionSet = val; % does the right thing if val is nan
            end
            
            obj.updateZSeries();
        end
        
        function set.stackReturnHome(obj,val)
            val = obj.validatePropArg('stackReturnHome',val);
            if obj.componentUpdateProperty('stackReturnHome',val)
                obj.stackReturnHome = val;
            end
        end
        
        function set.stackStartCentered(obj,val)
            val = obj.validatePropArg('stackStartCentered',val);
            if obj.componentUpdateProperty('stackStartCentered',val)
                obj.stackStartCentered = val;
            end
            
            obj.updateZSeries();
        end
        
        function set.stackZStepSize(obj,val)
            if obj.componentUpdateProperty('stackZStepSize',val)
                val = obj.validatePropArg('stackZStepSize',val);
                
                obj.stackZStepSize = val;
                if obj.stackStartEndPointsDefined && ~obj.hSI.hFastZ.enable
                    numSlice = obj.zprpStackComputeNumSlices();
%                     obj.zprvSetInternal('numSlices',numSlice);
                    obj.numSlices = numSlice;
                end
            end
            
            obj.updateZSeries();
        end
        
        function set.slowStackWithFastZ(obj,v)
            if obj.componentUpdateProperty('slowStackWithFastZ',v)
                v = obj.validatePropArg('slowStackWithFastZ',v);
                obj.slowStackWithFastZ = v && obj.hSI.hFastZ.hasFastZ;
            end
        end
        
        function v = get.slowStackSlicesDone(obj)
            if obj.isSlowZ
                v = obj.stackSlicesDone;
            else
                v = 0;
            end
        end
    end
    %% USER METHODS
    methods
        function setStackStart(obj)
            % hSI.hStackManager.setStackStart()
            % Save curent motor Z position and beam power level as stack start point
            
            obj.stackZStartPos = obj.hSI.hMotors.stackCurrentMotorZPos;
            obj.hSI.hBeams.stackStartPower = obj.hSI.hBeams.powers;
        end
        
        function setStackEnd(obj)
            % hSI.hStackManager.setStackEnd()
            % Save curent motor Z position and beam power level as stack end point
            
            obj.stackZEndPos = obj.hSI.hMotors.stackCurrentMotorZPos;
            obj.hSI.hBeams.stackEndPower = obj.hSI.hBeams.powers;
        end
        
        function clearStackStartEnd(obj)
            % hSI.hStackManager.clearStackStartEnd()
            % Clear any saved stack start & end points
            
            obj.stackZStartPos = nan;
            obj.hSI.hBeams.stackStartPower = nan; % todo multibeam
            obj.stackZEndPos = nan;
            obj.hSI.hBeams.stackEndPower = nan; % todo multibeam
        end
        
        function clearStackEnd(obj)
            % hSI.hStackManager.clearStackEnd()
            % Clear saved stack end point (if set)
            
            obj.stackZEndPos = nan;
            obj.hSI.hBeams.stackEndPower = nan; % todo multibeam
        end
        
        function lockedStackParams(obj)
            stackStart = obj.stackZStartPos;
            stackEnd = obj.stackZEndPos;
            slices = obj.slicesPerAcq;
            steps = obj.stackZStepSize;
            
            stepSize = zprpStackComputeZStepSize();
            
            if ~isequaln(stepSize, steps)
                
            else
                
            end
        end
    end
    
    %% FRIEND METHODS
    methods (Hidden)
        function zprvResetHome(obj)
            %Reset home motor/fastZ/beam positions/powers
            obj.hSI.hMotors.zprvResetHome();
            obj.hSI.hBeams.zprvResetHome();
        end
        
        function zprvGoHome(obj)
            %Go to home motor/fastZ/beam positions/powers, as applicable
            obj.hSI.hMotors.zprvGoHome();
            obj.hSI.hBeams.zprvGoHome();
        end
        
        function motorPosChanged(obj)
            if ~(obj.active || obj.hSI.active || obj.hSI.acqInitInProgress)
                obj.updateZSeries();
            end
        end
        
        function updateZSeries(obj)
            if ~obj.mdlInitialized
                return
            end
            
            if obj.hSI.hRoiManager.isLineScan
                obj.zs = 0;
                obj.fZs = 0;
            end
            
            if obj.stageDependentZs
                z0 = obj.hSI.hMotors.motorPosition(3);
                fz = -obj.hSI.hMotors.motorPosition(3);
            else
                z0 = 0;
                fz = 0;
            end
            
            if obj.stackStartEndPointsDefined
               z0 = obj.stackZStartPos; 
            end
            
            if obj.hSI.hFastZ.hasFastZ && ~isnan(obj.hSI.hFastZ.positionTarget)
                z0 = z0 + obj.hSI.hFastZ.positionTarget;
            end
            
            obj.zPowerReference = z0;
             
            if obj.isFastZ && strcmp(obj.hSI.hFastZ.waveformType,'step') && obj.hSI.hFastZ.useArbitraryZs
                obj.zs = obj.hSI.hFastZ.userZs;
                obj.fZs = obj.hSI.hFastZ.userZs;
            else
                nz = obj.slicesPerAcq;
                dz = obj.stackZStepSize;
                
                if obj.isFastZ || obj.isSlowZ
                    if obj.stackStartCentered
                        z0 = z0 - (dz*(nz-1))/2;
                    end
                    
                    zs_=linspace(z0,z0+dz*(nz-1),nz);
                else
                    zs_ = z0;
                end
                
                obj.zs = zs_;
                obj.fZs = zs_+fz;
            end
        end
        
        function stackDone = endOfAcquisition(obj)
            stackDone = ~(obj.isSlowZ && obj.stackSlicesDone < obj.slicesPerAcq);
            if obj.isSlowZ
                if stackDone
                    %Return to stack start position for next stack.
                    obj.hSI.hMotors.stackCurrentMotorZPos = obj.slowZCachedStartPosition;
                    obj.hSI.hUserFunctions.notify('motorPositionUpdate');
                    
                    %Set slow stack is as disarmed.
                    obj.stackSlowArmed = false;
                else
                    obj.updateStackData
                end
            end
        end
        
        function updateStackData(obj)
            if obj.isSlowZ
                %Block on motor move to next z position.
                try
                    obj.stackMotorMoveWaitForFinish();
                catch ME
                    most.idioms.dispError([ME.message '\n']);
                end
                obj.hSI.hUserFunctions.notify('motorPositionUpdate'); %Signal potential motor position update

                %Update AOs for next slice
                obj.hSI.hWaveformManager.updateWaveforms();
                obj.hSI.hScan2D.updateSliceAO();
                obj.hSI.hBeams.updateSliceAO();
                obj.hSI.hFastZ.updateSliceAO();

                %Open shutters immediately after move completes.
                if abs(obj.stackZStepSize) > obj.shutterCloseMinZStepSize
                    obj.hSI.hShutters.shuttersTransition(obj.hSI.hScan2D.mdfData.shutterIDs,true,true); % Opens linked shutters
                end
            end
        end
        
        function stackMotorMoveStartRelative(obj,pos)
            if obj.slowStackWithFastZ
                obj.hSI.hFastZ.moveToNextSlice(pos);
            else
                obj.hSI.hMotors.moveStartRelative([nan nan pos]);
            end
        end
        
        function stackMotorMoveWaitForFinish(obj)
            if obj.slowStackWithFastZ
                obj.hSI.hFastZ.hStage.moveWaitForFinish();
            else
                obj.hSI.hMotors.moveWaitForFinish(3);
            end
        end
    end
    
    %% INTERNAL METHODS 
    methods (Access = protected, Hidden)
        function componentStart(obj)
        %   Runs code that starts with the global acquisition-start command
            obj.zprvResetHome(); %Reset motor/fastZ/beam positions/powers
            obj.updateZSeries(); % Recompute zseries prior to grab
            
            if obj.isSlowZ
                assert(~obj.slowStackWithFastZ || obj.hSI.hFastZ.hasFastZ, 'The current imaging system does not have a FastZ actuator. Disable ''slowStackWithFastZ'' option.');
                %******************************************************
                % MOTORS
                %******************************************************
                if obj.stackReturnHome
                    obj.hSI.hMotors.zprvSetHome();
                    obj.hSI.hBeams.zprvSetHome();
                end
                
                totalStackDz = (obj.slicesPerAcq-1)*obj.stackZStepSize;
                preStartZIncrement = []; %#ok<NASGU> % This is the size of the motor move we will execute pre-stack. This is set in the next block.
                
                % Deal with starting zpos
                if ~isnan(obj.stackZStartPos)
                    if obj.stackStartCentered
                        warnst = warning('off','backtrace');
                        warning('SI:ignoringStackStartCentered',...
                            'Starting z-position for stack has been set. Stack will not be centered around the current zposition.');
                        warning(warnst);
                    end

                    % Throw a warning if the current position does
                    % not match stackLastStartEndPositionSet or the
                    % calculated stack final position. When this
                    % condition holds, it is probable that the user
                    % has moved the motor position after setting up
                    % (and possibly running) a stack. In this
                    % situation the stackZStart/EndPos info may
                    % potentially be stale.
                    currStackZPosn = obj.hSI.hMotors.stackCurrentMotorZPos;
                    stackFinalZPos = obj.stackZStartPos + (obj.slicesPerAcq-1)*obj.stackZStepSize; % in this codepath, the stack starting pos is obj.stackZStartPos
                    if ~isequal(currStackZPosn,obj.stackLastStartEndPositionSet) && ...
                            ~isequal(currStackZPosn,stackFinalZPos) % this condition is for when stackZStartPos is set last, and stackReturnHome is false.
                        warnst = warning('off','backtrace');
                        warning('SI:stackWithPotentiallyStaleStartEndPos',...
                            'Motor has moved since last stack start/end position was set.');
                        warning(warnst);
                    end

                    preStartZIncrement = obj.stackZStartPos-currStackZPosn;
                    obj.hSI.hMotors.stackCurrentMotorZPos = obj.stackZStartPos;
                    obj.slowZCachedStartPosition = obj.stackZStartPos;
                elseif obj.stackStartCentered
                    preStartZIncrement = -totalStackDz/2;
                    posn = obj.hSI.hMotors.stackCurrentMotorZPos;
                    posn = posn + preStartZIncrement;
                    obj.hSI.hMotors.stackCurrentMotorZPos = posn;
                    obj.slowZCachedStartPosition = posn;
                else
                    % none; start stack at current zpos
                    preStartZIncrement = 0.0;
                    obj.slowZCachedStartPosition = obj.hSI.hMotors.stackCurrentMotorZPos;
                end
                
                obj.hSI.hUserFunctions.notify('motorPositionUpdate'); %Signal potential motor position update
                
                %******************************************************
                % BEAMS
                %******************************************************
                %Only handle beams if we have any in the rig.
                if obj.hSI.hBeams.numInstances > 0 && any(obj.hSI.hBeams.pzAdjust)
                    % deal with starting power
                    if obj.hSI.hBeams.stackUseStartPower && obj.hSI.hBeams.stackStartPowerDefined
                        % use stack starting power; ignore any
                        % correction due to preStartZIncrement and Lz
                        obj.hSI.hBeams.zprvSetInternal('powers',obj.hSI.hBeams.stackStartPower);
                    else
                        % correct starting power using acquisition Lz (could be overridden, etc)
%                         obj.hSI.hBeams.zprvBeamsDepthPowerCorrection(obj.zPowerReference,obj.zs(1),obj.hSI.hBeams.acqLengthConstants);
                    end
                    
                    % throw a warning if the final power will exceed 100%
                    beamPwrs = obj.hSI.hBeams.powers; % beam powers have been initialized to stack-start values
                    for beamIdx = 1:length(beamPwrs)
                        finalPwrs = obj.hSI.hBeams.zprvBeamsDepthPowerCorrection(beamIdx,beamPwrs(beamIdx), 0, totalStackDz, obj.hSI.hBeams.acqLengthConstants(beamIdx));
                    end
                    if any(finalPwrs(:)>100)
                        warnst = warning('off','backtrace');
                        warning('SI:beamPowerWillSaturate',...
                            'Beam power correction will cause one or more beams to exceed 100%% power at or before stack end. Beam power will saturate at 100%%.');
                        warning(warnst);
                    end
                end
            end
        end
        
        function componentAbort(obj)
        %   Runs code that aborts with the global acquisition-abort command
            try
                %Wait for any pending moves to finish.
                if obj.hSI.hMotors.numInstances
                    obj.stackMotorMoveWaitForFinish();
                end
                
                %Move all motors to home position.
                if obj.stackReturnHome
                    obj.zprvGoHome();
                    obj.hSI.hUserFunctions.notify('motorPositionUpdate');
                end
                
                obj.zprvResetHome(); %Reset motor/fastZ/beam positions/powers
                
            catch ME
                most.idioms.reportError(ME)
            end
        end
    end
    
    methods (Access = private)        
        function val = zprpStackComputeZStepSize(obj)
            dz = obj.stackZEndPos - obj.stackZStartPos;
            val = dz/(obj.slicesPerAcq-1);
        end
        
        function val = zprpStackComputeNumSlices(obj)
            dz = obj.stackZEndPos - obj.stackZStartPos;
            if dz==0 && obj.stackZStepSize==0
                % edge case
                val = 1;
            else
                if obj.stepSizeLock
                    val = ceil(dz/obj.stackZStepSize)+1;
                else
                    val = floor(dz/obj.stackZStepSize)+1;
                end
            end
        end
    end
    %% USER EVENTS
    %% FRIEND EVENTS
    %% INTERNAL EVENTS
    
end

%% LOCAL
function s = ziniInitPropAttributes()
%At moment, only application props, not pass-through props, stored here -- we think this is a general rule
%NOTE: These properties are /ordered/..there may even be cases where a property is added here for purpose of ordering, without having /any/ metadata.
%       Properties are initialized/loaded in specified order.
%
s = struct();

s.framesPerSlice = struct('Classes','numeric','Attributes',{{'scalar' 'positive' 'integer' 'finite'}});
s.slicesPerAcq = struct('Classes','numeric','Attributes',{{'scalar','positive'}},'DependsOn',{{'hSI.hFastZ.waveformType' 'hSI.hFastZ.enable' 'hSI.hFastZ.useArbitraryZs' 'hSI.hFastZ.userZs' 'numSlices'}});
s.zs = struct('Classes','numeric','Attributes',{{'vector'}});
s.zPowerReference = struct('Classes','numeric','Attributes',{{'scalar','nonnan','finite'}});
s.stageDependentZs = struct('Classes','binaryflex','Attributes','scalar');

%%% Stack props
s.numSlices = struct('Classes','numeric','Attributes',{{'scalar','positive'}});
s.stackZStepSize = struct('Classes','numeric','Attributes','scalar');
s.stackZStartPos = struct('Classes','numeric','Attributes','scalar');
s.stackZEndPos = struct('Classes','numeric','Attributes','scalar');
s.stackReturnHome = struct('Classes','binaryflex','Attributes','scalar');
s.stackStartCentered = struct('Classes','binaryflex','Attributes','scalar');
s.slowStackWithFastZ = struct('Classes','binaryflex','Attributes','scalar');
end


%--------------------------------------------------------------------------%
% StackManager.m                                                           %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
