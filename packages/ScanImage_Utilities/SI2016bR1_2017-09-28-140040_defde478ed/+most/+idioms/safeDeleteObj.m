function safeDeleteObj(objs)
    %SAFEDELETEOBJ Checks if the object handle is valid and deletes it if so.
    % Returns true if object was valid.
    if isempty(objs)
        return
    end
    
    if iscell(objs)
        cellfun(@(obj)safeDelete(obj),objs);
    elseif numel(objs) > 1
        arrayfun(@(obj)safeDelete(obj),objs);
    else
        safeDelete(objs);
    end
end

function safeDelete(obj)
try
    if most.idioms.isValidObj(obj)
        if isa(obj,'timer')
            stop(obj);
        end
        delete(obj);
    end
catch ME
    % No reason to report any error if object isn't extant/valid    
    % most.idioms.reportError(ME);
end
end


%--------------------------------------------------------------------------%
% safeDeleteObj.m                                                          %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
