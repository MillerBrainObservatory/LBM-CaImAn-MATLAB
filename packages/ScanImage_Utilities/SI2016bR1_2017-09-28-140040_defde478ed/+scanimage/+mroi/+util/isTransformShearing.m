function tf = isTransformShearing(A,v1,v2)
if nargin < 2 || isempty(v1)
    v1 = [0,1];
end

if nargin < 3 || isempty(v2)
    v2 = [1,0];
end

assert(dot(v1,v2) == 0);

v1t = scanimage.mroi.util.xformPoints(v1,A);
v2t = scanimage.mroi.util.xformPoints(v2,A);
origint = scanimage.mroi.util.xformPoints([0,0],A);

dotprod = dot(v1t-origint,v2t-origint);
tf = abs(dotprod) > eps; % ~= 0 with tolerance
end


%--------------------------------------------------------------------------%
% isTransformShearing.m                                                    %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
