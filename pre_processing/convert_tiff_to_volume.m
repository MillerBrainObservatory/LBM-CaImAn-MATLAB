function convert_tiff_to_volume(filePath, saveDirPath, diagnosticFlag)
% Convert a ScanImage.tif file or or series of files into a collated 4D
% volume. 
%
% NOTE: Only raw .tif files from one session should be in the filePath
%
% Inputs:
%   filePath - The directory containing the raw .tif files.
%   fileNameRoot - The root name for each file in the directory.
%   saveDirPath - The directory where processed files will be saved.
%   diagnosticFlag - When set to '1', reports all .tif files in the directory.

addpath(genpath(fullfile('ScanImage_Utilities/')));
if ~exist('diagnosticFlag', 'var')
    diagnosticFlag = '0';
end

filePath = fullfile(filePath);
if ~isfolder(filePath)
    error("Filepath %u does not exist", filePath);
end

if ~exist('saveDirPath', 'var') || isempty(saveDirPath)
    saveDirPath = filePath; % default save directory is the input filePath
else
    if not(isfolder(saveDirPath))
        mkdir(saveDirPath)
    end
end

tic
clck = clock; % Generate a timestamp for the log file name.
logFileName = sprintf('matlab_log_%d_%02d_%02d_%02d_%02d.txt', clck(1), clck(2), clck(3), clck(4), clck(5));
logFullPath = fullfile(filePath, logFileName);
fid = fopen(logFullPath, 'w');

if strcmp(diagnosticFlag, '1')
    dir([filePath, '*.tif']);
else
    try
        % Grab all tiffs in the given path
        files = dir(fullfile(filePath, '*.tif'));
        if isempty(files)
            error('No suitable files found for processing in: \n  %s', filePath);
        elseif length(files)>1
            xx = dir(fullfile(filePath,'*.tif'));
            N = {xx.name};
            X = ~cellfun('isempty', strfind(N, "_000"));
            numFiles = sum(X);
            multiFile = true;
        elseif length(files)==1
            multiFile = false;
            numFiles = 1; 
        end
        fileNames = {files.name};
        filteredFileNames = fileNames(~contains(lower(fileNames), 'plane'));
    
        filesToProcess = {}; % keep track of processed files
        for i = 1:length(filteredFileNames)
            currentFileName = filteredFileNames{i};
            % match _0000N.tif, where N = #files, at the end of the filename
            if multiFile && regexp(currentFileName, '.*_\d{5}\.tif$')
                filesToProcess{end+1} = currentFileName;
                sprintf('Adding %s ...', currentFileName)
            elseif length(filteredFileNames) == 1
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

        %%  (I) Assemble ROI's from ScanImage
        %%% Loop through raw .tif files and reassemble planes/frames.
        for ijk = 1:numFiles
            disp(['Loading file ' num2str(ijk) ' of ' num2str(numFiles) '...'])
            date = datetime(now,'ConvertFrom','datenum');
            formatSpec = '%s Beginning file %u...\n';
            fprintf(fid,formatSpec,date,ijk);
        
            % Use the currentFileName from filesToProcess
            currentFileName = filesToProcess{ijk};
            
            [vol, volumeRate, pixelResolution] = assembleCorrectedROITiff(fullfile(filePath, currentFileName));
            tt = toc/3600;
            disp(['Volume loaded and processed. Elapsed time: ' num2str(tt) ' hours. Saving volume to temp...'])
        
            %% Save volume as .mat/hdf5 and additional information as attributes
            matfilename = fullfile(saveDirPath, [currentFileName(1:end-4) '.mat']);
            numberOfPlanes = 30;
            if numberOfPlanes == 30
                order = [1 5:10 2 11:17 3 18:23 4 24:30];
                order = fliplr(order);
            elseif numberOfPlanes == 15
                order = [1 5 6 2 7:9 3 10:14 4 15];
                order = fliplr(order);
            else
                disp('Number of planes not recognized.')
            end
    
            vol = vol(:,:,order,:);
            fullVolumeSize = size(vol);
            savefast(matfilename,'vol','volumeRate','pixelResolution','fullVolumeSize');

            tt = toc/3600;
            disp(['Volume loaded, processed, and saved to disk. Elapsed time: ' num2str(tt) ' hours. Processing next volume...'])
        
            clear vol
            pause(0.5)
        end
    catch ME
        if ~isempty(ME.cause)
            fprintf('Error in %s at line %d: %s\n', ME.stack(1).name, ME.stack(1).line, ME.cause{1,1}.message);
            sprintf('%s Error in function %s() at line %d. Error Message: %s', date,ME.stack(1).name, ME.stack(1).line, ME.cause{1,1}.message);
        else
            fprintf('Error in %s at line %d: %s\n', ME.stack(1).name, ME.stack(1).line, ME.message);
        end
        
        % delete the logfile before erroring out
        fclose(fid);
        fprintf('Deleting logfile: %s', logFullPath)
        delete(logFullPath);
        clearvars
        return;
    end
end