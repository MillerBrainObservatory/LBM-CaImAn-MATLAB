classdef IMotionCorrector < most.util.Uuid
    % User properties
    properties (SetObservable)
        % Place any user accessible properties into a SetObservable
        % property block in the class implementation
    end
    
    events
        correctNow; % event that triggers a motion update in ScanImage
    end
    
    methods (Abstract)
        %% start(obj)
        %
        % initializes the motionCorrector for a new acquisition
        %
        start(obj)
        
        %% abort(obj)
        %
        % stops the motionCorrector at the end of an acquisition
        %
        abort(obj)
        
        %% updateMotionHistory(obj,motionHistory)
        %
        % hands the latest motionHistory from ScanImage over to the Motion
        % Corrector. motionHistory is a struct array.
        % Note: in future releases the motionHistory might not be sorted anymore.
        % Use [motionHistory.historyIdx] to get the history indices
        %
        updateMotionHistory(obj,motionHistory);
        
        %% drRef = getCorrection(obj)
        % 
        % Returns a recommended relative (1x3) motion vector drRef in reference space
        % for moving the x,y,z axis to compensate any sample motion. Return 0 or NaN for
        % axis that don't need to be corrected. ScanImage can query this function and discard the data.
        % Notify the event correctNow to trigger a correction event
        % 
        dr = getCorrection(obj);
        
        %% correctedMotion(obj,dr,motionCorrectionVector)
        %
        % Informs the Motion Corrector that ScanImage performed a relative motion
        % correction of vector dr (x,y,z) in reference space.
        % The new absolute correction in reference space is given by correctionVectorAbsolute.
        %
        correctedMotion(obj,dr,correctionVectorAbsolute);
    end
    
    methods (Hidden)
        %% s = saveUserData(obj)
        %
        % Saves data required to restore the motion estimator when loading
        % from disk. (Does not need to include the user properties, they
        % are handled by the IMotionCorrector interface)
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
        % corrector
        %
        function loadUserData(obj,s)
            % Override if needed
        end
    end
    
    %% LifeCycle
    methods
        function obj = IMotionCorrector()
            obj.initPropertyListener();
        end
        
        function delete(obj)
            most.idioms.safeDeleteObj(obj.propertyListeners);
        end
    end
    
    %% Internal properties and methods
    properties (Access = private)
        propertyListeners;
    end
    
    events (NotifyAccess = private)
        changed
    end
    
    methods (Access = protected)
        function configurationChanged(obj)
            obj.notify('changed');
        end
    end
    
    methods (Access = private)
        function initPropertyListener(obj)      
            propNames = obj.getUserPropertyList();
            listeners = cellfun(@(pn)addlistener(obj,pn,'PostSet',@(varargin)obj.configurationChanged),propNames,'UniformOutput',false);
            obj.propertyListeners = horzcat(listeners{:});            
        end
    end
    
    properties (Constant, Hidden)
        CLASS_DESCRIPTION = mfilename('class');
    end
    
    methods (Hidden)
        function propNames = getUserPropertyList(obj)
            mc = metaclass(obj);
            
            propList = mc.PropertyList;
            propFilter = [propList.SetObservable] & ~[propList.Hidden] & strcmpi({propList.SetAccess},'public') & strcmpi({propList.GetAccess},'public');
            propNames = {propList(propFilter).Name};
        end
        
        function s = saveobj(obj)           
            s = struct();
            s.description = obj.CLASS_DESCRIPTION;
            s.class = class(obj);
            s.user_props = obj.getUserPropStruct();
        end
        
        function s = getUserPropStruct(obj)
            propNames = obj.getUserPropertyList();
            propVals = cellfun(@(p)obj.(p),propNames,'UniformOutput',false);
            
            props = [propNames(:)'; propVals(:)'];
            props = props(:)';
            
            s = struct(props{:});
            s.IMC_user_data = struct(); % empty struct
            try
                s.IMC_user_data = obj.saveUserData();
            catch ME
                most.idioms.reportError(ME);
            end
        end
        
        function setUserPropStruct(obj,s)
            fields = fieldnames(s);
            fields = setdiff(fields,{'IMC_user_data'}); % filter out IMC_user_data
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
                obj.loadUserData(s.IMC_user_data);
            catch ME
                most.idioms.reportError(ME);
            end
        end
    end
    
    methods (Static, Hidden)
        function obj = loadobj(s)
            class_description = scanimage.interfaces.IMotionCorrector.CLASS_DESCRIPTION;
            
            % validation
            assert(isstruct(s),'s is not a valid struct');
            assert(isfield(s,'description'),'Not a valid %s. Could not find structure field ''description''.',class_description);
            assert(strcmpi(s.description,class_description),'Not a valid %s. File description is unexpected: %s.',class_description,s.description);
            assert(8==exist(s.class,'class'),'%s was not found on the path',s.class);
            
            constructor_fh = str2func(s.class);
            obj = constructor_fh();
            obj.setUserPropStruct(s.user_props);
        end
    end
end

%--------------------------------------------------------------------------%
% IMotionCorrector.m                                                       %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
