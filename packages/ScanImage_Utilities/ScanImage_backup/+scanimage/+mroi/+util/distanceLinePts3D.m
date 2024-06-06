function d = distanceLinePts3D(linePt,lineV,pts)
% calculates the shortest distance of points pts to a line defined by
% linePt and lineV
%
% inputs:
%   linePt: point on the line (3 element vector)
%   lineV:  directional vector of the line (3 element vector)
%   pts:    mx3 matrix of points
%
% outputs:
%   d: mx1 vector of distances for each point in pts
%
% use:
%    d = scanimage.mroi.util.distanceLinePts3D(pt,v,pts)
validateattributes(linePt,{'numeric'},{'vector','numel',3});
validateattributes(lineV,{'numeric'},{'vector','numel',3});
assert(norm(lineV)>0,'Directional vector for line cannot be a zero vector'); % could also just output NaNs for d instead
validateattributes(pts,{'numeric'},{'2d','ncols',3});

linePt = linePt(:);
lineV = lineV(:)./norm(lineV); % unit vector

origin = linePt;
origin_ = [0;0;0];

pt1 = linePt + lineV;
pt1_ = [0;0;1];

% pick an arbitrary vector normal to v. Criterion: dot(lineV,n1)=0
[~,idx]=max(abs(lineV)); % make sure we don't divide by zero
switch idx
    case 1
        n1 = [-(lineV(2)+lineV(3))/lineV(1);1;1];
    case 2
        n1 = [1;-(lineV(1)+lineV(3))/lineV(2);1];
    case 3
        n1 = [1;1;-(lineV(1)+lineV(2))/lineV(3)];
    otherwise
        error('Something bad happened');
end

n1 = n1./norm(n1); % unit vector
pt2 = linePt + n1;
pt2_ = [1;0;0];

n2 = cross(lineV,n1); % unit vector
pt3 = linePt + n2;
pt3_= [0;1;0];

pp = [origin,pt1,pt2,pt3];
pp(4,:) = 1;

pp_ = [origin_,pt1_,pt2_,pt3_];
pp_(4,:) = 1;

T = pp_ / pp;

pts = scanimage.mroi.util.xformPoints(pts,T);
d = sqrt(pts(:,1).^2 + pts(:,2).^2);
end

%--------------------------------------------------------------------------%
% distanceLinePts3D.m                                                      %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
