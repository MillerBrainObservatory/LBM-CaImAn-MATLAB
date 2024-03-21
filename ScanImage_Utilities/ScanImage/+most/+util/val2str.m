function str = val2str(val)
    if iscell(val)
        str = most.util.cell2str(val);
    elseif ischar(val)
        str = ['''' val ''''];
    elseif isnumeric(val)
        str = mat2str(val);
    else
        str = sprintf('''Unknown class %s''',class(val));
        most.idioms.warn('Cannot convert class %s to string',class(val));
    end
end


%--------------------------------------------------------------------------%
% val2str.m                                                                %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
