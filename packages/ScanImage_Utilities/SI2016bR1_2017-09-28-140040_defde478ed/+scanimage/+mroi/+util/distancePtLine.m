function dist = distancePtLine(pt,ptL,ptV)
% calculates the distance of a point from a line
% pt: point not on line
% ptL,ptV: definition on line, ptL = point on Line, ptV = line vector

n = [ptV(2),-ptV(1)];
X = scanimage.mroi.util.intersectLines(pt,n,ptL,ptV);

dist = norm(pt-X);

end



%--------------------------------------------------------------------------%
% distancePtLine.m                                                         %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
