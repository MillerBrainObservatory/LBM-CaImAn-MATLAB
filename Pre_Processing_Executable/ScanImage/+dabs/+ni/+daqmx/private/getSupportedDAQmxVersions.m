function versions = getSupportedDAQmxVersions
switch computer('arch')
    case 'win32'
        archFolder = 'win32';
    case 'win64'
        archFolder = 'x64';
    otherwise
        error('NI DAQmx: Unknown computer architecture :%s',computer(arch));
end
    folders = dir('NIDAQmx_*');
    folders = {folders.name};
    
    versions = {};
    for i = 1:length(folders)
        folder = folders{i};
        supported = 0 < exist(fullfile(pwd,folder,archFolder,'NIDAQmx_proto.m'),'file') ...
                 || 0 < exist(fullfile(pwd,folder,archFolder,'NIDAQmx_proto.p'),'file');
        if strcmp(archFolder,'x64')
            supported = supported && 0 < exist(fullfile(pwd,folder,archFolder,'nicaiu_thunk_pcwin64.dll'),'file');
        end
        
        if supported
           versions{end+1} = strrep(strrep(folder,'NIDAQmx_',''),'_','.'); %#ok<AGROW>
        end
    end
end


%--------------------------------------------------------------------------%
% getSupportedDAQmxVersions.m                                              %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
