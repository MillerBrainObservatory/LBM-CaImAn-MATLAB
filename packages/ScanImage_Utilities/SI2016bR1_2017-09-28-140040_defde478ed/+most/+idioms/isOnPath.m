function tf = isOnPath(path_)
path_ = fullfile(path_,''); % ensure right formatting
currentpath = strsplit(path(),';');
tf = any(strcmpi(path_,currentpath)); % case insensitive
end


%--------------------------------------------------------------------------%
% isOnPath.m                                                               %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
