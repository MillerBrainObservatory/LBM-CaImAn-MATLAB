function rms_ = rmsCalc(data)
    N = numel(data);
    
    rms_ = sqrt(1/N.*(sum(data.^2)));
end

%--------------------------------------------------------------------------%
% rmsCalc.m                                                                %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
