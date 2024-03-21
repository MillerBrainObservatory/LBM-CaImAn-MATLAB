function tf = isValidObj(obj)
    %ISVALIDOBJ Determines is the argument is an object handle and if the handle acutually
    % points to a valid object (isobject does not actually tell you this)
    tfObj = ~isempty(obj) && isobject(obj) && all(isvalid(obj));
    tfHdl = ~isempty(obj) && all(ishandle(obj));
    
    tf = tfObj || tfHdl;
end



%--------------------------------------------------------------------------%
% isValidObj.m                                                             %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
