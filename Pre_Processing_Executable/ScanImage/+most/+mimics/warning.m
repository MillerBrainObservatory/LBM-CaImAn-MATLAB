function warning(varargin)
%WARNING Mimic of built-in function 'warning', with stack tracing turned off. 

s = warning('off', 'backtrace');
warning(varargin{:});
warning(s);


%--------------------------------------------------------------------------%
% warning.m                                                                %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
