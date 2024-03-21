classdef GenericEventData < event.EventData
    %GENERICEVENTDATA Generic event data class with a UserData field
    
    properties
        UserData;
    end
    
    methods
        
        function obj = GenericEventData(userdata)
            % obj = GenericEventData()
            % obj = GenericEventData(userdata)
            if nargin
                obj.UserData = userdata;
            end
        end        
        
    end
   
end



%--------------------------------------------------------------------------%
% GenericEventData.m                                                       %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
