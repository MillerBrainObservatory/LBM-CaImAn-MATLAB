classdef DelayedEventListener < handle    
    properties
        delay;
        enabled = true;
    end
    
    properties (Access = private)
       hDelayTimer;
       delayTimerRunning = false;
       lastDelayFunctionCall;
       functionHandle;
       hListener;
    end
    
    methods
        function obj = DelayedEventListener(delay,varargin)            
            obj.hDelayTimer = timer(...
                'TimerFcn',@obj.doNothing,...
                'StopFcn',@obj.timerCallback,...
                'BusyMode','drop',...
                'ExecutionMode','singleShot',...
                'StartDelay',1,... % overwritten later
                'ObjectVisibility','off');
            
            obj.delay = delay;
            
            if ischar(varargin{end}) && strcmpi(varargin{end},'weak')
                obj.hListener = most.idioms.addweaklistener(varargin{1:end-1});
            else
                obj.hListener = addlistener(varargin{:});
            end
            obj.functionHandle = obj.hListener.Callback;
            obj.hListener.Callback = @(varargin)obj.delayFunction(varargin);
            
            listenerSourceNames = strjoin(cellfun(@(src)class(src),obj.hListener.Source,'UniformOutput',false));
            set(obj.hDelayTimer,'Name',sprintf('Delayed Event Listener Timer %s:%s',listenerSourceNames,obj.hListener.EventName));
        end
        
        function delete(obj)
            obj.hDelayTimer.StopFcn = []; % stop will be called when deleting the timer. Avoid the stop function
            most.idioms.safeDeleteObj(obj.hListener);
            most.idioms.safeDeleteObj(obj.hDelayTimer);
        end
    end
    
    methods
        function delayFunction(obj,varargin)
            if obj.enabled
                % restart timer
                obj.lastDelayFunctionCall = tic();
                if ~obj.delayTimerRunning
                    obj.hDelayTimer.StartDelay = obj.delay;
                    obj.delayTimerRunning = true;
                    start(obj.hDelayTimer);
                end 
            end
        end
        
        function doNothing(obj,varargin)
        end
        
        function timerCallback(obj,varargin)
            dt = toc(obj.lastDelayFunctionCall);
            newDelay = obj.delay-dt;
            
            if newDelay > 0
                % rearm timer
                newDelay = (ceil(newDelay*1000)) / 1000; % timer delay is limited to 1ms precision
                obj.hDelayTimer.StartDelay = newDelay;
                start(obj.hDelayTimer);
            else
                % execute delayed callback
                obj.delayTimerRunning = false;
                obj.executeFunctionHandle(varargin);
            end
        end
        
        function executeFunctionHandle(obj,varargin)
            obj.functionHandle(varargin);
        end
    end
    
    methods
        function set.delay(obj,val)
            validateattributes(val,{'numeric'},{'scalar','positive','nonnan','finite'});
            val = (ceil(val*1000)) / 1000; % timer delay is limited to 1ms precision
            obj.delay = val;
        end
    end
end


%--------------------------------------------------------------------------%
% DelayedEventListener.m                                                   %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
