function tf = isValidObj(obj)
    %ISVALIDOBJ Determines is the argument is an object handle and if the handle actually
    % points to a valid object (isobject does not actually tell you this)
    tf = ~isempty(obj) && ( ...
                            ( isobject(obj) && all(isvalid(obj)) ) || ...
                            ( all(ishandle(obj)) ) ...
                           );
end



%--------------------------------------------------------------------------%
% isValidObj.m                                                             %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
