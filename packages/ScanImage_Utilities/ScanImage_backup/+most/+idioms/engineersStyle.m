function str = engineersStyle(x,unit,format)
    % based on http://www.mathworks.com/matlabcentral/answers/892-engineering-notation-printed-into-files
    % credits to Jan Simon
    
    if nargin < 2 || isempty(unit)
        unit = '';
    end
    
    if nargin < 3 || isempty(format)
        format = '%.1f';
    end
    
    if isempty(x)
        str = '';
        return
    end
    
    exponent = 3 * floor(log10(x) / 3);
    y = x / (10 ^ exponent);
    expValue = [24,21,18,15,12,9,6,3,0,-3,-6,-9,-12,-15,-18,-21,-24];
    expName = {'Y','Z','E','P','T','G','M','k','','m','u','n','p','f','a','z','y'};
    expIndex = (exponent == expValue);
    if any(expIndex)  % Found in the list:
        str = sprintf([format '%s%s'],y,expName{expIndex},unit);
    else
        str = sprintf('%fe%+04d%s',y,exponent,unit);
    end
end


%--------------------------------------------------------------------------%
% engineersStyle.m                                                         %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
