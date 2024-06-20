function X = intersectLines(pt1,v1,pt2,v2)
assert(length(pt1)==2);
assert(length(v1)==2);
assert(length(pt2)==2);
assert(length(v2)==2);
% line 1: pt1, v1
% line 2: pt2, v2

pt11 = pt1 + v1;
pt22 = pt2 + v2;

n1 = [pt11(2)-pt1(2),pt1(1)-pt11(1)];
n2 = [pt22(2)-pt2(2),pt2(1)-pt22(1)];

r1 = dot(n1,[pt1(1),pt1(2)]);
r2 = dot(n2,[pt2(1),pt2(2)]);

r = [r1;r2];
l = [n1;n2];

X = mldivide(l,r)';
end

%--------------------------------------------------------------------------%
% intersectLines.m                                                         %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
