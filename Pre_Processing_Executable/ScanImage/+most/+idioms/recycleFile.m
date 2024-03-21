function recycleFile(filename)
%RECYCLEFILE Recycles, rather than deletes, specified filename

status = recycle;
recycle on;
delete(filename);
recycle(status);

end



%--------------------------------------------------------------------------%
% recycleFile.m                                                            %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
