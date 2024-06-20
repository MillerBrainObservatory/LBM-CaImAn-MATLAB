function tf = isEmptyDouble(val)
tf = isa(val,'double') && isequal(size(val),[0 0]);
end


%--------------------------------------------------------------------------%
% isEmptyDouble.m                                                          %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
