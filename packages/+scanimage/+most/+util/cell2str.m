function strout = cell2str(cellin)
    strout = cellfun(@(v){most.util.val2str(v)},cellin);
    strout = [ '{' strjoin(strout,',') '}' ];
end


%--------------------------------------------------------------------------%
% cell2str.m                                                               %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
