function [offsetX,offsetY,scaleX,scaleY,rotation,shear] = paramsFromTransform(T)
if scanimage.mroi.util.isTransformPerspective(T)
%     offsetX = NaN;
%     offsetY = NaN;
%     scaleX = NaN;
%     scaleY = NaN;
%     rotation = NaN;
%     shear = NaN;
%     return
    
    T([3,6]) = 0; % ignoring perspective entries for the moment. TODO: find better solution
end

ctr = scanimage.mroi.util.xformPoints([0.5,0.5],T);
offsetX = ctr(1)-0.5;
offsetY = ctr(2)-0.5;

toOrigin = eye(3);
toOrigin([7,8]) = [-ctr(1),-ctr(2)];

T = toOrigin * T;

[ux,~] = getUnitVectors(T);
rot = atan2(ux(2),ux(1));
rotation = rot * 180 / pi;

toUnRotated = [cos(rot) sin(rot) 0; ...
              -sin(rot) cos(rot) 0; ...
               0         0         1];

T = toUnRotated * T;

[ux,uy] = getUnitVectors(T);
scaleX = norm(ux);
scaleY = dot(uy,[0,1]);

toUnScaled = eye(3);
toUnScaled([1,5]) = [1/scaleX,1/scaleY];
T = toUnScaled * T;

[~,uy] = getUnitVectors(T);
shear = uy(1);
end

function [ux,uy] = getUnitVectors(T)
% returns transformed unit vectors
X = [1.5,0.5];
Y = [0.5,1.5];
O = [0.5,0.5];
pts = scanimage.mroi.util.xformPoints([X;Y;O],T);
X = pts(1,:);
Y = pts(2,:);
O = pts(3,:);
ux = X-O;
uy = Y-O;
end

%--------------------------------------------------------------------------%
% paramsFromTransform.m                                                    %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
