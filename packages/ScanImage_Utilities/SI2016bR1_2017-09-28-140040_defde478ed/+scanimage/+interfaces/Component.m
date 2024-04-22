classdef Component < scanimage.interfaces.Class & most.Model
    
    %% User Properties
    properties (Abstract, SetAccess = protected)
        numInstances;           % Number of component instances
    end
    
    %% Internal Properties
    properties (SetAccess = immutable, Hidden, Transient)
        hSI;                    % handle to the root SI object
        componentIsRoot;        % Logical. Specifies if current obj == hSI
    end
    
    properties (SetAccess = protected, Hidden, Transient)
        independentComponent;   % Logical. Specifies if current obj active state is independent of hSI state
    end
    
    properties (SetAccess = protected, Transient, SetObservable, Hidden)
        active = false;         % Logical. Specifies if the Component is active
    end
    
    %%% Abstract properties
    properties (Abstract, Constant, Hidden)
        COMPONENT_NAME;                 % [char array] short name describing functionality of component e.g. 'Beams' or 'FastZ'
        PROP_TRUE_LIVE_UPDATE;          % Cell array of strings specifying properties that can be set while the component is active
        PROP_FOCUS_TRUE_LIVE_UPDATE;    % Cell array of strings specifying properties that can be set while focusing
        DENY_PROP_LIVE_UPDATE;          % Cell array of strings specifying properties for which a live update is denied (during acqState = Focus)
        
        FUNC_TRUE_LIVE_EXECUTION;       % Cell array of strings specifying functions that can be executed while the component is active
        FUNC_FOCUS_TRUE_LIVE_EXECUTION; % Cell array of strings specifying functions that can be executed while focusing
        DENY_FUNC_LIVE_EXECUTION;       % Cell array of strings specifying functions for which a live execution is denied (during acqState = Focus)
    end
    
    %% Life Cycle
    methods
        function obj = Component(hSI,isRoot,independentComponent)
            if nargin < 2 || isempty(isRoot)
                isRoot = false;
            end
            if nargin < 3 || isempty(independentComponent)
                independentComponent = false;
            end
            
            obj.componentIsRoot = isRoot;
            if isRoot
                obj.hSI = obj;
            else
                obj.hSI = hSI;
            end
            
            obj.independentComponent = independentComponent;
            
            obj.checkLivePropertiesExist(); % Not strictly needed, but it helps to keep lists clean of deleted / legacy properties
        end
    end
    
    %% Property Access
    methods
        function val = get.active(obj)
            val = obj.active;
            val = obj.componentGetActiveOverride(val);
        end
    end
    
    %% Friend methods
    methods (Hidden)
        function reloadMdf(obj)
            if isa(obj, 'most.HasMachineDataFile')
                obj.initializeMdf();
                
                subms = obj.mdlSubModelClasses;
                for i = 1:numel(subms)
                    obj.(subms{i}).reloadMdf();
                end
            end
        end
        
        function start(obj,varargin)
            %Ignore start operation for components with no instances
            if obj.numInstances <= 0
                return
            end
            
            assert(~obj.active,'%s: Cannot start acquisition while acquisition is active',obj.COMPONENT_NAME);
            
            try
                obj.componentStart(varargin{:});
                obj.active = true;
            catch ME
                % if starting a component fails, abort scanimage before
                % reporting the error
                if ~isempty(obj.hSI) && isvalid(obj.hSI)
                    obj.hSI.abort();
                else
                    obj.abort();
                end
                rethrow(ME);
            end
        end
        
        function abort(obj,varargin)
            try
                obj.active = false;
                obj.componentAbort(varargin{:});
            catch ME
                % convert hard error into soft error
                most.idioms.reportError(ME);
            end
        end
        
        function zprvMDFScalarExpand(obj,mdfVarName,N)
            if isscalar(obj.mdfData.(mdfVarName))
                obj.mdfData.(mdfVarName) = repmat(obj.mdfData.(mdfVarName),N,1);
            end
        end
        
        function zprvMDFVerify(obj,mdfVarName,validAttribArgs,assertFcn)
            val = obj.mdfData.(mdfVarName);
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
    end
    
    %% Internal methods
    methods (Access = protected)
        function updateProp = componentUpdateProperty(obj,propName,val)
        %   Updates property making sure 'live' restrictions are obeyed
        %
            if obj.numInstances <= 0
                updateProp = false;
                return
            end
            
            if ismember(propName,obj.PROP_TRUE_LIVE_UPDATE)
                updateProp = true;
                return
            end
            
            if isempty(obj.hSI) || ~isvalid(obj.hSI)
                % Component is used as a standalone application
                if obj.active && ~ismember(propName,obj.PROP_FOCUS_TRUE_LIVE_UPDATE)
                    tfSuccess = false;
                    updateProp = false;
                else
                    tfSuccess = true;
                    updateProp = true;
                end
            else
                % Component is used as a module of SI
                if strcmpi(obj.hSI.acqState,'focus') && ismember(propName,obj.PROP_FOCUS_TRUE_LIVE_UPDATE)
                    tfSuccess = true;
                    updateProp = true;
                elseif obj.hSI.active && ~obj.independentComponent
                    tfSuccess = obj.zzzUpdateProperty(propName,val);
                    updateProp = false;
                else
                    assert(~obj.active) % Sanity check
                    tfSuccess = true;
                    updateProp = true;
                end
            end
            
            if ~tfSuccess
                most.idioms.dispError('%s: Cannot set property %s.%s during an active acquisition\n',obj.COMPONENT_NAME,class(obj),propName);
            end
        end
        
        function executeFcn = componentExecuteFunction(obj,fncName,varargin)
        %   Interface method that allows the execution of particular functions
        %
            if obj.numInstances <= 0
                executeFcn = false;
                return
            end
            
            if ismember(fncName,obj.FUNC_TRUE_LIVE_EXECUTION)
                executeFcn = true;
                return
            end
            
            if isempty(obj.hSI) || ~isvalid(obj.hSI)
                % Component is used as a standalone application
                if obj.active && ~ismember(fncName,obj.FUNC_FOCUS_TRUE_LIVE_EXECUTION)
                    tfSuccess = false;
                    executeFcn = false;
                else
                    tfSuccess = true;
                    executeFcn = true;
                end
            else
                % Component is used as a module of SI
                if strcmpi(obj.hSI.acqState,'focus') && ismember(fncName,obj.FUNC_FOCUS_TRUE_LIVE_EXECUTION)
                    tfSuccess = true;
                    executeFcn = true;
                elseif obj.hSI.active && ~obj.independentComponent
                    tfSuccess = obj.zzzExecuteFunction(fncName,varargin);
                    executeFcn = false;
                else
                    assert(~obj.active) % Sanity check
                    tfSuccess = true;
                    executeFcn = true;
                end
            end
            
            if ~tfSuccess
                most.idioms.dispError('%s: Cannot execute function %s.%s during an active acquisition\n',obj.COMPONENT_NAME,class(obj),fncName);
            end
        end
        
        function componentShortWarning(obj,message,varargin)
            % issues a warning including the component name, without printing the stack
            most.idioms.warn([obj.COMPONENT_NAME ,': ',message],varargin{:});
        end
    end
    
     methods (Access = private)
        function tfSuccess = zzzUpdateProperty(obj,propName,val)
            if strcmpi(obj.hSI.acqState,'focus') && ~ismember(propName,obj.DENY_PROP_LIVE_UPDATE)
                obj.hSI.abort(true)
                
                assert(~obj.hSI.active); % sanity check
                assert(~obj.active); % sanity check
                try
                    obj.(propName) = val;
                catch ME
                    obj.hSI.startFocus();
                    rethrow(ME);
                end
                
                obj.hSI.startFocus();
                tfSuccess = true;
            else
                tfSuccess = false;
            end
        end
        
        function tfSuccess = zzzExecuteFunction(obj,fncName,args)
            if strcmpi(obj.hSI.acqState,'focus') && ~ismember(fncName,obj.DENY_FUNC_LIVE_EXECUTION)
                obj.hSI.abort(true)
                
                assert(~obj.hSI.active); % sanity check
                assert(~obj.active); % sanity check
                
                try
                    obj.(fncName)(args{:});
                catch ME
                    obj.hSI.startFocus();
                    rethrow(ME);
                end
                
                obj.hSI.startFocus();
                tfSuccess = true;
            else
                tfSuccess = false;
            end
        end
        
        function checkLivePropertiesExist(obj)
            mc = metaclass(obj);
            
            allobjprops = {mc.PropertyList.Name};
            checkprops('PROP_TRUE_LIVE_UPDATE'      ,allobjprops,'properties');
            checkprops('PROP_FOCUS_TRUE_LIVE_UPDATE',allobjprops,'properties');
            checkprops('DENY_PROP_LIVE_UPDATE'      ,allobjprops,'properties');
            
            allobjmethods = {mc.MethodList.Name};
            checkprops('FUNC_TRUE_LIVE_EXECUTION'      ,allobjmethods,'methods');
            checkprops('FUNC_FOCUS_TRUE_LIVE_EXECUTION',allobjmethods,'methods');            
            checkprops('DENY_FUNC_LIVE_EXECUTION'      ,allobjmethods,'methods');

            % nested function
            function checkprops(nameproplist,allprops,proptype)
                unknownprops = setdiff(obj.(nameproplist),allprops);
                if ~isempty(unknownprops)
                    obj.componentShortWarning(...
                        'The %s {''%s''} listed in %s do not exist in class %s',...
                        proptype,strjoin(unknownprops,''' '''),nameproplist,class(obj));
                end 
            end
        end
     end    
    
    %%% Hook methods
    methods (Access = protected, Hidden)
        function val = componentGetActiveOverride(obj,val) %#ok<INUSL>
            % overload this method if needed
        end
    end
    
    %%% Abstract methods
    methods (Abstract, Hidden, Access = protected)
        componentStart(obj);    % start the component
        componentAbort(obj);    % abort the component
    end
end


%--------------------------------------------------------------------------%
% Component.m                                                              %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
