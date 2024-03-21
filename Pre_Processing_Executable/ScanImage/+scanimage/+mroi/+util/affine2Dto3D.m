function T = affine2Dto3D( T )
T(4,4) = T(3,3); % expand matrix to 4x4
T(11) = 1;
T([4,8,13,14]) = T([3,7,9,10]);
T([3,7,9,10]) = 0;
end



%--------------------------------------------------------------------------%
% affine2Dto3D.m                                                           %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
