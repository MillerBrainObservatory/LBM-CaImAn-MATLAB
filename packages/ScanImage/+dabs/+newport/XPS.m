classdef XPS < dabs.interfaces.LinearStageController & most.HasMachineDataFile & most.DClass
   % TODO: some mechanism to put low level limits on stage motion
   % TODO: verify defaults (currently set to extremes from stages.ini file
   
   %% REALIZED ABSTRACT PROPERTIES 
    properties (Constant,Hidden)
        nonblockingMoveCompletedDetectionStrategy='poll'; % Either 'callback' or 'poll'. If 'callback', this class guarantees that moveDone() will be called when a nonblocking move is complete. See documentation for moveStartHook().
    end
    
    % The Abstract properties below can be implemented by subclasses in several
    % ways. These include:
    %   * Constant values (effectively), defined in subclass property block
    %   * Dependent property, with get/set methods defined in subclass
    %   * Constructor-initialized value, optional or mandatory, in subclass ctor
    
    properties (SetAccess=protected)
        isMoving; %Logical scalar. If true, the stage is currently moving.
        infoHardware; %String providing hardware information, e.g. firmware version, manufacture date, etc.
    end

    properties (SetAccess=protected,Hidden)
        positionAbsoluteRaw; % Absolute stage position, in positionDeviceUnits. Numeric array of size [1 numDeviceDimensions].
        velocityRaw; % Stage velocity, in velocityDeviceUnits. Either a scalar or an array of size [1 numDeviceDimensions].
        accelerationRaw; %Stage acceleration, in accelerationDeviceUnits. Either a scalar or an array of size [1 numDeviceDimensions].

        invertCoordinatesRaw; %Logical array of size [1 numDeviceDimensions]. If invertCoordinatesRaw(i)==true, position values in ith device dimension are inverted.
        maxVelocityRaw; %Maximum stage velocity in velocityDeviceUnits. Either a scalar or array of size [1 numDeviceDimensions].
        
        %The 'resolution' property indicates the fraction of
        %positionAbsoluteRaw values to consider valid to use in
        %setting/interpreting position values. For most devices, it will be
        %read-only; for some devices, it may be a settable property
        %indicating the user-required resolution.
        %
        %TIP: A value of 1 indicates that resolution matches the positionDeviceUnits
        resolutionRaw; %Current stage resolution, in positionDeviceUnits. Either a scalar or array of size [1 numDeviceDimensions].
        
        positionDeviceUnits=1E-3; %Units, in meters, in which the device's position values (as reported by positionAbsoluteRaw) are given. Either a scalar, or an array of size [1 numDeviceDimensions].
        velocityDeviceUnits=1E-3; %Units, in meters/sec, in which the device's velocity values (as reported by velocityRaw) are given. Either a scalar, or an array of size [1 numDeviceDimensions]. If scalar, may be nan, indicating dimensionless units.
        accelerationDeviceUnits=1E-3; %Units, in meters/sec^2, in which the device's acceleration values (as reported by accelerationRaw) are given. Either a scalar, or an array of size [1 numDeviceDimensions]. If scalar, may be nan, indicating dimensionless units.
        maxAccelerationRaw;
        maxJerkAllowedRaw; 
        minJerkAllowedRaw;
    end   

    properties
        minJerkRaw;
        maxJerkRaw;
    end
    
    properties(SetAccess=protected)
        hStage;
        ipAddress;
        port;
        numberOfGroups;
        positionerNames;
        groupNames;
        groupToAxisMap;
        stageRanges;
        numberOfPositioners
    end
    properties (Access=private)
        notInitializedStates=[0 1 2 3 4 5 6 7 8 9 63 50 66 67 71 72];
        notReferencedState=42;
    end
    
    %%% ABSTRACT PROPERTY REALIZATIONS (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'Newport XPS';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
        
        mdfDefault = defaultMdfSection();
    end
    
    %% CONSTRUCTOR/DESTRUCTOR
    methods
        function obj=XPS(varargin)
            %superclass constructor
            obj = obj@dabs.interfaces.LinearStageController('numDeviceDimensions',3);
            
            %constructure XPS
            positioners = obj.mdfData.positionerNames;
            obj.positionerNames={};
            obj.groupNames={};
            obj.groupToAxisMap=containers.Map;
            obj.numberOfPositioners = 0;
            for i=1:length(positioners)
                if ~isempty(positioners{i})
                    obj.numberOfPositioners = obj.numberOfPositioners + 1;
                    obj.positionerNames=[obj.positionerNames, positioners(i)];
                    [groupName, ~]=strtok(positioners{i},'.');
                    if ~ismember(groupName,obj.groupNames);
                        obj.groupNames=[obj.groupNames,{groupName}];
                    end
                    if ~ismember(groupName,obj.groupToAxisMap.keys);
                        obj.groupToAxisMap(groupName)=i;
                    else
                        obj.groupToAxisMap(groupName)=[obj.groupToAxisMap(groupName) i];
                    end
                end
            end
            
            obj.numberOfGroups=length(obj.groupNames);
            positionersInGroup=zeros(1,obj.numberOfGroups);
            for i=1:obj.numberOfGroups
                positionersInGroup(i)=length(obj.groupToAxisMap(obj.groupNames{i}));
            end
            
            obj.hStage=dabs.newport.XPS_TCP(obj.groupNames,positionersInGroup,obj.mdfData.ipAddress,obj.mdfData.port);
            
            % for now, set all axis to no inversion;
            if ~isempty(obj.mdfData.invertCoordinates);
                obj.invertCoordinatesRaw=obj.mdfData.invertCoordinates;
            else
                obj.invertCoordinatesRaw=zeros(1,obj.numberOfPositioners);
            end
            
            % check for manually entered limits on stage motion in the ini
            % file
            % Note, these must be in the default stage coordinates and units, test in a safe environment
            % This is incomplete, may not bother to implement
            
            %if exist(state.motor.newport.Limits) && ~isempty(state.motor.newport.Limits);
            
            obj.initializeAllGroups;
            obj.groupHomeSearch;
            
            if ~isempty(obj.mdfData.velocity)
                obj.velocity=obj.mdfData.velocity;
            else
                obj.velocityRaw=obj.maxVelocityRaw;
            end
            
            if ~isempty(obj.mdfData.acceleration)
                obj.acceleration=obj.mdfData.acceleration;
            else
                obj.accelerationRaw=obj.maxAccelerationRaw;
            end
            
            if ~isempty(obj.mdfData.minJerkRaw)
                obj.minJerkRaw=obj.mdfData.minJerkRaw;
            else
                obj.minJerkRaw=obj.minJerkAllowedRaw;
            end
            
            if ~isempty(obj.mdfData.maxJerkRaw)
                obj.maxJerkRaw=obj.mdfData.maxJerkRaw;
            else
                obj.maxJerkRaw=obj.maxJerkAllowedRaw;
            end
        end
    end
    
    %% Individual get/set
    methods 
        function val=get.isMoving(obj)
            statusarray=zeros(1,length(obj.groupNames));
            for i=1:obj.numberOfGroups
                temp=obj.hStage.executeFunction('GroupStatusGet',obj.groupNames{i});
                statusarray(i)=temp{1};
            end
            
            val=any(statusarray==44) || any(statusarray==43);
        end
        
        
        function val=get.infoHardware(obj)
            val=obj.hStage.executeFunction('FirmwareVersionGet');
        end
        
        function val=get.positionAbsoluteRaw(obj)
            val=nan(1,obj.numberOfPositioners);
            for i=1:obj.numberOfPositioners;
                temp=obj.hStage.executeFunction('GroupPositionCurrentGet',obj.positionerNames{i});
                val(i)=temp{1};
            end
            val=obj.applyInversion(val);
            %val=obj.hStage.positionCurrentArray;
        end
        
        function paramArray=getSGammaParams(obj)
            paramArray=nan(length(obj.positionerNames),4);
            for i=1:obj.numberOfPositioners
                temp=obj.hStage.executeFunction('PositionerSGammaParametersGet',obj.positionerNames{i});
                paramArray(i,:)=[temp{:}];
            end
        end
        
        function setSGammaParams(obj,val)
            for i=1:obj.numberOfPositioners
                obj.hStage.executeFunction('PositionerSGammaParametersSet',obj.positionerNames{i},val(i,1),val(i,2),val(i,3),val(i,4));
            end
        end
        
        function val=get.velocityRaw(obj)
            val=obj.getSGammaParams();
            val=val(:,1);
        end
        
        function val=get.accelerationRaw(obj)
            val=obj.getSGammaParams();
            val=val(:,2);
        end
        
        function val=get.minJerkRaw(obj)
            val=obj.getSGammaParams();
            val=val(:,3);
        end
        
        function val=get.maxJerkRaw(obj)
            val=obj.getSGammaParams();
            val=val(:,4);
        end
        
        function set.velocityRaw(obj,val)
            paramArray=obj.getSGammaParams();
            paramArray(:,1)=val';
            obj.setSGammaParams(paramArray);
        end
        
        function set.accelerationRaw(obj,val)
            paramArray=obj.getSGammaParams();
            paramArray(:,2)=val';
            obj.setSGammaParams(paramArray);
        end
        
        function set.minJerkRaw(obj,val)
            paramArray=obj.getSGammaParams();
            paramArray(:,3)=val';
            obj.setSGammaParams(paramArray);
        end
        
        function set.maxJerkRaw(obj,val)
            paramArray=obj.getSGammaParams();
            paramArray(:,4)=val';
            obj.setSGammaParams(paramArray);
        end
        
        function val=getStageParamsNumber(obj,paramName)
            val=nan(1,obj.numberOfPositioners);
            for i=1:obj.numberOfPositioners
                temp=obj.hStage.executeFunction('PositionerStageParameterGet',obj.positionerNames{i},paramName);
                val(i)=str2double(temp{1});
            end
        end
        
        function val=get.resolutionRaw(obj)
            val=getStageParamsNumber(obj,'EncoderResolution');
        end
            
        function val=get.maxVelocityRaw(obj)
            val=getStageParamsNumber(obj,'MaximumVelocity');
        end
        
        function val=get.stageRanges(obj)
            val=cell(obj.numberOfPositioners,2);
            for i=1:obj.numberOfPositioners
                temp=obj.hStage.executeFunction('PositionerUserTravelLimitsGet',obj.positionerNames{i});
                val{i,1}=temp{1};
                val{i,2}=temp{2};
            end
            
        end
        
        function val=get.maxAccelerationRaw(obj)
             val=getStageParamsNumber(obj,'MaximumAcceleration');
        end
        
        function val=get.maxJerkAllowedRaw(obj)
             val=getStageParamsNumber(obj,'MaximumJerkTime');
        end
        
        function val=get.minJerkAllowedRaw(obj)
            val=getStageParamsNumber(obj,'MinimumJerkTime'); 
        end
    end
    %% REALIZED ABSTRACT METHODS    
    
    % This method must be implemented in a concrete subclass.
    methods (Access=protected,Hidden)
        
        % Start a nonblocking move and return immediately. absTargetPosn is
        % in the device coordinate system, eg it is directly comparable to
        % positionAbsoluteRaw.
        %
        % Requirements/Expectations:
        % 1. During a move initiated by moveStartHook, the .isMoving
        % property of the object in question must faithfully represent the
        % state of its stage. That is, .isMoving must be true while the
        % move is in progress, and it must become false once the move is
        % complete. Some devices may allow querying the device for this
        % during the move, while others may not.
        % 2. If possible, LinearStageController.moveDone should
        % be called when the nonblocking move is complete. This is
        % optional, but recommended if possible. 
        %
        % If a concrete LinearStageController class can only meet the first
        % requirement, then set its nonblockingMoveCompletedDetectionStrategy
        % to 'poll'. In this case, LinearStageController or its clients may
        % poll the .isMoving property to determine when a nonblocking move
        % is complete. If a concrete LinearStageController class can meet
        % the second (optional) requirement in addition to the first, then
        % set its nonblockingMoveCompletedDetectionStrategy to 'callback'.
        function moveStartHook(obj,absTargetPosn)
             %absTargetPosn=obj.checkLimits(absTargetPosn); %% TODO (there might be something built into scanimage proper to address this
             absTargetPosn=obj.applyInversion(absTargetPosn);
             for i=1:obj.numberOfGroups
                 
                 currentGroup=obj.groupNames{i};
                 relaventPositionIndices=obj.groupToAxisMap(currentGroup);
                 targetPosnAdjusted=absTargetPosn(relaventPositionIndices);
                 targetPosnAdjusted=num2cell(targetPosnAdjusted);
                 obj.hStage.executeFunction('GroupMoveAbsolute',currentGroup,targetPosnAdjusted{:});
             end
        end
    end
    
    % These methods have default implementations. Implementation in
    % concrete subclasses is not required, but encouraged where applicable.
    methods (Access=protected,Hidden)

        
        % Interrupt a move. After return, the stage should be ready to
        % accept new commands.
        function interruptMoveHook(obj)
            for i=1:obj.numberOfGroups
                obj.hStage.executeFunction('GroupMoveAbort',obj.groupNames{i});
            end
            
        end
        
        % Attempt to recover from an error condition. This is similar in
        % intention but less "severe" than resetHook().
        function recoverHook(obj)
            try
                %obj.errorConditionReset();
                posn = obj.positionAbsolute;
%                 if obj.errorCondition %See if any error condition was caused during get operation
%                     error('dummy');
%                 end
            catch 
                ME = obj.DException('','ResetErrorConditionFailed','Attempted to reset the error condition, but was unsuccessful');
                obj.errorConditionSet(ME);
                ME.throw();
            end
        end

        % "Hard reset" of device. 
        function resetHook(obj)
            error([mfilename ':ResetNotSupported'],'Device of class %s does not support ''reset()'' operation.',class(obj));
        end
        
        % Zero position coordinate system on device. coords is a logical
        % vector indicating which dimensions to zero. coords has the same
        % number of elements as positionAbsoluteRaw and is with respect to
        % the same physical dimensions.
        %
        % Zero-ing should have the effect of shifting the values returned
        % by positionAbsoluteRaw. The software origin (relativeOrigin)
        % maintained by LinearStageController will be unaffected.
        function zeroHardHook(obj,coords) %#ok<INUSD>
            error([mfilename ':ZeroHardNotSupported'],'Device of class %s does not support ''zeroHard()'' operation.',class(obj));
        end
        
        %Return value of best (finest) resolution supported by device, in
        %positionDeviceUnits, as a scalar or array of [1 numDeviceDimensions]
        function val = getResolutionBestHook(obj)
            val = obj.resolutionRaw;
        end
    end
    
    methods 
          function initializeAllGroups(obj)
              for i=1:obj.numberOfGroups
                    status=obj.hStage.executeFunction('GroupStatusGet',obj.groupNames{i});
                    statusArray=ismember(status{1},obj.notInitializedStates);
                    % Can only be initialized if in a certain state(s)
                    if sum(statusArray)~=0
                       % fprintf('Initializing %s\n',obj.groupNames{i});
                        obj.hStage.executeFunction('GroupInitialize',obj.groupNames{i});
                        % pause(5)
                    end
                    
              end
           
          end
        
        function groupHomeSearch(obj)
            skipPrompt=0;
            
            for i=1:obj.numberOfGroups
                status=obj.hStage.executeFunction('GroupStatusGet',obj.groupNames{i});
                statusArray=ismember(status{1},obj.notReferencedState);
                % Group can only be homed if it is in a certain
                % state(s)
                if statusArray
                    if (skipPrompt || strcmp('Yes',questdlg('WARNING: Continuing may move the stage to the home position. Make sure the stage is clear. Continue?','Continue with stage move?')))
                        % fprintf('Initializing %s\n',obj.groupNames{i});
                        obj.hStage.executeFunction('GroupHomeSearch',obj.groupNames{i});
                        skipPrompt=1;
                        pause(1)
                        %For some reason, blocking by waiting for the
                        %read to complete from the XPS seemed to cause
                        %problems, so instead the homing move is
                        %initialized, and then it's state is polled.
                        %This is relatively crude but seems to work.
                        while obj.isMoving
                            pause(1)
                            %statusTemp=obj.hStage.executeFunction('GroupStatusGet',obj.groupNames{i})
                        end
                        statusTemp=obj.hStage.executeFunction('GroupStatusGet',obj.groupNames{i});
                        if statusTemp{1}~=11 %11 is the ready state after homing
                            obj.delete();
                            error('Homing Failed')
                            
                        end
                    else
                        obj.delete();
                    end
                end
            end
        end
    end
    
    methods
        %% Helper Methods
        function pos=applyInversion(obj,pos)
            for i=1:obj.numberOfPositioners
                if obj.invertCoordinatesRaw(i)
                    pos(i)=obj.stageRanges{i,2}-(pos(i)-obj.stageRanges{i,1});
                end
            end
        end
    end
end

function s = defaultMdfSection()
    s = [...
        makeEntry('positionerNames',{{'' '' ''}},'Positioner names as strings, in the order XYZ. Use empty string if dimension isn''t used (e.g. If only using the z dimensions {'''','''',''Z.Z''})')...
        makeEntry('ipAddress','192.168.0.254')...
        makeEntry('port',5001)...
        makeEntry('acceleration',[1E3 1E3 40E3],'um per s')...
        makeEntry('velocity',[.4E3 .4E3 5E3],'um per s')...
        makeEntry('minJerkRaw',[.005 .005 .005],'device units')...
        makeEntry('maxJerkRaw',[.005 .005 .005],'device units')...
        makeEntry('invertCoordinates',[0 0 0])...
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
% XPS.m                                                                    %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
