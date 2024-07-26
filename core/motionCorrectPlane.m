function motionCorrectPlane(data_path, save_path, ds, debug_flag, varargin)
% MOTIONCORRECTPLANE Perform piecewise-rigid motion correction on imaging data.
%
% Parameters
% ----------
% data_path : char
%     Path to the directory containing the files extracted via convertScanImageTiffToVolume.
% save_path : char
%     Path to the directory to save the motion vectors.
% ds : char, optional
%     Group path within the hdf5 file that contains raw data.
%     Default is '/Y'.
% debug_flag : double, logical, optional
%     If set to 1, the function displays the files in the command window and does
%     not continue processing. Defaults to 0.
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
% options : struct
%     NormCorre Params Object,
%
% Notes
% -----
% Each motion-corrected plane is saved as a .h5 group containing the 2D
%   shift vectors in x and y. The raw movie is saved in '/Y' and the
%
% - Only .h5 files containing processed volumes should be in the file_path.

p = inputParser;
addRequired(p, 'data_path', @(x) ischar(x) || isstring(x));
addOptional(p, 'save_path', @(x) ischar(x) || isstring(x));
addOptional(p, 'ds', '/Y', @(x) (ischar(x) || isstring(x)));
addOptional(p, 'debug_flag', 0, @(x) isnumeric(x) || islogical(x));
addParameter(p, 'overwrite', 1, @(x) isnumeric(x) || islogical(x));
addParameter(p, 'num_cores', 1, @(x) isnumeric(x));
addParameter(p, 'start_plane', 1, @(x) isnumeric(x) && x > 0);
addParameter(p, 'end_plane', 1, @(x) isnumeric(x) && x >= p.Results.start_plane);
addParameter(p, 'do_figures', 1, @(x) isnumeric(x) && isPositiveIntegerValuedNumeric(x));
addParameter(p, 'options_rigid', {}, @(x) isstruct(x));
addParameter(p, 'options_nonrigid', {}, @(x) isstruct(x));
parse(p,data_path,save_path,ds,debug_flag,varargin{:});

data_path = p.Results.data_path;
save_path = p.Results.save_path;
ds = p.Results.ds;
debug_flag = p.Results.debug_flag;
overwrite = p.Results.overwrite;
num_cores = p.Results.num_cores;
start_plane = p.Results.start_plane;
end_plane = p.Results.end_plane;
do_figures = p.Results.do_figures;
options_rigid = p.Results.options_rigid;
options_nonrigid = p.Results.options_nonrigid;

if ~isfolder(data_path); error("Data path:\n %s\n ..does not exist", data_path); end
if debug_flag == 1; dir([data_path, '*.tif']); return; end

if isempty(save_path)
    warning("No save_path given. Saving data in data_path: %s\n", data_path);
    save_path = data_path;
end

fig_save_path = fullfile(save_path, "figures");
if ~isfolder(fig_save_path); mkdir(fig_save_path); end

files = dir(fullfile(data_path, '*.h*'));
if isempty(files)
    error('No suitable data files found in: \n  %s', data_path);
end

log_file_name = sprintf("%s_correction.log", datestr(datetime('now'), 'yyyy_mm_dd_HH_MM_SS'));
log_full_path = fullfile(save_path, log_file_name);
fid = fopen(log_full_path, 'w');
if fid == -1
    error('Cannot create or open log file: %s', log_full_path);
else
    fprintf('Log file created: %s\n', log_full_path);
end

num_cores = max(num_cores, 23);
tall=tic; log_message(fid, 'Beginning registration with %d cores...\n', num_cores);
for plane_idx = start_plane:end_plane
    tplane=tic;

    log_message(fid, 'Beginning plane %d\n', plane_idx);

    z_str = sprintf('plane_%d', plane_idx);
    plane_name = sprintf("%s/extracted_%s.h5", data_path, z_str);
    plane_name_save = sprintf("%s/motion_corrected_%s.h5", save_path, z_str);

    if plane_idx == start_plane
        metadata = read_h5_metadata(plane_name);
        log_struct(fid, metadata,'metadata',log_full_path);
    end

    if isfile(plane_name_save)
        log_message(fid, '%s already exists.\n',plane_name_save);
        if overwrite
            log_message(fid, 'Parameter Overwrite=true. Deleting file: %s\n',plane_name_save);
            delete(plane_name_save)
        end
    end

    poolobj = gcp("nocreate"); % If no pool, do not create new one.
    if isempty(poolobj)
        log_message(fid, "Initializing parallel cluster with %d workers.\n", num_cores);
        clust=parcluster('local');
        clust.NumWorkers=num_cores;
        parpool(clust,num_cores, 'IdleTimeout', 30);
    end

    Y = read_plane(plane_name,'ds',ds,'plane',plane_idx);
    if ~isa(Y,'single');Y = single(Y);end  % we want float32

    volume_size = size(Y);
    d1 = volume_size(1);
    d2 = volume_size(2);
    pixel_resolution = metadata.pixel_resolution;

    if numel(options_rigid) < 3
        options_rigid = NoRMCorreSetParms(...
            'd1',d1,...
            'd2',d2,...
            'bin_width',200,...
            'max_shift', round(20/pixel_resolution),...        % Max shift in px
            'us_fac',20,...                   % upsample factor
            'init_batch',200,...              % #frames used to create template
            'correct_bidir', false...         % DONT Correct bidirectional scanning
            );
    end

    % start timer for registration after parpool to avoid inconsistent
    % pool startup times.
    t_rigid=tic;

    log_message(fid, "Beginning batch template.\n");
    [M1,shifts1,~,~] = normcorre_batch(Y, options_rigid);
    log_message(fid, "Rigid registration complete. Elapsed time: %.3f minutes\n",toc(t_rigid)/60);

    % create the template using X/Y shift displacements
    log_message(fid, "Calculating template...\n");
    shifts1 = squeeze(cat(3,shifts1(:).shifts));
    shifts_v = movvar(shifts1, 24, 1);
    [~, minv_idx] = sort(shifts_v, 120);
    best_idx = unique(reshape(minv_idx, 1, []));
    template_good = mean(M1(:,:,best_idx), 3);

    % % Non-rigid motion correction using the good template from the rigid
    if numel(options_nonrigid) < 3
        options_nonrigid = NoRMCorreSetParms(...
            'd1', d1,...
            'd2', d2,...
            'bin_width', 10,...
            'max_shift', round(20/pixel_resolution),...
            'us_fac', 20,...
            'init_batch', 200,...
            'iter', 1, ...
            'plot_flag', true, ...
            'correct_bidir', false...
            );
    end

    % DFT subpixel registration - results used in CNMF
    t_nonrigid=tic; log_message(fid, "Template creation complete. Beginning non-rigid registration...\n");
    [M2, shifts2, ~, ~] = normcorre_batch(Y, options_nonrigid, template_good);
    log_message(fid, "Non-rigid registration complete. Elapsed time: %.3f minutes.\n",toc(t_nonrigid)/60);

    log_message(fid, "Calculating registration metrics...\n");

    [cY,mY,~] = motion_metrics(Y,10);
    [cM1,mM1,~] = motion_metrics(M1,10);
    [cM2,mM2,~] = motion_metrics(M2,10);
    T = length(cY);
    if do_figures

        log_message(fid, "Plotting registration metrics...\n");

        fig_plane_name = sprintf("%s/plane_%d", fig_save_path, plane_idx);
        metrics_name_png = sprintf("%s_metrics.png", fig_plane_name);

        f = figure('Visible', 'off', 'Units', 'normalized', 'OuterPosition', [0 0 1 1]);

        ax1 = subplot(2, 2, 1); imagesc(mY); axis equal; axis tight; axis off;
        title('mean raw data', 'fontsize', 10, 'fontweight', 'bold');

        % ax2 = subplot(2, 3, 2); imagesc(mM1); axis equal; axis tight; axis off;
        % title('mean rigid corrected', 'fontsize', 10, 'fontweight', 'bold');

        ax2 = subplot(2, 2, 2); imagesc(mM2); axis equal; axis tight; axis off;
        title('mean corrected', 'fontsize', 10, 'fontweight', 'bold');
        subplot(2, 2, 3); plot(1:T, cY, 1:T, cM2); legend('raw data', 'corrected');
        title('correlation coefficients', 'fontsize', 10, 'fontweight', 'bold');
        subplot(2, 2, 4); scatter(cY, cM2); hold on;
        plot([0.9 * min(cY), 1.05 * max(cM2)], [0.9 * min(cY), 1.05 * max(cM2)], '--r'); axis square;
        xlabel('raw data', 'fontsize', 10, 'fontweight', 'bold'); ylabel('corrected', 'fontsize', 10, 'fontweight', 'bold');
        linkaxes([ax1, ax2], 'xy');
        exportgraphics(f,metrics_name_png,'Resolution',600,'BackgroundColor','k');
        close(f);
    end

    log_message(fid, "Calculating registration shifts...\n");

    shifts2 = cat(ndims(shifts2(1).shifts)+1,shifts2(:).shifts);
    shifts2 = reshape(shifts2,[],ndims(Y)-1,T);
    shifts_x = squeeze(shifts2(:,1,:))';
    shifts_y = squeeze(shifts2(:,2,:))';
    if do_figures
        log_message(fid, "Plotting registration shifts...\n");

        shifts_name_png = sprintf("%s_shifts.png", fig_plane_name);
        f = figure("Visible","off"); % changed to "on" for debugging

        ax1 = subplot(311);
        plot(1:T, cY, 'LineWidth', 2); hold on;
        plot(1:T, cM1, 'LineWidth', 2,  'LineStyle', '--');
        plot(1:T, cM2, 'LineWidth', 2, 'LineStyle', '--');
        legend('raw data', 'rigid', 'non-rigid');
        title('correlation coefficients', 'fontsize', 8, 'fontweight', 'bold');
        set(gca, 'Xtick', []);

        ax2 = subplot(312);
        plot(shifts_x, 'LineWidth', 2, 'Marker', 'none');
        hold on;
        plot(shifts2(:,1), '--r', 'LineWidth', .5);
        title('displacements along x', 'fontsize', 8, 'fontweight', 'bold');
        set(gca, 'Xtick', []);
        xlim([81 1678]);
        ylim([-1.88 3.84]);

        ax3 = subplot(313);
        plot(shifts_y, 'LineWidth', 2, 'Marker', 'none');
        hold on;
        plot(squeeze(shifts2(:,2)), '--r', 'LineWidth', .5);
        title('displacements along y','fontsize',8,'fontweight','bold');
        xlabel('timestep','fontsize',8,'fontweight','bold');

        set(f, 'Position', [1.0000 64.0000 1270.0000 883.0000]);
        set(ax1, 'Position', [0.1300 0.6739 0.7750 0.2157]);
        set(ax2, 'Position', [0.1300 0.4096 0.7750 0.2157]);
        set(ax3, 'Position', [0.1300 0.1453 0.7750 0.2157]);
        set(ax1, 'Box', 'off');
        set(ax2, 'Box', 'off');

        % Link axes
        linkaxes([ax1, ax2, ax3], 'x');
        exportgraphics(f,shifts_name_png, 'Resolution', 600, 'BackgroundColor', 'k');
        close(f);
    end

    write_frames_3d(plane_name_save,M2,'/Y',true,4);

    h5create(plane_name_save,"/shifts",size(shifts2));
    h5create(plane_name_save,"/Ym",size(mM2));
    h5write(plane_name_save, '/shifts', shifts2);
    h5write(plane_name_save, '/Ym', mM2);

    write_metadata_h5(metadata, plane_name_save, '/');
    log_message(fid, "Plane %d finished, data saved. Elapsed time: %.2f minutes\n",plane_idx,toc(tplane)/60);
    if getenv("OS") == "Windows_NT"
        mem = memory;
        max_avail = mem.MemAvailableAllArrays / 1e9;
        mem_used = mem.MemUsedMATLAB / 1e9;
        log_message(fid, "MEMORY USAGE (max/available/used): %.2f/%.2f\n", max_avail, mem_used)
    end
    clear M* shifts* template Ym; close all hidden;
end
log_message(fid, "Processing complete. Time: %.2f hours\n",toc(tall)/3600);
close('all');
