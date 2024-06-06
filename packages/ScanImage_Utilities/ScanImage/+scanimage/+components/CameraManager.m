classdef CameraManager < scanimage.interfaces.Component & most.HasMachineDataFile & ...
        most.HasClassDataFile
    %% CameraManager
    %
    % Contains functionality to manage and arbitrate 1 or more cameras.
    %
    
    properties(Dependent, SetAccess=private, Transient)
        hCameras;                           % Cell array of Camera objects being managed
    end
    
    properties (SetAccess = private, Transient)
        hCameraWrappers = scanimage.components.cameramanager.CameraWrapper.empty(1,0); % array of camera wrappers
    end
    
    properties (Hidden, SetAccess=?scanimage.interfaces.Class, SetObservable)
        classDataFileName;
    end
    
    properties(Hidden, SetAccess = private, SetObservable)
        hListeners = event.proplistener.empty(1,0);  %  Array of listener objects for camera updates
    end
    
    events
        cameraLastFrameUpdated;              % Event to notify system that a camera has updated new frame
        cameraLUTChanged;                    % Event to notify system that the Camera Look Up Table has changed
    end
    
    %%% ABSTRACT PROPERTY REALIZATION (most.Model)
    properties (Hidden,SetAccess=protected)
        mdlPropAttributes = ziniInitPropAttributes();
        mdlHeaderExcludeProps = {'hCameras','hCameraWrappers'};
    end
    
    %%% ABSTRACT PROPERTY REALIZATION (scanimage.interfaces.Component)
    properties (SetAccess = protected, Hidden)
        numInstances = 1;
    end
    
    properties (Constant, Hidden)
        COMPONENT_NAME = 'CameraManager';    % [char array] short name describing functionality of component e.g. 'Beams' or 'FastZ'
        PROP_TRUE_LIVE_UPDATE = {};          % Cell array of strings specifying properties that can be set while the component is active
        PROP_FOCUS_TRUE_LIVE_UPDATE = {};    % Cell array of strings specifying properties that can be set while focusing
        DENY_PROP_LIVE_UPDATE = {};          % Cell array of strings specifying properties for which a live update is denied (during acqState = Focus)
        
        FUNC_TRUE_LIVE_EXECUTION = {};       % Cell array of strings specifying functions that can be executed while the component is active
        FUNC_FOCUS_TRUE_LIVE_EXECUTION = {}; % Cell array of strings specifying functions that can be executed while focusing
        DENY_FUNC_LIVE_EXECUTION = {};       % Cell array of strings specifying functions for which a live execution is denied (during acqState = Focus)
    end
    
    %%% ABSTRACT PROPERTY REALIZATIONS (most.HasMachineDataFile)
    properties (Constant, Hidden)
        %Value-Required properties
        mdfClassName = mfilename('class');
        mdfHeading = 'CameraManager';
        
        %Value-Optional properties
        mdfDependsOnClasses; %#ok<MCCPI>
        mdfDirectProp;       %#ok<MCCPI>
        mdfPropPrefix;       %#ok<MCCPI>
        
        mdfDefault = defaultMdfSection();
    end
    
    %% LIFE CYCLE METHODS
    methods
        %% Constructor
        function obj = CameraManager(hSI, varargin)
            obj = obj@scanimage.interfaces.Component(hSI);
            
            % Determine classDataFile name and path
            if isempty(obj.hSI.classDataDir)
                pth = most.util.className(class(obj),'classPrivatePath');
            else
                pth = obj.hSI.classDataDir;
            end
            classNameShort = most.util.className(class(obj),'classNameShort');
            obj.classDataFileName = fullfile(pth, [classNameShort '_classData.mat']);
            
            % mdf validation
            types = obj.mdfData.cameraTypes;
            names = obj.mdfData.cameraNames;
            assert(iscellstr(types),'Invalid Machine Data File Entry for camera types. Must be a cell array of strings.');
            assert(iscellstr(names),'Invalid Machine Data File Entry for camera names. Must be a cell array of strings.');
            assert(numel(types)==numel(names),'Invalid Machine Data File Entry: camera types and camera names must have same length.');
            
            for idx=1:numel(names)
                registryEntry = scanimage.components.cameramanager.registry.CameraRegistry.getCameraEntryByName(types{idx});
                if isempty(registryEntry)
                    fprintf(2,'Camera %s not found in camera registry. \n',names{idx});
                    continue
                end
                
                constructorFcn = registryEntry.classConstructor;
                try
                    hCamera = constructorFcn(names{idx});
                catch ME
                    most.idioms.reportError(ME);
                    continue;
                end
                obj.hListeners(end+1) = addlistener(hCamera,'lastFrame','PostSet',@(varargin)obj.notifyFrameUpdate(hCamera));
                
                hCameraWrapper = scanimage.components.cameramanager.CameraWrapper(hCamera);
                obj.hListeners(end+1) = addlistener(hCameraWrapper,'lut','PostSet',@(varargin)obj.notifyLUTUpdate(hCameraWrapper));
                obj.hCameraWrappers(idx) = hCameraWrapper;
            end
            
            % load class data file
            obj.loadClassData();
        end
        
        %% Destructor
        function delete(obj)
            obj.saveClassData();
            most.idioms.safeDeleteObj(obj.hListeners);
            if any(cellfun('isclass', obj.hCameras, 'dabs.Spinnaker.Camera'))
                %Spinnaker uses a singleton system handle which needs clearing before
                % scanimage exits
                dabs.Spinnaker.System.release();
            end
            most.idioms.safeDeleteObj(obj.hCameraWrappers);
        end
    end
    
    %% USER METHODS
    methods
        %% resetTransforms(obj)
        %
        % Resets all cameraToRefTransforms to the identity matrix
        %
        function resetTransforms(obj)
            for idx = 1:length(obj.hCameraWrappers)
                obj.hCameraWrappers(idx).cameraToRefTransform = eye(3);
            end
        end        
    end
    
    %% INTERNAL METHODS
    methods
        %% notifyFrameUpdate(obj, camera)
        %
        % Callback function passed to Camera constructor to fire frame
        % update event notification upon frame update.
        %
        function notifyFrameUpdate(obj,camera)
            camIdxArray = obj.idxFromCamera(camera);
            
            if ~isempty(camIdxArray)
                evntData = ...
                    scanimage.components.cameramanager.frameUpdateEventData(...
                    obj.hCameraWrappers(camIdxArray));
                notify(obj,'cameraLastFrameUpdated',evntData);
            end
        end
        
        %% notifyLUTUpdate(obj, camWrap)
        %
        % Function to notify other classes that a cameras look up table has
        % changed. This function is sent to the CameraWrappers object array
        % hCameraWrappers during construction and initialization as an anonymous
        % callback function. When the look up table for that cameras
        % CameraWrapper object changes, this function is called to let
        % other classes know.
        %
        function notifyLUTUpdate(obj, camWrap, varargin)
            evntData =...
                scanimage.components.cameramanager.lutUpdateEventData(camWrap);
            notify(obj, 'cameraLUTChanged', evntData);
        end
        
        %% idxFromCamera(obj, camera)
        %
        % Function to get the idx for a specific camera in the array of
        % currently managed cameras.
        %
        function idx = idxFromCamera(obj, camera)
            tf = camera.uuidcmp(obj.hCameras);
            idx = find(tf,1,'first');
        end
    end
    
    %% PROPERTY GET/SET METHODS
    methods
        %% get.hCameras(obj)
        %
        % Returns a cell array of handles to the camera objects currently
        % being managed.
        %
        function val = get.hCameras(obj)
            val = {obj.hCameraWrappers.hDevice};
        end
    end
    
    %% Friend Methods
    methods(Hidden, Access=protected)
        % start the component
        function componentStart(obj)
        end
        
        % abort the component
        function componentAbort(obj)
        end
    end
    
    methods(Access = protected, Hidden)
        function ensureClassDataFileProps(obj)
            obj.ensureClassDataFile(struct('cameraProps',[]),obj.classDataFileName);
        end
        
        function loadClassData(obj)
            obj.ensureClassDataFileProps();
            
            cameraProps = obj.getClassDataVar('cameraProps',obj.classDataFileName);
            for idx = 1:length(cameraProps)
                s = cameraProps(idx);
                camIdx = find(strcmpi(s.cameraName,{obj.hCameraWrappers.cameraName}), 1);
                if isempty(camIdx)
                    most.idioms.warn('CameraManager: Camera %s not found in system.',s.cameraName);
                else
                    try
                        obj.hCameraWrappers(camIdx).loadProps(s);
                    catch ME
                        most.idioms.reportError(ME);
                    end
                end
            end
        end
        
        function saveClassData(obj)
            try
                obj.ensureClassDataFileProps();
                cameraProps = arrayfun(@(cw)cw.saveProps,obj.hCameraWrappers);
                obj.setClassDataVar('cameraProps',cameraProps,obj.classDataFileName);
            catch ME
                most.idioms.reportError(ME);
            end
        end
    end
end

%% LOCAL FUNCTIONS
function s = defaultMdfSection()
s = [...
    makeEntry('cameraNames',{{}},'Some string identifier e.g. {''MyCam''}') ...
    makeEntry('cameraTypes',{{}},'string dictating type e.g. {''Micromanager''}') ...
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

function s = ziniInitPropAttributes()
s = struct();
end

%--------------------------------------------------------------------------%
% CameraManager.m                                                          %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
