classdef (ConstructOnLoad) frameUpdateEventData < event.EventData
   properties
       camSource;
   end
   methods
       function data = frameUpdateEventData(camSource)
          data.camSource = camSource; 
       end
   end
end

%--------------------------------------------------------------------------%
% frameUpdateEventData.m                                                   %
% Copyright � 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
