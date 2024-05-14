function motionCorrectPlane(filePath, savePath, numCores, startPlane, endPlane)
% MOTIONCORRECTPLANE Perform rigid and non-rigid motion correction on imaging data.
%
% This function processes imaging data by sequentially loading individual
% processed planes, applying rigid motion correction to generate a template,
% followed by patched non-rigid motion correction. Each motion-corrected plane
% is saved separately with relevant shifts and metadata.
%
% Parameters
% ----------
% filePath : char
%     Path to the directory containing the files extracted via convertScanImageTiffToVolume.
% savePath : char
%     Path to the directory to save the motion vectors.
% numCores : double, integer, positive
%     Number of cores to use for computation. The value is limited to a maximum
%     of 24 cores.
% startPlane : double, integer, positive
%     The starting plane index for processing.
% endPlane : double, integer, positive
%     The ending plane index for processing. Must be greater than or equal to
%     startPlane.
%
% Returns
% -------
% Each motion-corrected plane is saved as a .mat file containing the following:
% shifts : array
%     2D motion vectors as single precision.
%
% Notes
% -----
% - Only .h5 files containing processed volumes should be in the filePath.
% - Any .h5 files with "plane" in the filename will be skipped to avoid
%   re-processing a previously motion-corrected plane.
%
% See also ADDPATH, GCP, DIR, ERROR, FULLFILE, FOPEN, REGEXP, CONTAINS, MATFILE, SAVEFAST
arguments
    filePath (1,:) char                    % Path to the directory with input files.
    numCores (1,1) double {mustBeInteger, mustBePositive, mustBeLessThanOrEqual(numCores,24)} = 1
    startPlane (1,1) double {mustBeInteger, mustBePositive} = 1
    endPlane (1,1) double {mustBeInteger, mustBePositive, mustBeGreaterThanOrEqual(endPlane,startPlane)} = 1
end
    [currpath, ~, ~] = fileparts(fullfile(mfilename('fullpath'))); % path to this script
    addpath(genpath(fullfile(currpath, '../packages/CaImAn_Utilities/motion_correction/')));
    addpath(genpath(fullfile(currpath, "utils")));

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

    files = dir(fullfile(filePath, '*.h5'));
    if isempty(files)
        error('No suitable h5 files found in: \n  %s', filePath);
    end

    h5files = dir([filePath '*.h5']);
    metainfo = h5files(1);
    h5path = fullfile(metainfo.folder, metainfo.name);

    figpath = fullfile(filePath, 'figures/');
    mkdir(figpath);

    h5data = readH5Metadata(h5path);
    groups = h5data.Groups;
    num_files = length(groups);    
    for file_idx=1:num_files        
        file_info = groups(file_idx);
        planes = file_info.Datasets;
        for j=1:length(planes)
            loc_plane = sprintf("/plane_%d", j);
            full_path = sprintf("%s%s", file_info.Name, loc_plane);
            datasetInfo = h5info(h5path, full_path);
            metadata = struct();
            for k = 1:length(datasetInfo.Attributes)
                attrName = datasetInfo.Attributes(k).Name;
                attrValue = h5readatt(h5path, full_path, attrName);
                metadata.(matlab.lang.makeValidName(attrName)) = attrValue;
            end
        end
    end

    pixel_resolution = metadata.pixel_resolution;
    num_planes = metadata.num_planes;
    num_frames_file = metadata.num_frames_file;
    num_frames_total = metadata.num_frames_total;

    if ~(num_planes >= endPlane)
        error("Not enough planes to process given user supplied argument: %d as endPlane when only %d planes exist in this dataset.", endPlane, num_planes);
    end

    % preallocate based on the total number of time points across all files
    % For each file, grab all data for this plane.
    for plane_idx = startPlane:endPlane

        fprintf('Loading plane %s\n', num2str(plane_idx));
        Y = zeros([metadata.image_size(1) metadata.image_size(2) num_frames_total], 'single');

        for file_idx = 1:num_files
            file_group = sprintf("/file_%d/plane_%d", file_idx, plane_idx);
            save_name = sprintf("file_%d_plane_%d", file_idx, plane_idx);

            Y(:,:,(file_idx-1)*num_frames_file+1:file_idx*num_frames_file) = im2single(h5read(h5path, file_group));
        end

        volume_size = size(Y);
        d1 = volume_size(1);
        d2 = volume_size(2);
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
            'd1',d1,...
            'd2',d2,...
            'bin_width',24,...
            'max_shift', max_shift,...
            'us_fac',20,...
            'init_batch',120,...
            'correct_bidir',false...
            );

        % DFT subpixel registration - results used in CNMF
        [M2,shifts2,~,~] = normcorre_batch(Y,options_nonrigid,template_good);

        % % Returns a [2xnum_frames] vector of shifts in x and y
        % [shifts, ~, ~] = rigid_mcorr(Y,'template', template_good, 'max_shift', max_shift, 'subtract_median', false, 'upsampling', 20);
        % outputFile = [filePath 'mc_vectors_plane_' num2str(plane_idx) '.mat'];

        savefast(savePath, 'metadata', 'shifts', 'M2', 'shifts2');

        disp('Data saved, beginning next plane...')
        date = datetime(now,'ConvertFrom','datenum');
        formatSpec = '%s Motion Correction Complete. Beginning next plane...\n';
        fprintf(fid,formatSpec,date);

        clear M1 cM1 cM2 cY cMT template_good shifts* M2

        % disp('Calculating motion correction metrics...')

        % apply vectors to movie
        % mov_from_vec = translateFrames(Y, t_shifts);

        [cY,~,~] = motion_metrics(Y,10);
        [cM1,~,~] = motion_metrics(M1,10);
        % [cM2,~,~] = motion_metrics(M2,10);
        % [cMT,~,~] = motion_metrics(mov_from_vec,10);
    end

    disp('All planes processed...')
    t = toc;
    disp(['Routine complete. Total run time ' num2str(t./3600) ' hours.'])
    date = datetime(now,'ConvertFrom','datenum');
    formatSpec = '%s Routine complete.';
    fprintf(fid,formatSpec,date);
end
