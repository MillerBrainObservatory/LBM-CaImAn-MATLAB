function checkFilePermissions()
    siPath = scanimage.util.siRootDir();
    fileName = fullfile(siPath,[most.util.generateUUID '.si']);
    
    if ~makeTestFile(fileName)
        button = questdlg(sprintf('ScanImage does not have write permissions in its installation folder.\nDo you want to fix the file permissions automatically?'));
        switch lower(button)
            case 'yes'
                scanimage.util.setSIFilePermissions();
                if ~makeTestFile(fileName);
                    msgbox('ScanImage could not set the folder permissions automatically.','Warning','warn');
                end
            otherwise
                msgbox('Without write access in the installation folder ScnaImage might not function correctly.','Warning','warn');
                return
        end
    end
end

function success = makeTestFile(fileName)
    success = false;
    try
        hFile = fopen(fileName,'w+');
        if hFile < 0
            return
        end
        fprintf(hFile,'my test string');
        fclose(hFile);
        success = true;
    catch
        success = false;
    end
    
    if exist(fileName,'file');
        delete(fileName);
    end
end

%--------------------------------------------------------------------------%
% checkFilePermissions.m                                                   %
% Copyright © 2016 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2016 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
