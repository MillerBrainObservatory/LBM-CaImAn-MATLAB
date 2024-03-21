function loadnisyscfg()
    if libisloaded('nisyscfg');return;end
    
    if strcmp(computer('arch'),'win32')
        % for some reason this function crashes Matlab on Windows 32 bit
        error('generateNIMaxReport currently unsupported on Windows 32 bit');
    end
    
    binarypath = fullfile(fileparts(mfilename('fullpath')),computer('arch'));
    
    oldpath = pwd();
    cd(binarypath);
    
    s = warning();
    warning off MATLAB:loadlibrary:TypeNotFound
    warning off MATLAB:loadlibrary:TypeNotFoundForStructure
    try
        [notfound,warnings] = loadlibrary('nisyscfg', @nisyscfg_proto);
    catch ME
        warning(s);
        cd(oldpath);
        rethrow(ME);
    end
    warning(s);
    cd(oldpath);
end


%--------------------------------------------------------------------------%
% loadnisyscfg.m                                                           %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
