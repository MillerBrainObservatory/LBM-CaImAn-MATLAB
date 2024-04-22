function warn(varargin)
    warnst = warning('off','backtrace');
    warning(varargin{:});
    warning(warnst);
end



%--------------------------------------------------------------------------%
% warn.m                                                                   %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
