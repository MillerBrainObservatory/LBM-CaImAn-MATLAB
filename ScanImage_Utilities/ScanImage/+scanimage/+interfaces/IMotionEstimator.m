classdef IMotionEstimator < most.util.Uuid & matlab.mixin.Heterogeneous
    %% User properties
    properties (SetObservable)
        % Place any user accessible properties into a SetObservable
        % property block in the class implementation. These properties will
        % show in the table of the Motion Display GUI
    end
    
    properties (SetObservable, Dependent)
        plotPerformance;
    end
    
    %% Abstract Properties
    properties (SetAccess = immutable, Abstract)
        channels;   % the channel numbers thise estimator processes. e.g. [1] for the first channel, [2 3] for channels 2 and 3
        zs;         % the zs this estimator processes e.g. [0 1 2] for z positions 0 1 and 2 microns
    end
    
    %% Public Properties
    properties (SetAccess = private)
        started = false;
    end
    
    %% Abstract functions    
    methods(Abstract, Access = protected)
        %% motion_estimator_result=estimateMotionInternal(obj,im)
        %
        % Request estimation of the  3D translation of im with respect to 
        % a reference volume.
        %
        % Returned object must implement the IMotionEstimatorResult
        % interface. Return value can be empty if motion estimator cannot
        % compute estimate for given roiData
        
        motion_estimator_result = estimateMotionInternal(obj,roiData);
        
        %% startInternal(obj)
        %
        % starts the MotionEstimator before a new acquisition. Reserves
        % required resources if needed
        % 
        startInternal(obj);
        
        %% abortInternal(obj)
        %
        % aborts the MotionEstimator after an acquisition. Unreserves
        % resources if applicable
        %
        abortInternal(obj);
    end
    
    methods (Hidden)
        %% s = saveUserData(obj)
        %
        % Saves data required to restore the motion estimator when loading
        % from disk. (Does not need to include the user properties, they
        % are handled by the IMotionEstimator interface)
        %
        % Returns struct 's' containing the user data
        %
        function s = saveUserData(obj)
            % Override if needed
            s = struct();
        end
        
        %% loadUserData(s)
        %
        % Restores the user data from struct 's' on loading the motion
        % estimator
        %
        function loadUserData(obj,s)
            % Override if needed
        end
    end
    
    methods(Static,Abstract)
        %% checkSystemRequirements()
        %
        % Checks the system requirements for the MotionEstimator
        % resources are available. Throws is requirements are not met
        checkSystemRequirements();
    end
    
    %% Public Methods
    methods (Sealed)
        function motion_estimator_result = estimateMotion(obj,roiData)
            obj.hPerformancePlot.tic();
            motion_estimator_result = obj.estimateMotionInternal(roiData);
            obj.hPerformancePlot.toc();
        end
        
        function start(obj)
            obj.startInternal();
            obj.started = true;
        end
        
        function abort(obj)
            obj.started = false;
            obj.abortInternal();
        end
    end
    
    %% LifeCycle
    methods
        function obj = IMotionEstimator(referenceRoiData)
            obj.checkSystemRequirements();
            validateattributes(referenceRoiData,{'scanimage.mroi.RoiData'},{'scalar'},'Could not construct Motion Estimator: received invalid reference RoiData');
            assert(~isempty(referenceRoiData.hRoi));
            
            obj.roiData = referenceRoiData;
            obj.roiZs = referenceRoiData.zs;
            
            obj.extractRoiInfo();
            
            obj.initPropertyListener();
            
            obj.hPerformancePlot = most.util.PerformancePlot(...
                sprintf('Performance %s\nROI %s', most.util.className(class(obj)), obj.roiName),false);
            obj.hPerformancePlot.changedCallback = @eigenSetPlots;
            
            function eigenSetPlots(varargin)
                % this is to update the user interface
                obj.plotPerformance = obj.plotPerformance;
            end
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.propertyListeners);
            most.idioms.safeDeleteObj(obj.hPerformancePlot);
        end
    end
    
    %% Internal Properties    
    properties (SetObservable)
        enable = true;
    end
    
    properties (SetAccess = private)
        roiData;
        roiUuiduint64;
        roiUuid;
        roiHash;
        roiName;
        roiZs;
    end
    
    properties (Dependent)
        outOfDate;
    end
    
    events (NotifyAccess = 'private')
        changed; % fires if configuration of Motion Estimator changes to update user interface. Use obj.configurationChanged() to fire this event
    end
    
    properties (SetAccess = private, Hidden)
        propertyListeners;
        hPerformancePlot;
    end
    
    properties (Constant, Hidden)
        CLASS_DESCRIPTION = mfilename('class');
    end
    
    %% Internal Methods
    methods (Access = private)
        function extractRoiInfo(obj)
            obj.roiUuid = obj.roiData.hRoi.uuid;
            obj.roiUuiduint64 = obj.roiData.hRoi.uuiduint64;
            obj.roiHash = obj.roiData.hRoi.hashgeometry();
            obj.roiName = obj.roiData.hRoi.name;
        end
            
        function initPropertyListener(obj)      
            propNames = obj.getUserPropertyList();
            listeners = cellfun(@(pn)addlistener(obj,pn,'PostSet',@(varargin)obj.configurationChanged),propNames,'UniformOutput',false);
            obj.propertyListeners = horzcat(listeners{:});            
        end
    end
    
    methods (Access = protected)
        function configurationChanged(obj)
            notify(obj,'changed');
        end
    end
    
    methods (Hidden)
        function swapRoi(obj,hRoi)
            validateattributes(hRoi,{'scanimage.mroi.Roi'},{'scalar'},'hRoi neeeds to be of type scanimage.mroi.Roi');
            
            assert(obj.roiData.hRoi.isequalish(hRoi)); % only allow swapping if ROI geometry is the same
            obj.roiData.hRoi = hRoi;
            obj.extractRoiInfo();
            
            obj.configurationChanged();
        end
        
        function propNames = getUserPropertyList(obj)
            mc = metaclass(obj);
            
            propList = mc.PropertyList;
            propFilter = [propList.SetObservable] & ~[propList.Hidden] & strcmpi({propList.SetAccess},'public') & strcmpi({propList.GetAccess},'public');
            propNames = {propList(propFilter).Name};
        end
        
        function [s,hRoi] = saveobj(obj)
            s = struct();
            s.description = obj.CLASS_DESCRIPTION;
            s.class = class(obj);
            s.roiData = obj.roiData.saveobj();
            s.plotPerformance = obj.plotPerformance;
            s.roiHash = obj.roiHash;
            s.user_props = obj.getUserPropStruct();
            hRoi = obj.roiData.hRoi;
        end
        
        function s = getUserPropStruct(obj)
            propNames = obj.getUserPropertyList();
            propVals = cellfun(@(p)obj.(p),propNames,'UniformOutput',false);
            
            props = [propNames(:)'; propVals(:)'];
            props = props(:)';
            
            s = struct(props{:});
            s.IME_user_data = struct(); % empty struct
            try
                s.IME_user_data = obj.saveUserData();
            catch ME
                most.idioms.reportError(ME);
            end
        end
        
        function setUserPropStruct(obj,s)
            fields = fieldnames(s);
            fields = setdiff(fields,{'IME_user_data'}); % filter out IME_user_data
            for idx = 1:numel(fields)
                prop = fields{idx};
                val = s.(prop);
                try
                    obj.(prop) = val;
                catch ME
                    fprintf(2,'Could not set property %s of class %s',prop,class(obj));
                    most.idioms.reportError(ME);
                end                
            end
            
            try
                obj.loadUserData(s.IME_user_data);
            catch ME
                most.idioms.reportError(ME);
            end
        end
    end
    
    methods (Static, Hidden)
        function obj = loadobj(s,hRoi)
            class_description = scanimage.interfaces.IMotionEstimator.CLASS_DESCRIPTION;
            
            if nargin < 2 || isempty(hRoi)
                hRoi = [];
            end
            
            % validation
            assert(isstruct(s),'s is not a valid struct');
            assert(isfield(s,'description'),'Not a valid %s. Could not find structure field ''description''.',class_description);
            assert(strcmpi(s.description,class_description),'Not a valid %s. File description is unexpected: %s.',class_description,s.description);
            assert(8==exist(s.class,'class'),'%s was not found on the path',s.class);
            
            % construct motion estimator
            constructor_fh = str2func(s.class);
            s.roiData = scanimage.mroi.RoiData.loadobj(s.roiData);
            if ~isempty(hRoi)
                assert(hRoi.isequalish(s.roiData.hRoi),'Cannot relink to hRoi because the geometry has changed.');
                s.roiData.hRoi = hRoi; % relink to existing hRoi
            end
            obj = constructor_fh(s.roiData);
            obj.plotPerformance = s.plotPerformance;
            obj.setUserPropStruct(s.user_props);
        end
    end
    
    %% Getter / Setter
    methods
        function set.enable(obj,val)
            validateattributes(val,{'numeric','logical'},{'scalar','binary'});
            if val && obj.outOfDate
                most.idioms.warn('Cannot enable motion estimator for ROI ''%s'' because the ROI geometry changed',obj.roiData.hRoi.name);
                val = false;
            end
            obj.enable = logical(val);
            obj.configurationChanged();
        end
        
        function val = get.outOfDate(obj)
            val = ~strcmp(obj.roiHash,obj.roiData.hRoi.hashgeometry);
        end
        
        function set.plotPerformance(obj,val)
            oldVal = obj.plotPerformance;
            validateattributes(val,{'numeric','logical'},{'scalar','binary'});
            obj.hPerformancePlot.visible = logical(val);
            
            if oldVal ~= val
                if val
                    obj.hPerformancePlot.reset;
                end
            end
        end
        
        function val = get.plotPerformance(obj)
            val = obj.hPerformancePlot.visible;
        end
    end
end

%--------------------------------------------------------------------------%
% IMotionEstimator.m                                                       %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
