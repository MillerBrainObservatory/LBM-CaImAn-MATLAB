function tf = isstring(val)
%ISSTRING Returns true if supplied value is a string

tf = ischar(val) && (isempty(val) || isvector(val));


end



%--------------------------------------------------------------------------%
% isstring.m                                                               %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
