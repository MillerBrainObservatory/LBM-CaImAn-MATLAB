function c = name2csv(str)
%TOCSV Summary of this function goes here
%   Detailed explanation goes here

c = {};

while true
    [pre,post] = strtok(str,'.');
    
    c{end+1} = pre;
    
    if isempty(post)
        break;
    else
        str = post(2:end);
    end    
end



%--------------------------------------------------------------------------%
% name2csv.m                                                               %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
