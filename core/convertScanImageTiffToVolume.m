function convertScanImageTiffToVolume(data_path, save_path, fix_scan_phase, overwrite, debug_flag)
% CONVERTSCANIMAGETIFFTOVOLUME Convert ScanImage .tif files into a 4D volume.
%
% Convert raw `ScanImage`_ multi-roi .tif files from a single session
% into a single 4D volume (x, y, z, t). It's designed to process files for the
% ScanImage Version: 2016 software.
%
% If no save_path is provided, the same directory that is given for data_path is used.
% If a save_path is given but doesn't exist, it will be created and used to save extracted data.
%
% Parameters
% ----------
% data_path : char
%     The directory containing the raw .tif files. Only raw .tif files from one
%     session should be in the directory.
% save_path : char, optional
%     The directory where processed files will be saved. It is created if it does
%     not exist. Defaults to the data_path if not provided.
%     not continue processing. Defaults to 0.
% fix_scan_phase : double, logical, optional
%     Whether to correct for bi-directional scanning. Default is 1, True
% overwrite : double, logical, optional
%     If True, data saved in the save_path will be overwritten, otherwise the file will be skipped. Default is 0, False.
% debug_flag : double, logical, optional
%     If set to 1, the function displays the files in the command window and does
%
% Notes
% -----
% The function adds necessary paths for ScanImage utilities and processes each .tif
% file found in the specified directory. It checks if the directory exists, handles
% multiple or single file scenarios, and can optionally report the directory's contents
% based on the debug_flag. Each file processed is logged, assembled into a 4D volumetric time-series, and saved in a specified
% directory as a .h5 file with accompanying metadata saved in the attributes. The function also manages errors
% by cleaning up and providing detailed error messages if something goes wrong during processing.
%
% Examples
% --------
% convertScanImageTiffToVolume('C:/data/session1/', 'C:/processed/', 1, 0, 1, 1); % Function will run
% convertScanImageTiffToVolume('C:/data/session1/', 'C:/processed/', 1, 0, 1, 0 ); % Only files will display
%
% See also FILEPARTS, ADDPATH, GENPATH, ISFOLDER, DIR, FULLFILE, ERROR, REGEXP, SAVEFAST
arguments
    data_path (1,:) char  % The directory containing the raw .tif files
    save_path (1,:) char  = data_path   % The directory where processed files will be saved, created if id doesn't exist. Defaults to the data_path.
    fix_scan_phase (1,1) double {mustBeNumericOrLogical} = 1 % Correct bi-directional scanning (can also be done in a separately)
    overwrite (1,1) double {mustBeNumericOrLogical} = 0 % If 1, overwrite existing data.
    debug_flag (1,1) double {mustBeNumericOrLogical} = 0 % If 1, display the files in the command window and stop the process.
end

dbstop in convertScanImageTiffToVolume at 54
dbstop if error;

[currpath, ~, ~] = fileparts(fullfile(mfilename('fullpath'))); % path to this script
addpath(genpath(fullfile(currpath, '../packages/ScanImage_Utilities/ScanImage/')));
if ~exist('debug_flag', 'var')
    debug_flag = 0;
end

data_path = fullfile(data_path);
if ~isfolder(data_path)
    error("Filepath %s does not exist", data_path);
end

if not(isfolder(save_path))
    fprintf('Given savepath %s does not exist. Creating this directory...\n', save_path);
    mkdir(save_path)
end

if debug_flag==1
    dir([data_path, '*.tif']);
else
    try

        % Grab all tiffs in the given path
        files = dir(fullfile(data_path, '*.tif'));
        if isempty(files)
            error('No suitable tiff files found in: \n  %s', data_path);
        end

        % Check if there are multiple files and set flag
        multiFile = length(files) > 1;

        filesToProcess = {}; % keep track of processed files
        for i = 1:length(files)
            currentFileName = files(i).name;
            % match _0000N.tif, where N = #files, at the end of the filename
            if multiFile && regexp(currentFileName, '.*_\d{5}\.tif$')
                filesToProcess{end+1} = currentFileName;
                fprintf('Adding %s ...', currentFileName);
            elseif ~multiFile
                sprintf('Only file to process: %s ', currentFileName)
                filesToProcess{end+1} = currentFileName;
                break;
            else
                sprintf('Ignoring file %s ', currentFileName)
            end
        end

        if isempty(filesToProcess)
            error('No suitable files found for processing in: \n  %s', data_path);
        end

        tic
        clck = clock; % Generate a timestamp for the log file name.

        logFileName = sprintf('matlab_log_%d_%02d_%02d_%02d_%02d.txt', clck(1), clck(2), clck(3), clck(4), clck(5));
        logFullPath = fullfile(data_path, logFileName);
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
            grouppath = sprintf("/file_%s", num2str(ijk));
            currentFileName = filesToProcess{ijk};
            current_fullfile = fullfile(data_path, currentFileName);

            if ijk == 1
                % metadata that will be the same for each file
                metadata = get_metadata(current_fullfile);
            end
            [metadata] = assembleCorrectedROITiff(current_fullfile, metadata, 'group_path', grouppath, 'fix_scan_phase', nvargs.fix_scan_phase);

            tt = toc/3600;
            disp(['Volume loaded and processed. Elapsed time: ' num2str(tt) ' hours. Saving volume to temp...'])
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
