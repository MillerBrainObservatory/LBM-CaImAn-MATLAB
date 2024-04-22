function hTask = safeCreateTask(taskname, hDaqSys)
    
    if nargin < 2
        hDaqSys = dabs.ni.daqmx.System;
    end
    
    if most.util.checkForTask(taskname, true, hDaqSys)
        warning OFF BACKTRACE
        warning('Task ''%s'' already exists. Scanimage may not have shut down properly last time.\n  Scanimage will attempt to delete the old task and continue.', taskname);
        warning ON BACKTRACE
    end
    
    hTask = dabs.ni.daqmx.Task(taskname);
    
end



%--------------------------------------------------------------------------%
% safeCreateTask.m                                                         %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
