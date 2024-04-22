function dbgmsg(group, varargin)
    persistent activeDbgGroups
    
    if strcmp(group, '#set')
        activeDbgGroups = varargin{1};
    elseif ~isempty(activeDbgGroups) && (ismember(group, activeDbgGroups) || ismember('all', activeDbgGroups))
        if strcmp(varargin{1}, '#val')
            disp(varargin{2});
        else
            fprintf(varargin{:});
        end
    end
end


%--------------------------------------------------------------------------%
% dbgmsg.m                                                                 %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
