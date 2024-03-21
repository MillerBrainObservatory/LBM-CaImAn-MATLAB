function strout = cell2str(cellin)
    strout = {};
    for cellidx = 1:length(cellin)
        cellcontent = cellin{cellidx};
        if iscell(cellcontent)
            str = cell2str(cellcontent);
        elseif ischar(cellcontent)
            str = ['''' cellcontent ''''];
        elseif isnumeric(cellcontent)
            str = mat2str(cellcontent);
        else
            str = sprintf('''Unknown class %s''',class(cellcontent));
            most.idioms.warn('Cannot convert class %s to string',class(cellcontent));
        end
        strout{end+1} = str; %#ok<AGROW>
    end
    strout = [ '{' strjoin(strout,',') '}' ];
end


%--------------------------------------------------------------------------%
% cell2str.m                                                               %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
