function denyInFreeVersion(functionDescription,hardError)
if nargin < 1 || isempty(functionDescription)
    functionDescription = [];
end

if nargin < 2 || isempty(hardError)
    hardError = true;
end

if isempty(functionDescription)
    message = 'This functionality is not available in the free version of ScanImage';
else
    message = sprintf('%s is not available in the free version of ScanImage',functionDescription);
end

if hardError
    error('%s',message);
else
    most.idioms.warn('%s',message);
end

end

%--------------------------------------------------------------------------%
% denyInFreeVersion.m                                                      %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
