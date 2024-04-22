function removeFileTypes(d,filesToRemove)
%REMOVEFILETYPES Remove all files of specified extension(s) in a selected folder subtree
%
%   filesToRemove: String or cell string array of file expressions typically using wildcards, e.g. {'*.mold' '*.asv' '_*'}

if ischar(filesToRemove)
    filesToRemove = {filesToRemove};
end

if isempty(filesToRemove)
    return;
end

for i=1:length(filesToRemove)
    currPath = pwd;
    cd(d);
    system(['del ' filesToRemove{i} ' /S /Q'],'-echo');
    cd(currPath);
end
    


%--------------------------------------------------------------------------%
% removeFileTypes.m                                                        %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
