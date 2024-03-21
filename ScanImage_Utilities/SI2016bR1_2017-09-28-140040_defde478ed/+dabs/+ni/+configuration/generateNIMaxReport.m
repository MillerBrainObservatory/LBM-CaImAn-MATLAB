function filename = generateNIMaxReport(filename)
    if nargin < 1 || isempty(filename)
       [filename,pathname] = uiputfile('.zip','Choose path to save report','NIMaxReport.zip');
       if filename==0;return;end
       filename = fullfile(pathname,filename);
    end

    [fpath,fname,fext] = fileparts(filename);
    if isempty(fpath)
        fpath = pwd;
    end
    filename = fullfile(fpath,[fname '.zip']); % extension has to be .zip, otherwise NISysCfgGenerateMAXReport will throw error

    % initialize NI system configuration session
    [~,~,~,experthandle,sessionhandle] = nisyscfgCall('NISysCfgInitializeSession','localhost','','',1033,false,100,libpointer,libpointer);

    % create MAX report
    nisyscfgCall('NISysCfgGenerateMAXReport',sessionhandle,filename,2,true);

    % close session and expert handle
    nisyscfgCall('NISysCfgCloseHandle',sessionhandle);
    nisyscfgCall('NISysCfgCloseHandle',experthandle);
end


%--------------------------------------------------------------------------%
% generateNIMaxReport.m                                                    %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
