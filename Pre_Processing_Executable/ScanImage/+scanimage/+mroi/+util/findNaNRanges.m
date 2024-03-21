function nanRanges = findNaNRanges(data)
% finds the start and end indices of nan ranges in a data stream
% input: data - needs to be a vector of data
% outputs:
%   nanRanges- nx2 matrix, column 1 is start indices column 2 is end indices
%   
% example
%      findNaNRanges([1 2 3 NaN NaN 4 NaN])
%
%             ans =
% 
%                  4     5
%                  7     7
%
nans = any(isnan(data),2);

%find positive edges
nansshiftright = [false;nans(1:end-1)];
posedge = find(nans > nansshiftright);

nansshiftleft = [nans(2:end);false];
negedge = find(nans > nansshiftleft);

nanRanges = [posedge, negedge];
end


%--------------------------------------------------------------------------%
% findNaNRanges.m                                                          %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
