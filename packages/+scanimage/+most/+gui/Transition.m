classdef Transition < handle
    properties (SetAccess = private,Hidden)
        timerPeriod = round(1/30,3);
        hObject;
        propertyName;
        hTimer;
        startTime;
        duration;
        startVal;
        targetVal;
        trajectory;
        lastTrajectory;
        lastTimeFrac;
        callback;
        started = false;
    end    
    
    methods
        function obj = Transition(duration,hObject,propertyName,targetVal,trajectory,callback)
            % trajectory: function handle OR vector of numbers between 0 and 1 that describes
            % the path from current value to target value
            
            %%% argument validation
            if nargin<5 || isempty(trajectory)
                trajectory = @obj.cubicInOut;
            end
            
            if nargin<6 || isempty(callback)
                callback = [];                
            end
            
            if isa(trajectory,'function_handle')
                validateattributes(trajectory,{'function_handle'},{'scalar'});
            elseif ischar(trajectory)
                trajectory = str2func([mfilename('class') '.' trajectory]);
                try
                    trajectory(0);
                catch
                    error('invalid function: ''%s''',trajectory);
                end
            else
                validateattributes(trajectory,{'single','double'},{'vector','finite','nonnan'});
                assert(numel(trajectory) >= 2);
            end
            
            if ~isempty(callback)
                validateattributes(callback,{'function_handle'},{'scalar'});
            end
            
            validateattributes(duration,{'numeric'},{'scalar','nonnan','finite','nonnegative'});
            
            assert(isscalar(hObject) && isobject(hObject) && isvalid(hObject) && isa(hObject,'handle'));
            assert(ischar(propertyName) && isprop(hObject,propertyName));
            propVal = hObject.(propertyName);
            assert(strcmp(class(propVal),class(targetVal)),'The data class of the target value and the object property need to match');
            validateattributes(targetVal,{'single','double'},{});
            assert(isequal(size(propVal),size(targetVal)));
            
            %%% get Singleton
            obj = Singleton(obj,hObject,propertyName);
            obj.stop();
            
            obj.hObject = hObject;
            obj.propertyName = propertyName;
            obj.targetVal = targetVal;
            obj.duration = duration;
            obj.callback = callback;
            obj.trajectory = trajectory;
            
            obj.start();
        end
        
        function delete(obj)
            obj.stop();
            most.idioms.safeDeleteObj(obj.hTimer);
            remove = true;
            Singleton(obj,obj.hObject,obj.propertyName,remove);
            if ~isempty(obj.callback)
                obj.callback(obj.lastTimeFrac,obj.lastTrajectory);
            end
        end
    end
    
    %% trajectory functions
    % based on https://github.com/d3/d3-ease
    methods (Static)
        function v = linear(t)
            v = t;
        end
        
        function v = sinIn(t)
            v = 1 - cos(t .* pi./2);
        end
        
        function v = sinOut(t)
            v = sin(t .* pi./2);
        end
        
        function v = sinInOut(t)
            v =  (1 - cos(pi .* t)) ./ 2;
        end
        
        function v = expIn(t)
            v = 2.^(10 .* t - 10);
        end
            
        function v = expOut(t)
            v = 1 - 2.^( -10 .* t);
        end
        
        function v = expInOut(t)
            v = (t <= 0.5) .* ( 2 .^ (20 .* t - 10) ) ./ 2 + ...
                (t >  0.5) .* ( 2 - 2 .^ (10 - 20 .* t) ) ./ 2;
        end
        
        function v = cubicIn(t)
            v = t .^ 3;
        end
        
        function v = cubicOut(t)
            t = t-1;
            v =  t .^ 3 + 1;
        end
        
        function v = cubicInOut(t)
            v = (t <= 0.5) .* (t.*2).^3 ./ 2 + ...
                (t >  0.5) .* ((t.*2-2).^3 + 2) ./ 2;
        end
        
        function v = circleIn(t)
            v = 1 - sqrt(1 - t.^2);
        end

        function v = circleOut(t)
            v = sqrt(1 - (t-1).^2);
        end

        function v = circleInOut(t)
            v = (t <= 0.5) .* ( 1 - sqrt(1 - (t.*2).^2) ) ./ 2 + ...
                (t >  0.5) .* (sqrt(1 - (t*.2-2).^2) + 1) ./ 2;
            v = real(v);
        end
        
        function v = bounceOut(t)
            b = [4/11 6/11 8/11 3/4 9/11 10/11 15/16 21/22 63/64];
            b0 = b(1)^-2;
            
            v = (t < b(1)) .* (b0 .* t.^2) + ...
                (t >= b(1) & t < b(3)) .* (b0 .* (t-b(2)).^2 + b(4)) + ...
                (t >= b(3) & t < b(6)) .* (b0 .* (t-b(5)).^2 + b(7)) + ...
                (t >= b(6)) .* (b0 .* (t-b(8)).^2 + b(9));
        end
        
        function v = bounceIn(t)
            v = 1 - most.gui.Transition.bounceOut(1 - t);
        end
        
        function v = bounceInOut(t)
            v = (t <= 0.5) .* ( 1 - most.gui.Transition.bounceOut( 1 - t.*2 ) ) ./ 2 + ...
                (t >  0.5) .* (most.gui.Transition.bounceOut(t.*2 - 1) + 1) ./ 2;
        end
    end
    
    %% Internal functions
    methods (Access = private)
        function start(obj)
            if obj.started
                return
            end
            
            obj.startVal = obj.hObject.(obj.propertyName);
            obj.lastTrajectory = 0;
            obj.lastTimeFrac = 0;
            
            if isequal(obj.startVal,obj.targetVal)
                obj.lastTrajectory = 1;
                obj.lastTimeFrac = 1;
                obj.delete(); % nothing to transition to
                return
            end
            
            if isnumeric(obj.trajectory)
                interpolationMethod = 'pchip';
                obj.trajectory = griddedInterpolant(linspace(0,1,numel(obj.trajectory)),obj.trajectory(:)',interpolationMethod,'none');
            end
            
            obj.startTime = tic();
            obj.started = true;
                        
            if obj.duration > 0
                if isempty(obj.hTimer)
                    timerName = sprintf('%s.%s transition timer',class(obj.hObject),obj.propertyName);
                    obj.hTimer = timer('Name',timerName,'ExecutionMode','fixedRate','TimerFcn',@(varargin)obj.timerFcn);
                end
                obj.hTimer.Period = obj.timerPeriod;
                start(obj.hTimer);
            else
                obj.timerFcn();
            end
        end
        
        function stop(obj)
            if ~obj.started
                return
            end
            
            obj.started = false;
            if ~isempty(obj.hTimer)
                stop(obj.hTimer);
            end
        end
        
        function timerFcn(obj)            
            if ~isvalid(obj) || ~isvalid(obj.hObject)
                most.idioms.safeDeleteObj(obj);
                return
            end
            
            if ~obj.started
                return
            end
            
            if obj.duration > 0
                timeFrac = toc(obj.startTime)/obj.duration;
            else
                timeFrac = 1;
            end
            
            timeFrac_bounded = max(min(timeFrac,1),0);
            obj.lastTimeFrac = timeFrac_bounded;
            
            try
                traj = obj.trajectory(timeFrac_bounded);
                if traj ~= obj.lastTrajectory
                    obj.lastTrajectory = traj;
                    obj.hObject.(obj.propertyName) = obj.startVal + (obj.targetVal-obj.startVal) .* traj;
                end
            catch ME
                obj.delete();
                most.idioms.reportError(ME);
            end
            
            if timeFrac >= 1
                obj.stop();
                obj.delete();
            end
        end
    end
end

%% Local functions
function obj = Singleton(obj,hObject,propertyName,remove)
persistent hObjects
persistent propertyNames
persistent objs

if nargin < 4 || isempty(remove)
    remove = false;
end

if isempty(hObject) || isempty(propertyName)
    return
end

if isempty(hObjects)
    idx = [];
else
    objectmask = cellfun(@(o)eq(hObject,o),hObjects);
    propertymask = strcmpi(propertyNames(objectmask),propertyName);
    idxs = 1:numel(hObjects);
    idxs = idxs(objectmask);
    idx = idxs(propertymask);
end

if ~isempty(idx) && remove
    hObjects(idx) = [];
    propertyNames(idx) = [];
    objs(idx) = [];
    return
end

if isempty(idx)
    hObjects{end+1} = hObject;
    propertyNames{end+1} = propertyName;
    objs{end+1} = obj;
else
    delete(obj);
    obj = objs{idx};
end

end





%--------------------------------------------------------------------------%
% Transition.m                                                             %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
