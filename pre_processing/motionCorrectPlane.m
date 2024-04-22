function motionCorrectPlane(filePath, fileNameRoot, numCores, startPlane, endPlane)
% MOTIONCORRECTPLANE Perform rigid and non-rigid motion correction on imaging data.
%
% This function processes imaging data by loading individual processed planes,
% performing rigid motion correction to use as a template for patched non-rigid
% motion correction. Each motion-corrected plane is saved separately.
%
% Updates:
%   J.D. - 05/19/2020 - Original implementation.
%   F.O. - 03/04/2024 - Added support for 24 cores, included storage capacity checks.
%
% Inputs:
%   filePath      - Directory containing raw .tif files.
%   fileNameRoot  - Root name for files in the directory. This code appends '_00001.tif'
%                   to this root name, so this suffix should be removed from the root.
%   numCores      - Number of cores to use for computation. If more than 24, it defaults to 23.
%   startPlane    - The starting plane index for processing.
%   endPlane      - The ending plane index for processing.
%
% Outputs:
%   Each motion-corrected plane is saved as a .mat file containing:
%   - shifts: 2D motion vectors as single precision.
%   - metadata: Struct containing all relevant metadata for this session.
% 
% Notes:
%   Only .mat files containing processed volumes should be in the filePath.
%   Any .mat files with "plane" in the filename will be skipped to avoid
%           processing a previously motion-correted plane.
arguments
    filePath (1,:) char                    % Path to the directory with input files.
    fileNameRoot (1,:) char                % Base name for input files.
    numCores (1,1) double {mustBeInteger, mustBePositive, mustBeLessThanOrEqual(numCores,24)} = 1
    startPlane (1,1) double {mustBeInteger, mustBePositive} = 1
    endPlane (1,1) double {mustBeInteger, mustBePositive, mustBeGreaterThanOrEqual(endPlane,startPlane)} = 1
end
    addpath(genpath(fullfile("utils/")));
    addpath(genpath(fullfile('motion_correction/')));

    tic;
    clck = clock; % Generate a timestamp for the log file name.
    logFileName = sprintf('matlab_log_%d_%02d_%02d_%02d_%02d.txt', clck(1), clck(2), clck(3), clck(4), clck(5));
    logFullPath = fullfile(filePath, logFileName);
    fid = fopen(logFullPath, 'w');

    poolobj = gcp('nocreate');
    if ~isempty(poolobj)
        disp('Removing existing parallel pool.');
        delete(poolobj);
    end

    disp('Beginning processing routine.');
    numCores = max(numCores, 23);
    fprintf(fid, '%s Beginning processing routine...\n', datetime);
    
    files = dir(fullfile(filePath, '*.mat'));
    if isempty(files)
        error('No suitable tiff files found in: \n  %s', filePath);
    end

    multiFile = length(files) > 1;
    filesToProcess = {}; % keep track of processed files
    for i = 1:length(files)
        currentFileName = files(i).name;
        % match _0000N.tif, where N = #files, at the end of the filename
        if multiFile && ~isempty(regexp(currentFileName, '.*_\d{5}\.mat$', 'once'))
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
 
    % Filter out motion correction output files containing "plane" in the filename 
    fileNames = {files.name};
    relevantFiles = contains(fileNames, fileNameRoot) & ~contains(fileNames, 'plane');
    relevantFileNames = fileNames(relevantFiles);
    sprintf('Number of files to process: %s \n', num2str(length(relevantFileNames)))

    for fname=1:length(relevantFiles)
        disp(fname)
    end
    
    % Check if at least one relevant file is found
    if isempty(relevantFileNames)
        error('No relevant files found in filePath: %d \n', filePath);
    end
    
    numFiles = length(relevantFileNames);

    % Pull metadata file
    metadata_matfile = matfile(fullfile(filePath, relevantFileNames{1}), 'Writable',true);
    metadata = metadata_matfile.metadata;

    pixel_resolution = metadata.pixel_resolution;
    sizY = metadata.volume_size;
    d1Planes = metadata.volume_size(3);
    d1file = metadata.volume_size(1);
    d2file = metadata.volume_size(2);
    Tfile = metadata.volume_size(4);
    totalT = Tfile*length(relevantFileNames);

    if ~(d1Planes >= endPlane)
        error("Not enough planes to process given user supplied argument: %d as endPlane when only %d planes exist in this dataset.", endPlane, d1Planes);
    end

    % To use H5:
    % fileInfo = h5info(fullfile(filePath, relevantFileNames{1}), '/data');
    % d1 = fileInfo.Dataspace.Size(1);
    % d2 = fileInfo.Dataspace.Size(2);
    % num_planes = fileInfo.Dataspace.Size(3);
    % T = fileInfo.Dataspace.Size(4); % Number of time points per file
    
    % preallocate based on the total number of time points across all files
    % For each file, grab all data for this plane.
    for plane_idx = startPlane:endPlane
        sprintf('Loading plane %s', num2str(plane_idx))
        Y = zeros(sizY(1), sizY(2), totalT, 'single');
        for file_idx = 1:numel(relevantFileNames)
            currentFileName = relevantFileNames{file_idx};
            data = matfile(fullfile(filePath, currentFileName), "Writable",true);
            Y(:,:,(file_idx-1)*Tfile+1:file_idx*Tfile) = single(reshape(data.vol(:,:,plane_idx,:),d1file,d2file,Tfile));
        end

        sizY = size(Y);
        d1 = sizY(1);
        d2 = sizY(2);
        T = sizY(3);

        Y = Y-min(Y(:));
        
        fprintf(fid, '%s Beginning processing for plane %s with %s matlab workers.', datetime, plane_idx);

        if size(gcp("nocreate"),1)==0
            parpool(numCores);
        end

        %% Motion correction: Create Template                 
        max_shift = round(20/pixel_resolution);
        options_rigid = NoRMCorreSetParms(...
            'd1',d1,...
            'd2',d2,...
            'bin_width',200,...       % Bin width for motion correction
            'max_shift',round(20/pixel_resolution),...        % Max shift in px
            'us_fac',20,...
            'init_batch',200,...     % Initial batch size
            'correct_bidir',false... % Correct bidirectional scanning
            );

        [M1,shifts1,~,~] = normcorre_batch(Y,options_rigid);
        date = datetime(now,'ConvertFrom','datenum');
        formatSpec = '%s Rigid MC Complete, beginning non-rigid mc...\n';
        fprintf(fid,formatSpec,date);
        
        % create the template using X/Y shift displacements
        shifts_r = squeeze(cat(3,shifts1(:).shifts));
        shifts_v = movvar(shifts_r,24,1);
        [srt,minv_idx] = sort(shifts_v,120); 
        best_idx = unique(reshape(minv_idx,1,[]));
        template_good = mean(M1(:,:,best_idx),3);
        
        % Non-rigid motion correction using the good tamplate from the rigid
        % correction.
          options_nonrigid = NoRMCorreSetParms(...
            'd1',d1file,...
            'd2',d2file,...
            'bin_width',24,...
            'max_shift', max_shift,...
            'us_fac',20,...
            'init_batch',120,...
            'correct_bidir',false...
            );

        % DFT subpixel registration - results used in CNMF
        % [M2,shifts2,~,~] = normcorre_batch(Y,options_nonrigid,template_good);

        % Returns a [2xnum_frames] vector of shifts in x and y 
        [shifts, ~, ~] = rigid_mcorr(Y,'template', template_good, 'max_shift', max_shift, 'subtract_median', false, 'upsampling', 20);
        outputFile = [filePath 'mc_vectors_plane_' num2str(plane_idx) '.mat'];

        savefast(outputFile, 'metadata', 'shifts');

        disp('Data saved, beginning next plane...')
        date = datetime(now,'ConvertFrom','datenum');
        formatSpec = '%s Motion Correction Complete. Beginning next plane...\n';
        fprintf(fid,formatSpec,date);

        clear M1 cM1 cM2 cY cMT template_good shifts* %M2

        % disp('Calculating motion correction metrics...')

        % apply vectors to movie
        % mov_from_vec = translateFrames(Y, t_shifts);
   
        % [cY,~,~] = motion_metrics(Y,10);
        % [cM1,~,~] = motion_metrics(M1,10);
        % % [cM2,~,~] = motion_metrics(M2,10);
        % [cMT,~,~] = motion_metrics(mov_from_vec,10);
    end

    disp('All planes processed...')
    t = toc;
    disp(['Routine complete. Total run time ' num2str(t./3600) ' hours.'])
    date = datetime(now,'ConvertFrom','datenum');
    formatSpec = '%s Routine complete.';
    fprintf(fid,formatSpec,date);
end