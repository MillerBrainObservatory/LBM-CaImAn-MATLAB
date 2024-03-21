classdef EventGenerator < handle
    %EVENTGENERATOR Overrides notify to enable passing of arbitrary event
    %data.
    %
    %Note: Subclasses with events with non-public NotifyAccess should not
    %derive from EventGenerator.
    
    properties
        hEventData;
    end
            
    %% PUBLIC METHODS
    
    methods
        
        function obj = EventGenerator
            obj.hEventData = most.GenericEventData;            
        end
        
    end
    
    methods
        
        % Listeners receive a most.GenericEventData object, with the
        % specified eventData in the UserData field.
        function notify(obj,eventName,eventData)
            edata = obj.hEventData;
            if nargin < 3
                edata.UserData = [];
            else
                edata.UserData = eventData;
            end
            notify@handle(obj,eventName,edata);
        end
    end
    
end



%--------------------------------------------------------------------------%
% EventGenerator.m                                                         %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
