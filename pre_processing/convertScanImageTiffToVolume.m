function convertScanImageTiffToVolume(filePath, saveDirPath, diagnosticFlag)
%CONVERTSCANIMAGETIFFTOVOLUME Convert a MAxiMuM_Ez ScanImage .tif file into a 4D
%volume.
%   This function converts raw scanimage multi-roi .tif files from a single session into a single 4D volume.
%   Only raw .tif files from one session should be in the filePath directory.
% Current ScanImage Version: 2016
arguments
    filePath (1,:) char  % The directory containing the raw .tif files
    saveDirPath (1,:) char  = filePath   % The directory where processed files will be saved, created if id doesn't exist. Defaults to the filePath.
    diagnosticFlag (1,1) double {mustBeNumericOrLogical} = 0 % If 1, display the files in the command window and stop the process.
end

% ScanImage path
addpath(genpath(fullfile(mfilename('fullpath'), "/packages/")));

if ~exist('diagnosticFlag', 'var')
    diagnosticFlag = 0;
end

filePath = fullfile(filePath);
if ~isfolder(filePath)
    error("Filepath %u does not exist", filePath);
end

if not(isfolder(saveDirPath))
    mkdir(saveDirPath)
end

if diagnosticFlag==1
    dir([filePath, '*.tif']);
else
    try
        % Grab all tiffs in the given path
        files = dir(fullfile(filePath, '*.tif'));
        if isempty(files)
            error('No suitable tiff files found in: \n  %s', filePath);
        end
    
        % Check if there are multiple files and set flag
        multiFile = length(files) > 1;
        
        % fileNames = files.name;
        % filteredFileNames = fileNames(~contains(lower(fileNames), 'plane'));    
        filesToProcess = {}; % keep track of processed files
        for i = 1:length(files)
            currentFileName = files(i).name;
            % match _0000N.tif, where N = #files, at the end of the filename
            if multiFile && regexp(currentFileName, '.*_\d{5}\.tif$')
                filesToProcess{end+1} = currentFileName;
                sprintf('Adding %s ...', currentFileName)
            elseif ~multiFile
                sprintf('Only file to process: %s ', currentFileName)
                filesToProcess{end+1} = currentFileName;
                break;
            else
                sprintf('Ignoring file %s ', currentFileName)
            end
        end
  
        if isempty(filesToProcess)
            error('No suitable files found for processing in: \n  %s', filePath);
        end
        
        tic
        clck = clock; % Generate a timestamp for the log file name.

        logFileName = sprintf('matlab_log_%d_%02d_%02d_%02d_%02d.txt', clck(1), clck(2), clck(3), clck(4), clck(5));
        logFullPath = fullfile(filePath, logFileName);
        fid = fopen(logFullPath, 'w');

        %%  (I) Assemble ROI's from ScanImage
        %%% Loop through raw .tif files and reassemble planes/frames.
        numFiles = length(filesToProcess);
        for ijk = 1:numFiles
            disp(['Loading file ' num2str(ijk) ' of ' num2str(numFiles) '...'])
            date = datetime(now,'ConvertFrom','datenum');
            formatSpec = '%s Beginning file %u...\n';
            fprintf(fid,formatSpec,date,ijk);
        
            % Use the currentFileName from filesToProcess
            currentFileName = filesToProcess{ijk};
            [vol, metadata] = assembleCorrectedROITiff(fullfile(filePath, currentFileName));

            tt = toc/3600;
            disp(['Volume loaded and processed. Elapsed time: ' num2str(tt) ' hours. Saving volume to temp...'])
        
            %% Save volume as .mat/hdf5 with accompanying metadata
            matfilename = fullfile(saveDirPath, [currentFileName(1:end-4) '.mat']);
   
            order = [1 5:10 2 11:17 3 18:23 4 24:30];
            order = fliplr(order);
   
            vol = vol(:,:,order,:);
            metadata.volume_size = size(vol);
            metadata.filename = matfilename;
            savefast(matfilename,'vol','metadata');

            tt = toc/3600;
            disp(['Volume loaded, processed, and saved to disk. Elapsed time: ' num2str(tt) ' hours. Processing next volume...'])
        
            clear vol
            pause(0.5)
        end
    catch ME
        % delete the logfile before erroring out
        if exist('fid','var')
            fclose(fid);
        end
        if exist('logFullPath','var')
            if isfile(logFullPath)
                delete(logFullPath);
            end
        end
        rethrow(ME)        
    end


end