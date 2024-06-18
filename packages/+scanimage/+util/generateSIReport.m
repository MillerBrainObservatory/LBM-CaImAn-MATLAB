function generateSIReport(attemptSILaunch,filename)
%generateSIReport: Report generator for ScanImage 2015.
%   Saves the following properties:
%       cpuInfo             Struct with CPU information
%       NI_MAX_Report       Report generated using the NI's reporting API
%       REF                 Commit number, if available
%       mSessionHistory     Current session history as a Matlab string
%       mFullSession        Current session history as a Matlab string, including console output
%       searchPath
%       matlabVer
%       usrMem
%       sysMem
%       openGLInfo
%
%   If attemptSILaunch is enabled and ScanImage is not currently loaded, it attempts to launch ScanImage
%

    if nargin < 1 || isempty(attemptSILaunch)
        attemptSILaunch = false;
    end
    
    if nargin < 2 || isempty(filename)
        [filename,pathname] = uiputfile('.zip','Choose path to save report','SIReport.zip');
        if filename==0;return;end
    
        filename = fullfile(pathname,filename);
    end

    fileList = {};
    fileListCleanUp = {};

    [fpath,fname,fext] = fileparts(filename);
    if isempty(fpath)
        fpath = pwd;
    end
    
    if isempty(fname)
        fname = 'SIReport';
    end


    disp('Generating ScanImage report...');
    wb = waitbar(0,'Generating ScanImage report');
    
    try
        % Check if ScanImage is running
        siAccessible = false;
        if evalin('base','exist(''hSI'')')
            siAccessible = true;
        end

        if attemptSILaunch && ~siAccessible
            siAccessible = true;
            try
                scanimage;
            catch
                siAccessible = false;
            end
        end

        % Re-attempt to load hSI
        if siAccessible && evalin('base','exist(''hSI'')')
            hSILcl = evalin('base','hSI');
        end

        if siAccessible
            try
                % Save currently loaded MDF file
                mdf = most.MachineDataFile.getInstance;
                if mdf.isLoaded && ~isempty(mdf.fileName)
                    fileList{end+1} = mdf.fileName;
                end

                % Save current usr and cfg files
                fullFileUsr = fullfile(tempdir,[fname '.usr']);
                fullFileCfg = fullfile(tempdir,[fname '.cfg']);
                fullFileHeader = fullfile(tempdir,'TiffHeader.txt');
                fullFileErr = fullfile(tempdir,'ErrorLog.txt');

                hSILcl.hConfigurationSaver.usrSaveUsrAs(fullFileUsr,'',1);
                fileList{end+1} = fullFileUsr;
                fileListCleanUp{end+1} = fullFileUsr;

                hSILcl.hConfigurationSaver.cfgSaveConfigAs(fullFileCfg, 1);
                fileList{end+1} = fullFileCfg;
                fileListCleanUp{end+1} = fullFileCfg;
                
                fileID = fopen(fullFileHeader,'W');
                fwrite(fileID,hSILcl.mdlGetHeaderString(),'char');
                
                fclose(fileID);
                fileList{end+1} = fullFileHeader;
                fileListCleanUp{end+1} = fullFileHeader;
                
                errN = numel(hSILcl.errorLog);
                if errN
                    fileID = fopen(fullFileErr,'W');
                    
                    for i = 1:errN
                        e = hSILcl.errorLog{i};
                        fprintf(fileID, 'Logged error that occurred at %s:\n%s\n\n\n',datestr(e{1}),e{2}.getReport('extended'));
                    end

                    fclose(fileID);
                    fileList{end+1} = fullFileErr;
                    fileListCleanUp{end+1} = fullFileErr;
                end
            catch
                disp('Warning: SI could not be accessed properly');
            end
        end
        
        waitbar(0.2,wb);

        % create MAX report
        filenameNIMAX = fullfile(tempdir,[fname '_NIMAX.zip']); % extension has to be .zip, otherwise NISysCfgGenerateMAXReport will throw error
        NIMAXSuccess = true;
        try
            dabs.ni.configuration.generateNIMaxReport(filenameNIMAX);
        catch
            NIMAXSuccess = false;
        end

        if NIMAXSuccess
            fileList{end+1} = filenameNIMAX;
            fileListCleanUp{end+1} = filenameNIMAX;
        end
        
        waitbar(0.6,wb);

        % Open a temporary mat file to store any relevant information
        tmpFilename = fullfile(tempdir,[fname '_tmp.mat']);

        % CPU info
        cpuInfo = most.idioms.cpuinfo;
        save(tmpFilename, 'cpuInfo');
        fileListCleanUp{end+1} = tmpFilename;
        
        % ScanImage version
        siVersion = scanimage.SI.version();
        save(tmpFilename,'siVersion','-append');
        
        % Get current session history
        if ismcc || isdeployed
            mSessionHistory = evalin('base', 'hSICtl.hStatusWindow.getHistory()');
        else
            jSessionHistory = com.mathworks.mlservices.MLCommandHistoryServices.getSessionHistory;
            mSessionHistory = cellstr(char(jSessionHistory));
        end
        save(tmpFilename, 'mSessionHistory','-append');
        
        % Get current current text from the standard output
        if ismcc || isdeployed
            mFullSession = evalin('base', 'hSICtl.hStatusWindow.getBuffer()');
        else
            % NOTE: Clearing the window will prevent this function from showing the errors. It's still a good candidate
            %       to be called within ScanImage when being presented with an error
            drawnow;
            cmdWinDoc = com.mathworks.mde.cmdwin.CmdWinDocument.getInstance;
            jFullSession = cmdWinDoc.getText(cmdWinDoc.getStartPosition.getOffset,cmdWinDoc.getLength);
            mFullSession = char(jFullSession);    
        end
        save(tmpFilename, 'mFullSession','-append');
        % Get current search path
        searchPath = path; 
        save(tmpFilename, 'searchPath','-append');

        % Get Matlab and Java versions
        matlabVer = version();
        javaVer = version('-java'); 
        save(tmpFilename,'matlabVer','javaVer','-append');
        
        % Get Windows version
        [~,winVer] = system('ver');
        save(tmpFilename,'winVer','-append');        

        % Get memory info
        [usrMem sysMem] = memory;
        save(tmpFilename,'usrMem','sysMem','-append');

        % Get OpenGL information
        openGLInfo = opengl('data');
        save(tmpFilename,'openGLInfo','-append');
        
        try
            %save separate files for convenience
            fn = fullfile(tempdir,'mSessionHistory.txt');
            fidt = fopen(fn,'w');
            for i=1:length(mSessionHistory)
                fprintf(fidt, '%s\n', mSessionHistory{i});
            end
            fclose(fidt);
            fileListCleanUp{end+1} = fn;
            fileList{end+1} = fn;

            fn = fullfile(tempdir,'mFullSession.txt');
            fidt = fopen(fn,'w');
            fprintf(fidt,'%s', mFullSession);
            fclose(fidt);
            fileListCleanUp{end+1} = fn;
            fileList{end+1} = fn;
        catch
        end
        
        waitbar(0.8,wb);

        % Add the tmp file to the zip list
        fileList{end+1} = tmpFilename;

        % Zip important information
        zip(filename, fileList);

        % Clean directory
        cellfun(@(f)delete(f),fileListCleanUp);
        
        waitbar(1,wb);

        disp('ScanImage report ready');
    catch ME
        delete(wb);
        most.idioms.reportError(ME);
    end
    
    delete(wb); % delete the waitbar
end

%--------------------------------------------------------------------------%
% generateSIReport.m                                                       %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
