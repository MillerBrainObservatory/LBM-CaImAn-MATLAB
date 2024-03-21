function test9Callback()

global callbackStruct9

disp('howdy');

if callbackStruct9.stopInCallback
    hTask = callbackStruct9.task;
    hTask.stop();
end


%--------------------------------------------------------------------------%
% test9Callback.m                                                          %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
