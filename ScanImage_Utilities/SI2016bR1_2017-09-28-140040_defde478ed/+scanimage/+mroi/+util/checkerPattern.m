function pattern = checkerPattern(resolutionXY,checkerSize)
if nargin < 2 || isempty(checkerSize)
   checkerSize = 2; 
end

unit = zeros(2*checkerSize);
unit(1:checkerSize,1:checkerSize) = 1;
unit((checkerSize+1):(2*checkerSize),(checkerSize+1):(2*checkerSize)) = 1;

repsXY = ceil(resolutionXY/(checkerSize*2));
pattern = repmat(unit,repsXY(2),repsXY(1));
pattern((resolutionXY(2)+1):end,:) = [];
pattern(:,(resolutionXY(1)+1):end) = [];
end

%--------------------------------------------------------------------------%
% checkerPattern.m                                                         %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
