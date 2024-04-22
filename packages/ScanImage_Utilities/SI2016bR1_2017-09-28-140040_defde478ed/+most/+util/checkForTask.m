function tf = checkForTask(taskname, del, daqmxsys)
    
    if nargin < 3 || isempty(daqmxsys)
        daqmxsys = dabs.ni.daqmx.System;
    end
    
    tf = daqmxsys.taskMap.isKey(taskname);
    
    if tf && del
        delete(daqmxsys.taskMap(taskname));
    end

end



%--------------------------------------------------------------------------%
% checkForTask.m                                                           %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
