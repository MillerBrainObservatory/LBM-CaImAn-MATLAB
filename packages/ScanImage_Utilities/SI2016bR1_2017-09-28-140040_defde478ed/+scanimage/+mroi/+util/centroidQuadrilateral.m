function ctr = centroidQuadrilateral(pt1,pt2,pt3,pt4)

if nargin < 2
    pt2 = pt1(2,:);
    pt3 = pt1(3,:);
    pt4 = pt1(4,:);
    pt1 = pt1(1,:);
end

validateattributes(pt1,{'numeric'},{'size',[1,2]});
validateattributes(pt2,{'numeric'},{'size',[1,2]});
validateattributes(pt3,{'numeric'},{'size',[1,2]});
validateattributes(pt4,{'numeric'},{'size',[1,2]});

ctr1 = centroidTriangle(pt1,pt2,pt3);
ctr2 = centroidTriangle(pt1,pt3,pt4);
ctr3 = centroidTriangle(pt1,pt2,pt4);
ctr4 = centroidTriangle(pt2,pt3,pt4);

ctr = scanimage.mroi.util.intersectLines(ctr1,ctr2-ctr1,ctr3,ctr4-ctr3);
end

function ctr = centroidTriangle(pt1,pt2,pt3)
pt1_2 = pt1 + (pt2-pt1)./2;
pt2_3 = pt2 + (pt3-pt2)./2;

v1 = pt3-pt1_2;
v2 = pt1-pt2_3;

ctr = scanimage.mroi.util.intersectLines(pt1_2,v1,pt2_3,v2);
end

%--------------------------------------------------------------------------%
% centroidQuadrilateral.m                                                  %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
