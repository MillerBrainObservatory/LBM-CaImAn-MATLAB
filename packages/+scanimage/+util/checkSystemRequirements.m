function checkSystemRequirements()
    %64bit Matlab and Windows is required
    assert(strcmp(computer('arch'),'win64'),'Error: ScanImage only supports Matlab 64bit on Windows. This computer architecture is %s.',computer('arch'));
    
    %minimum required SI version is Matlab 2015a
    assert(~verLessThan('matlab','8.5.0'),'Error: ScanImage only supports Matlab 2015a or later. This Matlab version is %s.',regexprep(getfield(ver('matlab'),'Release'),'[\(\)]',''));
    
    %check for multiple scanimage versions on path
    list = what('scanimage');
    mask = cellfun(@(m)any(strcmpi(m,'SI.m')),{list.m});
    numSI = sum(mask);
    
    if numSI > 1
        msgbox('Multiple ScanImage installations were found on the path.','Error','error');
        folders = strjoin({list(mask).path},'\n\t');
        error('Multiple ScanImage installations were found on the path:\n\t%s\nRemove the redundant instances from the path and restart Matlab.',folders);
    end
end



%--------------------------------------------------------------------------%
% checkSystemRequirements.m                                                %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
