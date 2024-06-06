function tf = isTransformPerspective(A)
tolerance = 10 * eps;
tf = abs(A(3))>tolerance || abs(A(6))>tolerance;
end


%--------------------------------------------------------------------------%
% isTransformPerspective.m                                                 %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
