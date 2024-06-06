classdef Motors < scanimage.interfaces.Component & most.HasMachineDataFile & most.HasClassDataFile 
    % Motors    Functionality to manage and control motors

    %% USER PROPS
    properties (SetObservable)
        motorStepLimit = Inf;                   %scalar, numeric: Maximally allowed step size for all axes. If unused, set to Inf
        userDefinedPositions = repmat(struct('name','','coords',[]),0,1); % struct containing positions defined by users
    end
    
    properties (SetObservable, GetObservable, Transient)
        motorFastMotionThreshold = 100;         %Distance, in um, above which motion will use the 'fast' velocity for controller
        motorPosition;                          %1x3 array specifying motor position (in microns)
        motorPositionTarget;
        scanimageToMotorTF = eye(4);
        backlashCompensation = [0 0 0];         %numeric, vector of 3: compensates the backlash of the stage by overshooting the target position and moving to the targetPosition consistently from the same side; values determine the amount of overshoot
    end
    
    properties (Dependent,Hidden)
        positionUnits;
        motorPositionMeter;
    end
    
    %% FRIEND PROPS
    properties (SetObservable, Transient) % Transient because saved in class data file
        motorToRefTransform = nan(3);
    end
    
    properties (SetObservable,Dependent,Transient)
        azimuth;
        elevation;
    end
    
    properties (SetObservable,Dependent,SetAccess = private)
        motorToRefTransformValid;
        motorToRefTransformAbsolute;
        dimNonblockingMoveInProgress;
        nonblockingMoveInProgress;
    end
    
    properties (Hidden,SetObservable,SetAccess=?scanimage.interfaces.Class)
        hMotor = scanimage.components.motors.StageController.empty;
        hErrorCallBack;                         %Function handle for Motor Error (should be set by SI.m)
        
        stackCurrentMotorZPos;                  %z-position of stack motor
        stackHomeZPos                           %cached home position to return to at end of stack
        
        classDataFileName;
        
        motorDimMappingMtr = [0 0 0];
        motorDimMappingDim = [1 2 3];
        motorDimMappingInvert = [0 0 0];
        fakeMotorPosition = [0 0 0];
        fakeMotorOrigin = [0 0 0];
        
        calibrationPoints = cell(0,2);
    end
    
    %%% ABSTRACT PROPERTY REALIZATIONS (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'Motors';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
        
        mdfDefault = defaultMdfSection();
    end
    
    %%% ABSTRACT PROPERTY REALIZATION (most.Model)
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = ziniInitPropAttributes();
        mdlHeaderExcludeProps = {'hMotor','hMotorZ'};                            
    end
    
    %%% ABSTRACT PROPERTY REALIZATION (scanimage.interfaces.Component)
    properties (SetAccess = protected, Hidden)
        numInstances = 0;
    end
    
    properties (Constant, Hidden)
        COMPONENT_NAME = 'Motors';                                         % [char array] short name describing functionality of component e.g. 'Beams' or 'FastZ'
        PROP_TRUE_LIVE_UPDATE = {'motorPosition','stackCurrentMotorZPos'}; % Cell array of strings specifying properties that can be set while the component is active
        PROP_FOCUS_TRUE_LIVE_UPDATE = {};                                  % Cell array of strings specifying properties that can be set while focusing
        DENY_PROP_LIVE_UPDATE = {'motorFastMotionThreshold'};              % Cell array of strings specifying properties for which a live update is denied (during acqState = Focus)
        
        FUNC_TRUE_LIVE_EXECUTION = {'motorZeroSoft','zprvGoHome',...       % Cell array of strings specifying functions that can be executed while the component is active
            'zprvResetHome' 'zprvSetHome'};
        FUNC_FOCUS_TRUE_LIVE_EXECUTION = {'motorZeroXYZ','motorZeroXY','motorZeroZ','motorClearZeroSoft'};         % Cell array of strings specifying functions that can be executed while focusing
        DENY_FUNC_LIVE_EXECUTION = {'saveUserDefinedPositions' 'loadUserDefinedPositions'};    % Cell array of strings specifying functions for which a live execution is denied (during acqState = Focus)
    end
    
    %% LIFECYCLE
    methods (Hidden)
        function obj = Motors(hSI)
            obj = obj@scanimage.interfaces.Component(hSI);
            
            % Determine CDF name and path
            if isempty(obj.hSI.classDataDir)
                pth = most.util.className(class(obj),'classPrivatePath');
            else
                pth = obj.hSI.classDataDir;
            end
            classNameShort = most.util.className(class(obj),'classNameShort');
            obj.classDataFileName = fullfile(pth, [classNameShort '_classData.mat']);
            
            % Initialize class data file (ensure props exist in file)
            obj.zprvEnsureClassDataFileProps();
            
            % Initialize the scan maps (from values in Class Data File)
            obj.loadClassData();
            
            if isfield(obj.mdfData,'motorControllerType')
                fprintf(2,'MDF settings for Motors are outdated. Exit ScanImage and run the configuration editor to migrate the settings.\n');
                return;
            elseif isempty([obj.mdfData.motors.controllerType])
                fprintf(1,'No motor controller specified in Machine Data File. Feature disabled.\n');
                obj.numInstances = 1; % allow fake operation
                return;
            else
                obj.mdfData.motors(arrayfun(@(s)isempty(s.controllerType),obj.mdfData.motors)) = [];
            end
            
            % Check for duplicates or invalid dims in motor dimension mapping
            dims = strrep([obj.mdfData.motors.dimensions],'-','');
            assert(all(ismember(dims,'XYZ')) && (length(unique(dims)) == length(dims)),'Invalid motor dimension configuration.');
            
            % Initialize motor controller objects
            for i = 1:numel(obj.mdfData.motors)
                mtr = obj.mdfData.motors(i);
                obj.hMotor(i) = scanimage.components.motors.StageController(mtr);
                
                % assign the mappings
                dims = uint8(mtr.dimensions)-87;
                for j = 1:length(dims)
                    if dims(j) > 0
                        obj.motorDimMappingMtr(dims(j)) = i;
                        obj.motorDimMappingDim(dims(j)) = j;
                        
                        mtr.invertDim(end+1:length(dims)) = '+';
                        obj.motorDimMappingInvert(dims(j)) = mtr.invertDim(j) == '-'; % Looks suspect....
                    end
                end
                
                obj.hMotor(i).addlistener('LSCError',@obj.hErrorCallBack);
            end
            
            obj.numInstances = max(1,obj.numInstances);
            
        end
        
        function loadClassData(obj)
            obj.motorToRefTransform = obj.getClassDataVar('motorToRefTransform',obj.classDataFileName);
            obj.scanimageToMotorTF = obj.getClassDataVar('scanimageToMotorTF',obj.classDataFileName);
            obj.backlashCompensation = obj.getClassDataVar('backlashCompensation',obj.classDataFileName);
        end
    end
    
    methods (Access = protected, Hidden)
        function mdlInitialize(obj)
            if obj.numInstances > 0
                mdlInitialize@most.Model(obj);
            end
        end
    end
    
    %% PROP ACCESS
    methods
        % MOTOR SPECIFIC PROPERTY ACCESS METHODS
        function set.motorToRefTransform(obj,val)
            if isempty(val) || (isnumeric(val) && isscalar(val) && isnan(val))
                val = nan(3,3);
            end
            
            validateattributes(val,{'numeric'},{'size',[3,3]});
            
            if ~all(isnan(val(:))) && any(isnan(val(:)))
                error('motorToRefTransform cannot contain any NaN');
            end
            
            oldTransform = obj.motorToRefTransform;
            
            obj.motorToRefTransform = val;
            obj.setClassDataVar('motorToRefTransform',obj.motorToRefTransform,obj.classDataFileName);

            if ~isequal(oldTransform,obj.motorToRefTransform) && obj.mdlInitialized
                obj.correctObjectiveResolution();
            end
        end
        
        function set.scanimageToMotorTF(obj,val)
            validateattributes(val,{'numeric'},{'size',[4,4],'nonnan','finite'});
            obj.scanimageToMotorTF = val;
            obj.setClassDataVar('scanimageToMotorTF',obj.scanimageToMotorTF,obj.classDataFileName);
        end
        
        function val = get.motorToRefTransformValid(obj)
            T = obj.motorToRefTransform;
            val = isnumeric(T) && ~any(isnan(T(:))) && ~any(isinf(T(:)));
        end
        
        function val = get.motorToRefTransformAbsolute(obj)
            val = obj.motorToRefTransform;

            motorPosition_ = obj.motorPosition;
            if ~isempty(motorPosition_) && length(motorPosition_)>=2 && ~any(isnan(motorPosition_(1:2))) 
                T = eye(3);
                T(7:8) = motorPosition_(1:2);
                val = val/T;
            end
        end
        
        function val = get.motorPosition(obj)
            try
                vals = {obj.fakeMotorPosition obj.hMotor.positionRelative};
                val = arrayfun(@(x,y)vals{x}(y),obj.motorDimMappingMtr+1,obj.motorDimMappingDim);
            catch
                val = nan(1,3);
            end
            val = scanimage.mroi.util.xformPoints(val,obj.scanimageToMotorTF,true);
        end
        
        function val = get.positionUnits(obj)
            val = ones(1,length(obj.motorDimMappingMtr));
            
            for idx = 1:length(obj.motorDimMappingMtr)
                motorIdx = obj.motorDimMappingMtr(idx);
                if motorIdx ~= 0
                    val(idx) = obj.hMotor(motorIdx).hLSC.positionUnits;
                end
            end
        end
        
        function val = get.motorPositionMeter(obj)
            val = obj.motorPosition .* obj.positionUnits;
        end
        
        function set.motorPositionMeter(obj,val)
            val = val ./ obj.positionUnits;
            obj.motorPosition = val;
        end
        
        function val = get.motorPositionTarget(obj)
            if obj.numInstances <= 0
                val = [];
            else
                vals = {obj.fakeMotorPosition obj.hMotor.positionTarget};
                val = arrayfun(@(x,y)vals{x}(y),obj.motorDimMappingMtr+1,obj.motorDimMappingDim);
            end
        end
        
        function set.motorFastMotionThreshold(obj,val)
            val = obj.validatePropArg('motorFastMotionThreshold',val);
            if obj.componentUpdateProperty('motorFastMotionThreshold',val)
                for i=1:numel(obj.hMotor)
                    obj.hMotor(i).twoStepDistanceThreshold = val;
                end
                obj.motorFastMotionThreshold = val;
            end
        end
        
        function set.motorStepLimit(obj,val)
            val = obj.validatePropArg('motorStepLimit',val);
            assert(~isnan(val));
            obj.motorStepLimit = val;
        end
                 
        function set.motorPosition(obj,val)
            val = obj.validatePropArg('motorPosition',val);
            if obj.componentUpdateProperty('motorPosition',val) && obj.mdlInitialized
                motorsToWaitFor = obj.moveStartRelative(val);
                
                for mtr = motorsToWaitFor
                    if mtr
                        obj.hMotor(mtr).moveWaitForFinish();
                    end
                end
            end
        end
        
        function set.userDefinedPositions(obj,val)
            assert(all(isfield(val,{'name' 'coords'})), 'Invalid setting for userDefinedPositions');
            obj.userDefinedPositions = val;
        end
        
        function val = get.stackCurrentMotorZPos(obj)
            if obj.hSI.hStackManager.slowStackWithFastZ
                val = obj.hSI.hFastZ.positionTarget;
            elseif ~obj.motorDimMappingMtr(3)
                val = obj.fakeMotorPosition(3);
            elseif obj.hMotor(obj.motorDimMappingMtr(3)).stackStartReadPos
                val = obj.motorPosition(3);
            else
                val = obj.motorPositionTarget(3);
            end
        end
        
        function set.stackCurrentMotorZPos(obj,val)
%             if obj.componentUpdateProperty('stackCurrentMotorZPos',val)
                %always allow this. needed for stack operation
                if obj.hSI.hStackManager.slowStackWithFastZ
                    obj.hSI.hFastZ.positionTarget = val;
                else
                    obj.motorPosition = [nan nan val];
                end
%             end
        end
        
        function v = get.dimNonblockingMoveInProgress(obj)
            nbmp = [false obj.hMotor.nonblockingMovePending];
            v = nbmp(obj.motorDimMappingMtr+1);
        end
        
        function v = get.nonblockingMoveInProgress(obj)
            v = any(obj.dimNonblockingMoveInProgress);
        end
        
        function set.elevation(obj,val)
            if ~isnan(val)
                obj.makeCoordTransform(obj.azimuth,val);
            end
        end
        
        function val = get.elevation(obj)
            [elevation_, azimuth_] = obj.extrapolateAngles(obj.scanimageToMotorTF);
            val = elevation_;
        end
        
        function set.azimuth(obj,val)
            if ~isnan(val)
                obj.makeCoordTransform(val,obj.elevation);
            end
        end
        
        function val = get.azimuth(obj)
            [elevation_, azimuth_] = obj.extrapolateAngles(obj.scanimageToMotorTF);
            val = azimuth_;
        end
        
        function set.backlashCompensation(obj,val)
            val = obj.validatePropArg('backlashCompensation',val);
            assert(isempty(val) || isscalar(val) || (isvector(val) && length(val)==3));
            
            val = val(:)';
            
            if ~isempty(val) && isscalar(val)
                val = repmat(val,1,3);
            end
            
            obj.backlashCompensation = val;
            obj.setClassDataVar('backlashCompensation',obj.backlashCompensation,obj.classDataFileName);
        end
    end    
    
    %% USER METHODS
    methods
        function abortCalibration(obj)
            obj.calibrationPoints = cell(0,2);
        end
        
        function addCalibrationPoint(obj,motorPosition_, motion)            
            if nargin < 2 || isempty(motorPosition_)
                motorPosition_ = obj.motorPosition;
            end
            
            if nargin < 3 || isempty(motion)
                assert(strcmpi(obj.hSI.acqState,'focus'),'Motor alignment is only available during active Focus');
                
                if ~obj.hSI.hMotionManager.enable                    
                    obj.hSI.hMotionManager.activateMotionCorrectionSimple();
                end
                
                assert(~isempty(obj.hSI.hMotionManager.motionHistory),'Motion History is empty.');
                motion = obj.hSI.hMotionManager.motionHistory(end).drRef(1:2);
            end
            
            obj.calibrationPoints(end+1,:) = {motorPosition_, motion};
            
            pts = vertcat(obj.calibrationPoints{:,1});
            d = max(pts(:,3:end),[],1)-min(pts(:,3:end),[],1);
            
            if any(d > 1)
                warning('Motor alignment points are taken at different z depths. For best results, do not move the z stage during motor calibration');
            end
        end
        
        function createCalibrationMatrix(obj)
            assert(size(obj.calibrationPoints,1)>=3,'At least three calibration Points are needed to perform the calibration');
            
            motorPoints = vertcat(obj.calibrationPoints{:,1});
            if size(motorPoints,2) >= 3
                assert(all(abs(motorPoints(:,3)-motorPoints(1,3)) < 1),'All calibration points need to be taken on the same z plane and at the same rotation');
            end
            
            motorPoints = motorPoints(:,1:2);
            
            motionPoints = obj.calibrationPoints(:,2);
            motionPoints = vertcat(motionPoints{:});
            motionPoints = -motionPoints;
            
            motorPoints(:,3) = 1;
            motionPoints(:,3) = 1;
            
            motorToRefTransform_ = motionPoints' * pinv(motorPoints');
            motorCenterPt = scanimage.mroi.util.xformPoints([0,0],motorToRefTransform_,true);
            
            T = eye(3);
            T(7:8) = -motorCenterPt;
            
            obj.abortCalibration();
            obj.motorToRefTransform = motorToRefTransform_/T;
        end
        
        function resetCalibrationMatrix(obj)
            obj.motorToRefTransform = nan(3);
        end
        
        function correctObjectiveResolution(obj,silent)
            if nargin<2 || isempty(silent)
                silent = false;
            end
            
            if isempty(obj.motorToRefTransform) || any(isnan(obj.motorToRefTransform(:)))
                return
            end
            
            objectiveResolution_ = norm(scanimage.mroi.util.xformPoints([1 1]/sqrt(2),obj.motorToRefTransform,true));
            
            if isequal(obj.hSI.objectiveResolution,objectiveResolution_)
                return; % nothing to do
            end
            
            if ~silent
                button = questdlg(...
                    sprintf('New objective resolution detected: %.3f microns/degree.\nDo you want to set this resolution as default?',objectiveResolution_),...
                    'Objective resolution','Yes');
                if ~strcmpi(button,'Yes');
                    return
                end
            end
            
            obj.hSI.objectiveResolution = objectiveResolution_;
        end
        
        function tf = makeCoordTransform(obj,azimuth,elevation)
            if ischar(azimuth)
                azRad = pi/180 * str2double(azimuth);
            elseif isnumeric(azimuth)
                azRad = pi/180 * azimuth;
            else
                most.idioms.warn('Invalid Value for argument azimuth');
            end
            
            if ischar(elevation)
                elRad = pi/180 * str2double(elevation);
            elseif isnumeric(elevation)
                elRad = pi/180 * elevation;
            else
                most.idioms.warn('Invalid Value for argument elevation');
            end
            
            tf = makehgtform('zrotate',azRad,'yrotate',elRad);
            
            invert = obj.motorDimMappingInvert;
            for i=1:length(invert)
                if invert(i) == 1 && tf(i,i) > 0
                    tf(i, 1:end-1) =  tf(i, 1:end-1)*-1;
                elseif invert(i) == 1 && tf(i,i) < 0
                    % Already inverted
                elseif invert(i) == 0 && tf(i,i) > 0
                    % Already NOT inverted
                elseif invert(i) == 0 && tf(i,i) < 0
                    tf(i, 1:end-1) =  tf(i, 1:end-1)*-1;
                end
            end
            obj.scanimageToMotorTF = tf;
        end
        
        function [Elevation, Azimuth] = extrapolateAngles(obj,transform)
            % Make a copy of the transform
            temp_Transform = transform;
            
            % Primitively revomve any shift of the transform origin
            motor_origin_motorSpace = [0 0 0];
            motor_origin_ScanImageSpace = scanimage.mroi.util.xformPoints(motor_origin_motorSpace,temp_Transform,true);
            offsetT = eye(4);
            offsetT(1:3,4) = motor_origin_ScanImageSpace;
            temp_Transform = temp_Transform * offsetT;
            
            % Establish test coords
            test_coords = [0 0 15];
            unitZ = [0 0 1];
            unitY = [0 1 0];
            unitX = [1 0 0];
            test_tf_coords = scanimage.mroi.util.xformPoints(test_coords,temp_Transform);
            test_tf_coords_XY_proj = test_tf_coords;
            test_tf_coords_XY_proj(end) = 0;
            test_tf_coords_ZX_proj = test_tf_coords;
            test_tf_coords_ZX_proj(2) = 0;

            % Calculate angular distance of ray drawn to transformed test
            % coord from the axis
            distZ = 180/pi * atan2(norm(cross(unitZ,test_tf_coords)),dot(unitZ,test_tf_coords));
            distZX = 180/pi * atan2(norm(cross(unitX,test_tf_coords_ZX_proj)),dot(unitX,test_tf_coords_ZX_proj));

            % Convert anglar distance to cartesian angular coordinates
            if distZX <= 90
                Elevation = 180/pi * atan2(norm(cross(unitZ,test_tf_coords)),dot(unitZ,test_tf_coords));
            end
            if distZX > 90
                if distZ >= 90
                    Elevation = 180/pi * atan2(norm(cross(unitZ,test_tf_coords)),dot(unitZ,test_tf_coords)) + 90;
                elseif distZ < 90
                    Elevation = 180/pi * atan2(norm(cross(unitZ,test_tf_coords)),dot(unitZ,test_tf_coords)) + 180;
                end
            end

            % Calculate angular distance of ray drawn to transformed test
            % coord from the axis
            distY = 180/pi * atan2(norm(cross(unitY,test_tf_coords_XY_proj)),dot(unitY,test_tf_coords_XY_proj));
            distX = 180/pi * atan2(norm(cross(unitX,test_tf_coords_XY_proj)),dot(unitX,test_tf_coords_XY_proj));
            
            % Convert anglar distance to cartesian angular coordinates
            if distY <= 90
                Azimuth = 180/pi * atan2(norm(cross(unitX,test_tf_coords_XY_proj)),dot(unitX,test_tf_coords_XY_proj));
            end
            if distY > 90
                if distX >= 90
                    Azimuth = 180/pi * atan2(norm(cross(unitY,test_tf_coords_XY_proj)),dot(unitY,test_tf_coords_XY_proj)) + 90;
                elseif distX < 90
                    Azimuth = 180/pi * atan2(norm(cross(unitY,test_tf_coords_XY_proj)),dot(unitY,test_tf_coords_XY_proj)) + 180;
                end
            end
        end
        
        function zprvResetHome(obj)
            % zprvResetHome clears the motor home position
            %
            %   obj.zprvResetHome()   returns nothing
            
            if obj.componentExecuteFunction('zprvResetHome')
                obj.stackHomeZPos = [];
            end
        end
        
        function zprvSetHome(obj)
            % zprvSetHome Sets the motor home to the current stack's z position
            %
            %  obj.zprvSetHome()   returns nothing
            if obj.componentExecuteFunction('zprvResetHome')
                obj.stackHomeZPos = obj.stackCurrentMotorZPos;
            end
        end
        
        function zprvGoHome(obj)
            % zprvGoHome  Commands the motor to go to the home position
            %
            %  obj.zprvGoHome()
            
            if obj.componentExecuteFunction('zprvGoHome')
                if ~isempty(obj.stackHomeZPos)
                    obj.stackCurrentMotorZPos = obj.stackHomeZPos;
                end
            end
        end
        
        function zprvGoPark(obj)
            % zprvGoPark  Commands the motor to go to the park position
            %
            %  obj.zprvGoPark()
            
            if obj.componentExecuteFunction('zprvGoPark')
                % Do nothing for motors.
            end
        end

        function motorZeroXYZ(obj)
            % motorZeroXYZ   sets motor relative origin to current position for X,Y,and Z coordinates.
            %
            %  obj.motorZeroXYS()  returns nothing
            
            if obj.componentExecuteFunction('motorZeroXYZ')
                obj.motorZeroSoft([1 1 1]);
            end
        end
        
        function motorZeroXY(obj)
            % motorZeroXY sets motor relative origin to current position for X&Y coordinates.
            %
            %  obj.motorZeroXY()  returns nothing
            
            if obj.componentExecuteFunction('motorZeroXY')
                obj.motorZeroSoft([1 1 0]);
            end
        end
        
        function motorZeroZ(obj)
            % motorZeroZ  sets motor relative origin to current position for Z coordinates.
            %
            %   obj.motorZeroZ()   returns nothing
            
            if obj.componentExecuteFunction('motorZeroZ')
                obj.motorZeroSoft([0 0 1]);
            end
        end
        
        function motorClearZeroSoft(obj)
            if obj.componentExecuteFunction('motorClearZeroSoft')
                tfRescaleStackZStartEndPos = ~obj.hSI.hStackManager.slowStackWithFastZ;
                if tfRescaleStackZStartEndPos
                    if obj.motorDimMappingMtr(3)
                        origZCoord = obj.scanimageToMotorTF(3,4);
                    else
                        origZCoord = obj.fakeMotorPosition(3);
                    end
                end
                
                if tfRescaleStackZStartEndPos
                    obj.hSI.hStackManager.stackZStartPos = obj.hSI.hStackManager.stackZStartPos+origZCoord;
                    obj.hSI.hStackManager.stackZEndPos = obj.hSI.hStackManager.stackZEndPos+origZCoord;
                end
                
                
                motor_origin_motorSpace = [0 0 0];
                motor_origin_ScanImageSpace = scanimage.mroi.util.xformPoints(motor_origin_motorSpace,obj.scanimageToMotorTF,true);
                
                offsetT = eye(4);
                offsetT(1:3,4) = motor_origin_ScanImageSpace;
                
                obj.scanimageToMotorTF = obj.scanimageToMotorTF * offsetT;
            end
        end
        
        function defineUserPosition(obj,name,posn)
            % defineUserPosition   add current motor position, or specified posn, to
            %   motorUserDefinedPositions array at specified idx
            %
            %   obj.defineUserPosition()          add current position to list of user positions
            %   obj.defineUserPosition(name)      add current position to list of user positions, assign name
            %   obj.defineUserPosition(name,posn) add posn to list of user positions, assign name
            
            if nargin < 2 || isempty(name)
                name = '';
            end
            if nargin < 3 || isempty(posn)
                posn = obj.motorPosition;
            end
            obj.userDefinedPositions(end+1) = struct('name',name,'coords',posn);
        end
        
        function clearUserDefinedPositions(obj)
        % clearUserDefinedPositions  Clears all user-defined positions
        %
        %   obj.clearUserDefinedPositions()   returns nothing
        
            obj.userDefinedPositions = repmat(struct('name','','coords',[]),0,1);
        end
        
        function gotoUserDefinedPosition(obj,posn)
            % gotoUserDefinedPosition   move motors to user defined position
            %
            %   obj.gotoUserDefinedPosition(posn)  move motor to posn, where posn is either the name or the index of a position
            
            %Move motor to stored position coordinates
            if ischar(posn)
                posn = ismember(posn, {obj.userDefinedPositions.name});
            end
            assert(posn > 0 && numel(obj.userDefinedPositions) >= posn, 'Invalid position selection.');
            obj.motorPosition = obj.userDefinedPositions(posn).coords;
        end
        
        function saveUserDefinedPositions(obj)
            % saveUserDefinedPositions  Save contents of motorUserDefinedPositions array to a position (.POS) file
            %
            %   obj.saveUserDefinedPositions()  opens file dialog and saves user positions to selected file
            
            if obj.componentExecuteFunction('motorSaveUserDefinedPositions')
                [fname, pname]=uiputfile('*.pos', 'Choose position list file'); % TODO starting path
                if ~isnumeric(fname)
                    periods=strfind(fname, '.');
                    if any(periods)
                        fname=fname(1:periods(1)-1);
                    end
                    s.userDefinedPositions = obj.userDefinedPositions; %#ok<STRNU>
                    save(fullfile(pname, [fname '.pos']),'-struct','s','-mat');
                end
            end
        end
        
        function loadUserDefinedPositions(obj)
            % loadUserDefinedPositions  loads contents of a position (.POS) file to the motorUserDefinedPositions array (overwriting any previous contents)
            %
            %   obj.loadUserDefinedPositions()  opens file dialog and loads user positions from selected file
            if obj.componentExecuteFunction('motorLoadUserDefinedPositions')
                [fname, pname]=uigetfile('*.pos', 'Choose position list file');
                if ~isnumeric(fname)
                    periods=strfind(fname,'.');
                    if any(periods)
                        fname=fname(1:periods(1)-1);
                    end
                    s = load(fullfile(pname, [fname '.pos']), '-mat');
                    obj.userDefinedPositions = s.userDefinedPositions;
                end
            end
        end
    end
    
    %% FRIEND METHODS
    methods
        function motorsMoved = moveStartRelative(obj,pos)
            pos = pos(:)'; % ensure row vector
            
            current_Pos = obj.motorPosition; % this might be problematic because we increase numbers of commands sent to motor controller
            new_Pos = current_Pos;
            new_Pos(~isnan(pos)) = pos(~isnan(pos));
            
            current_Pos_motorSpace = scanimage.mroi.util.xformPoints(current_Pos,obj.scanimageToMotorTF);
            new_Pos_motorSpace = scanimage.mroi.util.xformPoints(new_Pos,obj.scanimageToMotorTF);
            new_Pos_motorSpace(new_Pos_motorSpace==current_Pos_motorSpace) = NaN;
            
            setFlag = ~isnan(new_Pos_motorSpace);
            
            motorsMovedBacklashCompensation = [];
            if ~isempty(obj.backlashCompensation) && any(obj.backlashCompensation(setFlag)~=0)
                travelDirection = sign(new_Pos_motorSpace - current_Pos_motorSpace);
                applyBacklashCompensation = travelDirection ~= sign(obj.backlashCompensation);
                applyBacklashCompensation(~setFlag) = 0;
                applyBacklashCompensation(~obj.backlashCompensation) = 0;
                
                if any(applyBacklashCompensation)
                    motorsMovedBacklashCompensation = obj.moveStartRelativeMotorSpace(new_Pos_motorSpace - obj.backlashCompensation.*applyBacklashCompensation,setFlag);
                    for mtr = motorsMovedBacklashCompensation
                        if mtr
                            obj.hMotor(mtr).moveWaitForFinish();
                        end
                    end
                    
                    % we only need to do a second move for the motors that
                    % need backlashCompensation
                    setFlag = false(1,3);
                    setFlag(applyBacklashCompensation) = true;
                    new_Pos_motorSpace(~setFlag) = NaN;
                end
            end
            
            motorsMoved = obj.moveStartRelativeMotorSpace(new_Pos_motorSpace,setFlag);
            motorsMoved = unique([motorsMoved,motorsMovedBacklashCompensation]);
        end
        
        function motorsMoved = moveStartRelativeMotorSpace(obj,new_Pos_motorSpace,setFlag)
            motorsMoved = [];
            mtrs = unique(obj.motorDimMappingMtr(setFlag));
            for mtr = mtrs
                if mtr
                    newPos = nan(1,3);
                    dimsToSet = (obj.motorDimMappingMtr == mtr) & setFlag;
                    newPos(obj.motorDimMappingDim(dimsToSet)) = new_Pos_motorSpace(dimsToSet);
                    
                    currentMotorPos = obj.hMotor(mtr).positionRelative;
                    diffs = abs(newPos - currentMotorPos);
                    if any(diffs)
                        obj.hMotor(mtr).moveStartRelative(newPos);
                        motorsMoved(end+1) = mtr;
                    end
                else
                    dimsToSet = (obj.motorDimMappingMtr == mtr) & setFlag;
                    obj.fakeMotorPosition(dimsToSet) = new_Pos_motorSpace(dimsToSet);
                end
            end
        end
        
        function moveWaitForFinish(obj,dims)
            mtrsToWaitFor = unique(obj.motorDimMappingMtr(dims));
            for mtr = mtrsToWaitFor
                if mtr
                    obj.hMotor(mtr).moveWaitForFinish();
                end
            end
        end
        
        function setMotorZero(obj,newZeroPos)
            chg = find(~isnan(newZeroPos));
            offsetT = eye(4);
            offsetT(chg,4) = newZeroPos(chg);

            obj.scanimageToMotorTF = obj.scanimageToMotorTF * offsetT;

            if ~obj.hSI.hStackManager.slowStackWithFastZ && ~isnan(newZeroPos(3))
                obj.hSI.hStackManager.stackZStartPos = obj.hSI.hStackManager.stackZStartPos-newZeroPos(3);
                obj.hSI.hStackManager.stackZEndPos = obj.hSI.hStackManager.stackZEndPos-newZeroPos(3);
            end
        end
        
        function success = recover(obj)
            success = true;
            
            for i = 1:numel(obj.hMotor)
                tryRec(obj.hMotor(i), sprintf('Stage controller #%d',i));
            end
            
            for i = 1:numel(obj.hSI.hFastZ.hStages)
                tryRec(obj.hSI.hFastZ.hStages(i), sprintf('FastZ actuator #%d',i));
            end
            
            function tryRec(hMtr,nm)
                if hMtr.lscErrPending
                    try
                        hMtr.recover();
                    catch ME
                        fprintf(2,'%s failed to recover. Error message: %s\n',nm,ME.message);
                        warndlg(sprintf('%s failed to recover. %s\n',nm,ME.message),'ScanImage');
                        success = false;
                    end
                end
            end
        end
    end
    
    %% INTERNAL METHODS
    methods (Access = private, Hidden)
        function motorZeroSoft(obj,coordFlags)
            % Do a soft zero along the specified coordinates, and update
            % stackZStart/EndPos appropriately.
            %
            % SYNTAX
            % coordFlags: a 3 element logical vec.
            %
            % NOTE: it is a bit dangerous to expose the motor publicly, since
            % zeroing it directly will bypass updating stackZStart/EndPos.
            if obj.componentExecuteFunction('motorZeroSoft')
                currentPos = obj.motorPosition;
                currentPos(~logical(coordFlags)) = nan;
                obj.setMotorZero(currentPos);
            end
        end
        
        function zprvEnsureClassDataFileProps(obj)
            obj.ensureClassDataFile(struct('motorToRefTransform',double([])),obj.classDataFileName);
            obj.ensureClassDataFile(struct('scanimageToMotorTF',eye(4)),obj.classDataFileName);
            obj.ensureClassDataFile(struct('backlashCompensation',zeros(1,3)),obj.classDataFileName);
        end
    end
    
    %%% Abstract method implementation (scanimage.interfaces.Component)
    methods (Access = protected, Hidden)
        function componentStart(~)
        %   Runs code that starts with the global acquisition-start command
        end
        
        function componentAbort(~)
        %   Runs code that aborts with the global acquisition-abort command
            obj.abortCalibration();
        end
    end
end

%% LOCAL 
function s = ziniInitPropAttributes()
    s = struct();
    s.motorStepLimit = struct('Classes','numeric','Attributes',{{'positive','scalar','nonnan'}});
    s.backlashCompensation = struct('Classes','numeric','Attributes',{{'nonnan','finite'}},'AllowEmpty',1);
    s.azimuth = struct('DependsOn',{{'scanimageToMotorTF'}});
    s.elevation = struct('DependsOn',{{'scanimageToMotorTF'}});
end

function s = defaultMdfSection()
    s = [...
        makeEntry('Motor used for X/Y/Z motion, including stacks.')... % comment only
        makeEntry()... % blank line
        makeEntry('motors(1).controllerType','','If supplied, one of {''sutter.mp285'', ''sutter.mpc200'', ''thorlabs.mcm3000'', ''thorlabs.mcm5000'', ''scientifica'', ''pi.e665'', ''pi.e816'', ''npoint.lc40x'', ''bruker.MAMC''}.')...
        makeEntry('motors(1).dimensions','','Assignment of stage dimensions to SI dimensions. Can be any combination of X,Y,Z, and R.')...
        makeEntry('motors(1).comPort',[],'Integer identifying COM port for controller, if using serial communication')...
        makeEntry('motors(1).customArgs',{{}},'Additional arguments to stage controller. Some controller require a valid stageType be specified')...
        makeEntry('motors(1).invertDim','','string with one character for each dimension specifying if the dimension should be inverted. ''+'' for normal, ''-'' for inverted')...
        makeEntry('motors(1).positionDeviceUnits',[],'1xN array specifying, in meters, raw units in which motor controller reports position. If unspecified, default positionDeviceUnits for stage/controller type presumed.')...
        makeEntry('motors(1).velocitySlow',[],'Velocity to use for moves smaller than motorFastMotionThreshold value. If unspecified, default value used for controller. Specified in units appropriate to controller type.')...
        makeEntry('motors(1).velocityFast',[],'Velocity to use for moves larger than motorFastMotionThreshold value. If unspecified, default value used for controller. Specified in units appropriate to controller type.')...
        makeEntry('motors(1).moveCompleteDelay',[],'Delay from when stage controller reports move is complete until move is actually considered complete. Allows settling time for motor')...
        makeEntry('motors(1).moveTimeout',[],'Default: 2s. Fixed time to wait for motor to complete movement before throwing a timeout error')...
        makeEntry('motors(1).moveTimeoutFactor',[],'(s/um) Time to add to timeout duration based on distance of motor move command')...
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
% Motors.m                                                                 %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
