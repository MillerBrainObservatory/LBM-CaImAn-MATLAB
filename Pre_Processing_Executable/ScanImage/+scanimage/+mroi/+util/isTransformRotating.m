function tf = isTransformRotating(A,v,tolerance)
if nargin < 2 || isempty(v)
    v = [1,0];
end

if nargin < 3 || isempty(tolerance)
    tolerance = eps;
end


origint = scanimage.mroi.util.xformPoints([0,0],A);
vt = scanimage.mroi.util.xformPoints(v,A) - origint;

tf = ~all( (v/norm(v) - vt/norm(vt)) <= tolerance);
end


%--------------------------------------------------------------------------%
% isTransformRotating.m                                                    %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
