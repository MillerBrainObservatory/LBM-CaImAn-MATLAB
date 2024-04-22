
function name = csv2name(varargin)
%CSV2NAME Convert comma seperated string values into dot-separated structure name

assert(iscellstr(varargin));

if nargin == 1
    name = varargin{1};
    return;
end

name = '';
for i=1:(nargin-1)
    name = [name varargin{i} '.'];
end

name = [name varargin{end}];

end



%--------------------------------------------------------------------------%
% csv2name.m                                                               %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
