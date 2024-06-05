classdef UserFunctions < scanimage.interfaces.Component
    % UserFunctions    Functionality to store/load user-functions

    %% USER PROPS
    properties(SetObservable)
        userFunctionsCfg = struct('EventName',cell(0,1),'UserFcnName',cell(0,1),'Arguments',cell(0,1),'Enable',cell(0,1)); % Nx1 struct array of CFG user function info structs.
        userFunctionsUsr = struct('EventName',cell(0,1),'UserFcnName',cell(0,1),'Arguments',cell(0,1),'Enable',cell(0,1)); % Mx1 struct array of USR user function info structs.
        userFunctionsOverride = struct('Function',cell(0,1),'UserFcnName',cell(0,1),'Enable',cell(0,1)); % Px1 struct array of user override functions
    end
    
    
    %% FRIEND PROPS
    properties(Hidden,SetAccess=?scanimage.interfaces.Class)
        userFunctionsEvents = zlclInitUserFunctionsEvents();                % column cellstr of events for user-functions.
        userFunctionsUsrOnlyEvents = zlclInitUserFunctionsUsrOnlyEvents();  % column cellstr of USR-specific events for user-functions
        userFunctionsOverrideFunctions = {'frameAcquiredFcn'};
    end
    
    %% INTERNAL PROPS
    properties(Hidden, SetAccess=protected)
        userFunctionsCfgListeners;                                          % Column cell array containing listener objects for user functions (CFG). There is a 1-1 correspondence between these objects and the elements of userFunctionsCfg.
        userFunctionsUsrListeners;                                          % Column cell array containing listener objects for user functiosn (USR). There is a 1-1 correspondence between these objects and the elements of userFunctionsUsr.
        userFunctionsOverriddenFcns2UserFcns;                               % Scalar struct. Fields: currently overridden fcns. vals: user fcns to call instead.
    end
    
    %%% ABSTRACT PROP REALIZATION (most.Model)
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = zlclInitPropAttributes();
        mdlHeaderExcludeProps = {};
    end
    
    %%% Abstract prop realization(scanimage.interfaces.Component)
    properties (Hidden, SetAccess = protected)
        numInstances = 1;
    end
    
    properties (Constant, Hidden)
        COMPONENT_NAME = 'UserFcns';                                        % [char array] short name describing functionality of component e.g. 'Beams' or 'FastZ'
        PROP_TRUE_LIVE_UPDATE = {};                                         % Cell array of strings specifying properties that can be set while the component is active
        PROP_FOCUS_TRUE_LIVE_UPDATE = {};                                   % Cell array of strings specifying properties that can be set while focusing
        DENY_PROP_LIVE_UPDATE = {   'userFunctionsCfg',...
                                    'userFunctionsUsr',...
                                    'userFunctionsOverride'};               % Cell array of strings specifying properties for which a live update is denied (during acqState = Focus)
        
        FUNC_TRUE_LIVE_EXECUTION = {};                                      % Cell array of strings specifying functions that can be executed while the component is active
        FUNC_FOCUS_TRUE_LIVE_EXECUTION = {};                                % Cell array of strings specifying functions that can be executed while focusing
        DENY_FUNC_LIVE_EXECUTION = {};                                      % Cell array of strings specifying functions for which a live execution is denied (during acqState = Focus)
    end
   
    %% LIFECYCLE
     methods (Hidden)
        function obj = UserFunctions(hSI)
            obj = obj@scanimage.interfaces.Component(hSI,[]);
        end
        
        function delete(~)
           % Nothing to do here 
        end
     end
    
    %% PROP ACCESS
    methods
        function set.userFunctionsCfg(obj,val)
            obj.assertSINotActive('userFunctionsCfg');
            if isempty(val)
                val = struct('EventName',cell(0,1),'UserFcnName',[],'Arguments',[],'Enable',[]);
            end
            
            % Validate the new value
            obj.zprpUserFunctionValidate(val,'EventName',obj.userFunctionsEvents);
            
            % Adjust listeners
            obj.zprvUserFunctionsConfigureListeners('userFunctionsCfgListeners',val);
            obj.userFunctionsCfg = val;
        end
        
        function set.userFunctionsUsr(obj,val)
            obj.assertSINotActive('userFunctionsUsr');
            if isempty(val)
                val = struct('EventName',cell(0,1),'UserFcnName',[],'Arguments',[],'Enable',[]);
            end
            
            % Validate new value
            allEvents = [obj.userFunctionsEvents;obj.userFunctionsUsrOnlyEvents];
            obj.zprpUserFunctionValidate(val,'EventName',allEvents);
            
            % Adjust listeners
            obj.zprvUserFunctionsConfigureListeners('userFunctionsUsrListeners',val);
            obj.userFunctionsUsr = val;
        end
        
        function set.userFunctionsOverride(obj,val)
            obj.assertSINotActive('userFunctionsOverride');
            if isempty(val)
                val = struct('Function',cell(0,1),'UserFcnName',[],'Enable',[]);
            end
            obj.zprpUserFunctionValidate(val,'Function',obj.userFunctionsOverrideFunctions,false);
            
            % Set up userFunctionsOverriddenFcns2UserFcns
            fcnMap = struct();
            for c = 1:numel(val)
                s = val(c);
                if s.Enable
                    assert(~isfield(fcnMap,s.Function),...
                        'Function ''%s'' is overridden more than once.',s.Function);
                    fcnMap.(s.Function) = s.UserFcnName;
                end
            end
            obj.userFunctionsOverriddenFcns2UserFcns = fcnMap; %#ok<MCSUP>
            obj.userFunctionsOverride = val;
        end
    end  % end user-function-related public methods
    
    %% INTERNAL METHODS
    methods(Hidden, Access = private)
        %TODO: Replace with Component mechanism!
        function assertSINotActive(obj,name)
            assert(~obj.hSI.active,'Cannot access ''%s'' during an active acquisition',name);
        end
        
        function zprpUserFunctionValidate(~,userFcnInfo,eventFieldName,eventsList,tfArguments)
            if nargin < 5
                tfArguments = true;
            end
            
            % Check that the right struct fields are present
            expectedFields = {eventFieldName;'UserFcnName';'Enable'};
            if tfArguments
                expectedFields = [expectedFields;'Arguments'];
            end
            if ~isstruct(userFcnInfo) || ...
                    ~isequal(sort(fieldnames(userFcnInfo)),sort(expectedFields))
                errStr = sprintf('''%s'', ',expectedFields{:});
                errStr = errStr(1:end-2);
                error('SI:invalidUserFcnFields',...
                    'Expected value to be a struct with fields %s.',errStr);
            end
            
            % All events must be in the eventsList
            evts = {userFcnInfo.(eventFieldName)}';
            assert(all(ismember(evts,eventsList)),'One or more invalid %s.',eventFieldName);
            
            % Arguments
            if tfArguments
                args = {userFcnInfo.Arguments}';
                tfArgsOk = cellfun(@(x)iscell(x)&&(isvector(x)||isequal(x,{})),args);
                if any(~tfArgsOk)
                    error('SI:invalidUserFunctionArguments',...
                        'Arguments for a user function must be a vector cell array.');
                end
            end
            
            % Enable
            enable = {userFcnInfo.Enable}';
            tfEnableOk = cellfun(@(x)isscalar(x)&&(islogical(x)||isnumeric(x)),enable);
            assert(all(tfEnableOk),'Enable field must be a scalar logical.');
        end
        
        function zprvUserFunctionsConfigureListeners(obj,listenerProp,newUserFcnInfo)
            % Configure listeners for user functions.
            % listenerProp: property containing listeners
            % newUserFcnInfo: user function info structs
            %
            % The backend of user functions is implemented using arrays of
            % listener objects that correspond precisely (ie in a 1-1
            % manner) with the userFunction struct arrays. Whenever a
            % userFunction struct array is updated, the corresponding array
            % of listeners is updated accordingly.
            
            Nnew = numel(newUserFcnInfo);
            
            listnrs = obj.(listenerProp);
            
            if numel(listnrs) > Nnew
                % Delete all extra listeners
                for c = Nnew+1:numel(listnrs)
                    delete(listnrs{c});
                end
                listnrs = listnrs(1:Nnew);
            elseif numel(listnrs) < Nnew
                % Pad listener vector with empty array []
                listnrs{Nnew,1} = [];
            end
            assert(numel(listnrs)==Nnew);
            
            % Setup listeners
            for c = 1:Nnew
                if isempty(listnrs{c})
                    listnrs{c} = obj.addlistener(newUserFcnInfo(c).EventName,...
                        @(src,evt)obj.zprvUserFunctionsGenericCallback(newUserFcnInfo(c),src,evt));
                else
                    listnrs{c}.EventName = newUserFcnInfo(c).EventName;
                    listnrs{c}.Callback = @(src,evt)obj.zprvUserFunctionsGenericCallback(newUserFcnInfo(c),src,evt);
                end
                listnrs{c}.Enabled = logical(newUserFcnInfo(c).Enable);
            end
            
            obj.(listenerProp) = listnrs;
        end
        
        function zprvUserFunctionsGenericCallback(~,userFcnInfo,src,evt)
            feval(userFcnInfo.UserFcnName,src,evt,userFcnInfo.Arguments{:});
        end
    end
    
    %%% Abstract method implementations (scanimage.interfaces.Component)
    methods (Access = protected)
        function componentStart(~)
        %   Runs code that starts with the global acquisition-start command
        end
        
        function componentAbort(~)
        %   Runs code that aborts with the global acquisition-abort command
        end
    end
   
    %% FRIEND EVENTS
    events (NotifyAccess = {?scanimage.interfaces.Class}) % use ?scanimage.components.Component attribute to distinguish cfg/usr-only events (arbitrary hack)
        acqModeArmed;               % Fires when a GRAB or LOOP acquisistion mode has been started and acqusition is waiting for a trigger. 
        acqModeStart;               % Fires when a GRAB or LOOP acquisition mode has been started.
        acqModeDone;                % Fires when a GRAB or LOOP acquisition mode has completed.
        acqStart;                   % Fires when a new acquisition within an ongoing GRAB/LOOP has been started.
        acqDone;                    % Fires when a GRAB acquisition, or single iteration of LOOP acquisition, has completed
        acqAbort;                   % Fires when a GRAB or LOOP acquisition has been aborted
        sliceDone;                  % Fires when single slice of a multi-slice GRAB/LOOP acquisition has completed
        focusStart;                 % Fires when a FOCUS acquisition has been started.
        focusDone;                  % Fires when FOCUS acquisition is completed
        frameAcquired;              % Fires when acquisition of frame has been completed
        overvoltage;                % Fires when the digitizer experiences a overvoltage condition
        
        onDmdStimStart;             % Fires when cmd to perform an on demand stim is received, before the trigger is sent
        onDmdStimSingleComplete;    % Fires when an on demand stim completes if multiple outputs are allowed; more stims can be externally triggered
        onDmdStimComplete;          % Fires when an on demand stim completes if multiple outputs are not allowed; no more stims will occur until next on demand command
        onDmdStimExtSel;            % Fires when an external on demand stimulus selection occurs
        seqStimStart;               % Fires when a sequence stimulation begins
        seqStimAdvance;             % Fires when a sequence element is complete and sequence advances to the next stim
        seqStimSingleComplete;      % Fires when a single sequence is complete
        seqStimComplete;            % Fires when the last sequence is complete
        photostimAbort;             % Firse when photostimulation module aborts
    end
    
    % Built-in user-only events
    events (NotifyAccess = {?scanimage.interfaces.Class}) % use ?scanimage.SI attribute to distinguish cfg/usr-only events (arbitrary hack)
        applicationOpen;          % Fires when application is finished starting up
        applicationWillClose;     % Fires when application is about to close
    end
    
    events (NotifyAccess = {?scanimage.interfaces.Class})
        motorPositionUpdate; %Signals that motor position has been, or may have been, updated
    end
end

%% LOCAL 
function evs = zlclInitUserFunctionsEvents()
mc = ?scanimage.components.UserFunctions;
allEvents = mc.Events;
tf = cellfun(@(x)isequal(x.DefiningClass,mc) && ismembermetaclass(?scanimage.interfaces.Class,x.NotifyAccess) && ~x.Hidden,allEvents);
evs = allEvents(tf);
evs = cellfun(@(x)x.Name,evs,'UniformOutput',false);
end

function evs = zlclInitUserFunctionsUsrOnlyEvents()
mc = ?scanimage.components.UserFunctions;
allEvents = mc.Events;
tf = cellfun(@(x)isequal(x.DefiningClass,mc)&&ismembermetaclass(?scanimage.interfaces.Class,x.NotifyAccess)&&~x.Hidden,allEvents);
evs = allEvents(tf);
evs = cellfun(@(x)x.Name,evs,'UniformOutput',false);
end

function tf = ismembermetaclass(metaClass,cellArrayMetaClasses)
% ismember does not support meta classes (Matlab R2013b)
% this function works around that
tf = false;
for i = 1:length(cellArrayMetaClasses)
   tf = or(tf,metaClass == cellArrayMetaClasses{i});
end
end

function s = zlclInitPropAttributes()
s = struct();
s.userFunctionsCfg = struct();
s.userFunctionsUsr = struct();
s.userFunctionsOverride = struct();
end


%--------------------------------------------------------------------------%
% UserFunctions.m                                                          %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
