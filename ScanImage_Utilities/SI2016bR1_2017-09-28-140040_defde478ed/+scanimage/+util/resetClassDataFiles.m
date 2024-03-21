function resetClassDataFiles(dataDir)
if nargin < 1
    dataDir = [];
end

if evalin('base','exist(''hSI'',''var'')')
    hSI = evalin('base','hSI');
    assert(isempty(hSI) || ~isvalid(hSI),'Cannot reset class data files while ScanImage is running');
end

fprintf('Deleting class data files in ScanImage path...\n');
p = fileparts(fileparts(fileparts(mfilename('fullpath'))));
most.util.removeFileTypes(p,'*_classData.mat');
fprintf('Done!\n');

if ~isempty(dataDir)
    assert(exist(dataDir,'dir') == 7,'Directory ''%s'' does not exist',dataDir);
    fprintf('Deleting class data files in data dir path...\n');
    most.util.removeFileTypes(dataDir,'*_classData.mat');
    fprintf('Done!\n');
end

fprintf('Resetting class data files completed successfully\n');
end

%--------------------------------------------------------------------------%
% resetClassDataFiles.m                                                    %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
