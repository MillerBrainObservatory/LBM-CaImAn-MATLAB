function T = paramsToTransform(offsetX,offsetY,scaleX,scaleY,rotation,shear)
toOrig = eye(3);
toOrig([7,8]) = [-0.5,-0.5];
fromOrig = eye(3);
fromOrig([7,8]) = [0.5,0.5];

S = eye(3);
S([1,5]) = [scaleX,scaleY];

rot = -rotation * pi / 180;
R = [cos(rot) sin(rot) 0;...
    -sin(rot) cos(rot) 0;...
     0        0        1];

SH = eye(3);
SH(4) = shear;

O = eye(3);
O([7,8]) = [offsetX,offsetY];

T = O * fromOrig * R * S * SH * toOrig;
end

%--------------------------------------------------------------------------%
% paramsToTransform.m                                                      %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
