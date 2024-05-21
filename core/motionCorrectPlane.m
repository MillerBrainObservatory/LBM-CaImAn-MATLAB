
function motionCorrectPlane(data_path, save_path, varargin)
    % motion_correct_plane Perform rigid and non-rigid motion correction on imaging data.
    %
    % Parameters
    % ----------
    % data_path : char
    %     Path to the directory containing the files extracted via convertScanImageTiffToVolume.
    % save_path : char
    %     Path to the directory to save the motion vectors.
    % overwrite : logical, optional
    %     Whether to overwrite existing files (default is 1).
    % num_cores : double, integer, positive
    %     Number of cores to use for computation. The value is limited to a maximum
    %     of 24 cores.
    % start_plane : double, integer, positive
    %     The starting plane index for processing.
    % end_plane : double, integer, positive
    %     The ending plane index for processing. Must be greater than or equal to
    %     start_plane.
    %
    % Returns
    % -------
    % Each motion-corrected plane is saved as a .mat file containing the following:
    % shifts : array
    %     2D motion vectors as single precision.
    %
    % Notes
    % -----
    % - Only .h5 files containing processed volumes should be in the file_path.
    % - Any .h5 files with "plane" in the filename will be skipped to avoid
    %   re-processing a previously motion-corrected plane.

    p = inputParser;
    addRequired(p, 'file_path', @ischar);
    addRequired(p, 'save_path', @ischar);
    addParameter(p, 'overwrite', 1, @(x) isnumeric(x) || islogical(x));
    addParameter(p, 'num_cores', 1, @(x) isnumeric(x) && x > 0 && x <= 24);
    addParameter(p, 'start_plane', 1, @(x) isnumeric(x) && x > 0);
    addParameter(p, 'end_plane', 1, @(x) isnumeric(x) && x >= p.Results.start_plane);
    parse(p, data_path, save_path, varargin{:});
    
    data_path = p.Results.file_path;
    save_path = p.Results.save_path;
    num_cores = p.Results.num_cores;
    start_plane = p.Results.start_plane;
    end_plane = p.Results.end_plane;
    overwrite = p.Results.overwrite;

    [currpath, ~, ~] = fileparts(fullfile(mfilename('fullpath'))); % path to this script
    addpath(genpath(fullfile(currpath, '../packages/CaImAn_Utilities/motion_correction/')));
    addpath(genpath(fullfile(currpath, "utils")));

    tic;
    clck = clock; % Generate a timestamp for the log file name.
    log_file_name = sprintf('matlab_log_%d_%02d_%02d_%02d_%02d.txt', clck(1), clck(2), clck(3), clck(4), clck(5));
    log_full_path = fullfile(data_path, log_file_name);
    fid = fopen(log_full_path, 'w');
    close_cleanup_obj = onCleanup(@() fclose(fid));

    poolobj = gcp('nocreate');
    if ~isempty(poolobj)
        disp('Removing existing parallel pool.');
        delete(poolobj);
    end

    disp('Beginning processing routine.');
    num_cores = max(num_cores, 23);
    fprintf(fid, '%s Beginning processing routine...\n', datetime);

    files = dir(fullfile(data_path, '*.h5'));
    if isempty(files)
        error('No suitable h5 files found in: \n  %s', data_path);
    end

    h5_file_path = fullfile(files(1).folder, files(1).name);
    h5_data = h5info(h5_file_path);
    session_info = h5_data.Groups;

    metadata = struct();
    for k = 1:length(session_info.Attributes)
        attr_name = session_info.Attributes(k).Name;
        attr_value = h5readatt(h5_file_path, session_info.Name, attr_name);
        metadata.(matlab.lang.makeValidName(attr_name)) = attr_value;
    end

    for plane_idx = start_plane:end_plane
        dataset_path = sprintf('/raw/plane_%d', plane_idx);
        plane_info = h5info(h5_file_path, dataset_path);
        
        pixel_resolution = metadata.pixel_resolution;
        % num_frames_file = metadata.num_frames_file;
        % num_frames_total = metadata.num_frames_total;

        if ~(metadata.num_planes >= end_plane)
            error("Not enough planes to process given user supplied argument: %d as end_plane when only %d planes exist in this dataset.", end_plane, metadata.num_planes);
        end

        fig_save_path = fullfile(save_path, 'metrics');
        if ~isfolder(fig_save_path)
            mkdir(fig_save_path);
        end

        fprintf(fid, 'Loading plane %d\n', plane_idx);
        Y = h5read(h5_file_path, dataset_path);
        volume_size = size(Y);
        d1 = volume_size(1);
        d2 = volume_size(2);
        Y = Y - min(Y(:));

        fprintf(fid, '%s Beginning processing for plane %d with %d matlab workers.\n', datetime, plane_idx, num_cores);
        if isempty(gcp('nocreate'))
            parpool(num_cores);
        end

        %% Motion correction: Create Template
        max_shift = round(20/pixel_resolution);
        options_rigid = NoRMCorreSetParms(...
            'd1',d1,...
            'd2',d2,...
            'bin_width',200,...       % Bin width for motion correction
            'max_shift', max_shift,...        % Max shift in px
            'us_fac',20,...
            'init_batch',200,...     % Initial batch size
            'correct_bidir',false... % Correct bidirectional scanning
        );

        [M1,shifts1,~,~] = normcorre_batch(Y, options_rigid);
        date = datetime(now,'ConvertFrom','datenum');
        format_spec = '%s Rigid MC Complete, beginning non-rigid MC...\n';
        fprintf(fid, format_spec, date);

        % create the template using X/Y shift displacements
        shifts_r = squeeze(cat(3,shifts1(:).shifts));
        shifts_v = movvar(shifts_r, 24, 1);
        [srt, minv_idx] = sort(shifts_v, 120);
        best_idx = unique(reshape(minv_idx, 1, []));
        template_good = mean(M1(:,:,best_idx), 3);

        % Non-rigid motion correction using the good template from the rigid
        options_nonrigid = NoRMCorreSetParms(...
            'd1', d1,...
            'd2', d2,...
            'bin_width', 24,...
            'max_shift', max_shift,...
            'us_fac', 20,...
            'init_batch', 120,...
            'correct_bidir', false...
        );

        % DFT subpixel registration - results used in CNMF
        [M2, shifts2, ~, ~] = normcorre_batch(Y, options_nonrigid, template_good);

        save_name = sprintf('registered_plane_%d.mat', plane_idx);
        metrics_save_name = sprintf('metrics_plane_%d.fig', plane_idx);

        full_save_path = fullfile(save_path, save_name);
        full_metrics_save_path = fullfile(fig_save_path, metrics_save_name);

        fprintf('Saving registration results in directory: \n \n %s \n', full_save_path);

        disp('Data saved, beginning next plane...');
        date = datetime(now,'ConvertFrom','datenum');
        format_spec = '%s Motion Correction Complete. Beginning next plane...\n';
        fprintf(fid, format_spec, date);

        disp('Calculating motion correction metrics...');

        shifts_r = squeeze(cat(3,shifts1(:).shifts));
        [cY, aa, bb] = motion_metrics(Y, 10);
        [cM1, cc, dd] = motion_metrics(M1, 10);
        [cM2, rr, oo] = motion_metrics(M2, 10);
        
        motion_correction_figure = figure;
        T = size(Y, 3);

        ax1 = subplot(311); plot(1:T, cY, 1:T, cM1, 1:T, cM2); legend('raw data', 'rigid', 'non-rigid'); title('correlation coefficients', 'fontsize', 14, 'fontweight', 'bold')
        set(gca, 'Xtick', [])
        ax2 = subplot(312); %plot(shifts_x); hold on; 
        plot(shifts_r(:,1), '--k', 'linewidth', 2); title('displacements along x', 'fontsize', 14, 'fontweight', 'bold')
        set(gca, 'Xtick', [])
        ax3 = subplot(313); 
        plot(shifts_r(:,2), '--k', 'linewidth', 2); title('displacements along y', 'fontsize', 14, 'fontweight', 'bold')
        xlabel('timestep', 'fontsize', 14, 'fontweight', 'bold')
        linkaxes([ax1, ax2, ax3], 'x')

        Ym = mean(Y, 3);
        save(full_save_path, 'Y', 'Ym', 'shifts_r', 'M1', 'shifts1', "-v7.3");

        registration_group = '/registration';

        if ~isfile(h5_filename)
            h5create(h5_filename, [registration_group, '/Ym'], size(Ym), 'Datatype', 'single');
            h5create(h5_filename, [registration_group, '/Y'], size(Y), 'Datatype', 'single');
            h5create(h5_filename, [registration_group, '/shifts_r'], size(shifts_r), 'Datatype', 'single');
            h5create(h5_filename, [registration_group, '/M1'], size(M1), 'Datatype', 'single');
            h5create(h5_filename, [registration_group, '/shifts1'], size(shifts1));
        elseif overwrite == 1
        
            info = h5info(h5_filename, registration_group);
            datasets = {info.Datasets.Name};
            for d = 1:numel(datasets)
                h5delete([registration_group, '/', datasets{d}]);
            end

            h5create(h5_filename, [registration_group, '/Ym'], size(Ym), 'Datatype', 'single');
            h5create(h5_filename, [registration_group, '/Y'], size(Y), 'Datatype', 'single');
            h5create(h5_filename, [registration_group, '/shifts_r'], size(shifts_r), 'Datatype', 'single');
            h5create(h5_filename, [registration_group, '/M1'], size(M1), 'Datatype', 'single');
            h5create(h5_filename, [registration_group, '/shifts1'], size(shifts1));

            % Write the data to the HDF5 file
            h5write(h5_filename, [registration_group, '/Ym'], Ym);
            h5write(h5_filename, [registration_group, '/Y'], Y);
            h5write(h5_filename, [registration_group, '/shifts_r'], shifts_r);
            h5write(h5_filename, [registration_group, '/M1'], M1);
            h5write(h5_filename, [registration_group, '/shifts1'], shifts1);
        end
        
        saveas(motion_correction_figure, full_metrics_save_path);
        close(motion_correction_figure);
        clear M* c* template_good shifts*;

    end

    disp('All planes processed...');
    t = toc;
    disp(['Routine complete. Total run time ' num2str(t./3600) ' hours.']);
    date = datetime(now,'ConvertFrom','datenum');
    format_spec = '%s Routine complete.\n';
    fprintf(fid, format_spec, date);
end

function close_log_file(fid)
    fclose(fid);
end