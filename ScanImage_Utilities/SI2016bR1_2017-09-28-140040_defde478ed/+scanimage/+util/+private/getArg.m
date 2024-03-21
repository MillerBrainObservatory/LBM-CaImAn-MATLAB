function arg = getArg(vararguments, flag, flags, flagIndices)
    [tf,loc] = ismember(flag,flags); %Use this approach, instead of intersect, to allow detection of flag duplication
    if length(find(tf)) > 1
        error(['Flag ''' flag ''' appears more than once, which is not allowed']);
    else %Extract location of specified flag amongst flags
        loc(~loc) = [];
    end
    flagIndex = flagIndices(loc);
    if length(vararguments) <= flagIndex
        arg = [];
        return;
    else
        arg = vararguments{flagIndex+1};
        if ischar(arg) && ismember(lower(arg),flags) %Handle case where argument was omitted, and next argument is a flag
            arg = [];
        end
    end
end

% 
% function arg = getArg(vararguments, flag)
%     % make a temp cell array to search for strings
%     argsch = vararguments;
%     ics = ~cellfun(@ischar,argsch);
%     argsch(ics) = {''};
%     
%     [tf,loc] = ismember(flag,argsch); %Use this approach, instead of intersect, to allow detection of flag duplication


%--------------------------------------------------------------------------%
% getArg.m                                                                 %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
