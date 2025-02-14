function motionCorrectPlane(data_path, varargin)
% Perform motion correction on imaging data.
%
% Each motion-corrected plane is saved as a .h5 group containing the 2D
% shift vectors in x and y. The raw movie is saved in '/Y' and the
%
% Parameters
% ----------
% data_path : char
%     Path to the directory containing the files assembled via convertScanImageTiffToVolume.
% save_path : char
%     Path to the directory to save the motion vectors.
% ds : char, optional
%     Group path within the hdf5 file that contains raw data.
%     Default is '/Y'.
% debug_flag : double, logical, optional
%     If set to 1, the function displays the files in the command window and does
%     not continue processing. Defaults to 0.
% do_figures : double, integer, positive
%     If true, correlation metrics will be saved to save_path/figures.
% overwrite : logical, optional
%     Whether to overwrite existing files (default is 0).
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
%
% - Only .h5 files containing processed volumes should be in the file_path.

p = inputParser;

% Define the parameters
addRequired(p, 'data_path', @(x) ischar(x) || isstring(x));
addParameter(p, 'save_path', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'ds', "/Y", @(x) (ischar(x) || isstring(x)));
addParameter(p, 'debug_flag', 0, @(x) isnumeric(x) || islogical(x));
addParameter(p, 'do_figures', 1, @(x) isnumeric(x) || islogical(x));
addParameter(p, 'overwrite', 0, @(x) isnumeric(x) || islogical(x));
addParameter(p, 'num_cores', 1, @(x) isnumeric(x));

%% additional parameters for motion correction
addParameter(p, 'start_plane', 1, @(x) isnumeric(x) && x > 0);
addParameter(p, 'end_plane', 1, @(x) isnumeric(x) && x >= p.Results.start_plane);
addParameter(p, 'options', {}, @(x) isstruct(x));

parse(p,data_path,varargin{:});

% Retrieve the parsed input arguments
data_path = convertStringsToChars(p.Results.data_path);
save_path = convertStringsToChars(p.Results.save_path);

ds = p.Results.ds;
debug_flag = p.Results.debug_flag;
overwrite = p.Results.overwrite;
num_cores = p.Results.num_cores;
start_plane = p.Results.start_plane;
end_plane = p.Results.end_plane;
do_figures = p.Results.do_figures;
options = p.Results.options;

if ~isfolder(data_path); error("Data path:\n %s\n ..does not exist", data_path); end

% Make the save path in data_path/assembled, if not given
if isempty(save_path)
    save_path = fullfile(data_path, '../', 'motion_corrected');
    if ~isfolder(save_path); mkdir(save_path);
        warning('Creating save path since one was not provided, located: %s', save_path);
    end
elseif ~isfolder(save_path)
    mkdir(save_path);
end

if debug_flag == 1; dir([data_path '/' '*.h*']); return; end

files = dir(fullfile(data_path, '*assembled_plane_*.h*'));
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

if do_figures
    fig_save_path = fullfile(save_path, "registration_figs/");
    if ~isfolder(fig_save_path); mkdir(fig_save_path); end
end

num_cores = max(num_cores, 23);
tall=tic; log_message(fid, 'Beginning registration with %d cores...\n', num_cores);
for plane_idx = start_plane:end_plane
    tplane=tic;
    
    log_message(fid, 'Beginning plane %d\n', plane_idx);
    
    z_str = sprintf('plane_%d', plane_idx);
    plane_name = sprintf("%s/assembled_%s.h5", data_path, z_str);
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
    
    volume_size = size(Y);
    d1 = volume_size(1);
    d2 = volume_size(2);
    pixel_resolution = metadata.pixel_resolution;
    frame_rate = metadata.frame_rate;
    
    options_rigid = NoRMCorreSetParms(...
        'd1',d1,...
        'd2',d2,...
        'fr', frame_rate, ...
        'bin_width',200,...
        'max_shift', round(20/pixel_resolution),...        % Max shift in px
        'us_fac',20,...                   % upsample factor
        'init_batch',200,...              % #frames used to create template
        'correct_bidir', false...         % DONT Correct bidirectional scanning
        );
    
    % start timer for registration after parpool to avoid inconsistent
    % pool startup times.
    t_rigid=tic;
    
    log_message(fid, "Beginning batch template.\n");
    [M1,shifts1,~,~] = normcorre_batch(Y, options_rigid);
    log_message(fid, "Rigid registration complete. Elapsed time: %.3f minutes\n",toc(t_rigid)/60);
    
    % create the template using X/Y shift displacements
    % with the least variance
    log_message(fid, "Calculating template...\n");
    shifts_r = squeeze(cat(3,shifts1(:).shifts));
    shifts_v = movvar(shifts_r, 24, 1);
    [~, minv_idx] = sort(shifts_v, 120);
    best_idx = unique(reshape(minv_idx, 1, []));
    template_good = mean(M1(:,:,best_idx), 3);
    
    % % Non-rigid motion correction using the good template from the rigid
    if numel(options) < 3
        options = NoRMCorreSetParms(...
            'd1', d1,...
            'd2', d2,...
            'fr', frame_rate, ...
            'bin_width', 20,...
            'grid_size', [128,128], ...
            'max_shift', round(100/pixel_resolution),...
            'us_fac', 5,...
            'init_batch', 200,...
            'iter', 1, ...
            'plot_flag', true, ...
            'correct_bidir', false...
            );
    end
    
    % DFT subpixel registration - results used in CNMF
    t_nonrigid=tic; log_message(fid, "Template creation complete. Beginning non-rigid registration...\n");
    [M2, shifts2, ~, ~] = normcorre_batch(Y, options, template_good);
    log_message(fid, "Non-rigid registration complete. Elapsed time: %.3f minutes.\n",toc(t_nonrigid)/60);
    
    if do_figures
        
        log_message(fid, "Plotting registration metrics...\n");
        
        fig_plane_name = sprintf("%s/plane_%d", fig_save_path, plane_idx);        
        [cY, mY, ~] = motion_metrics(Y, 10);
        [cM1, mM1, ~] = motion_metrics(M1, 10);
        [cM2, mM2, ~] = motion_metrics(M2, 10);
        T = length(cY);
        
        %% Summary Images
        fname = sprintf("%s_summary_images.png", fig_plane_name);
        f1 = figure('Visible', 'off', 'Units', 'normalized', 'OuterPosition', [0 0 1 1], 'Color', 'k');
        
        ax1 = subplot(1, 3, 1); imagesc(mY); axis equal; axis tight; axis off;
        title('Mean raw', 'fontsize', 10, 'fontweight', 'bold', 'Color', 'w');
        
        ax2 = subplot(1, 3, 2); imagesc(mM1); axis equal; axis tight; axis off;
        title('Mean rigid template', 'fontsize', 10, 'fontweight', 'bold', 'Color', 'w');
        
        ax3 = subplot(1, 3, 3); imagesc(mM2); axis equal; axis tight; axis off;
        title('Mean registered', 'fontsize', 10, 'fontweight', 'bold', 'Color', 'w');
        
        linkaxes([ax1, ax2, ax3], 'xy');
        exportgraphics(f1, fname, 'Resolution', 600, 'BackgroundColor', 'black');
        close(f1);
        
        %% Correlation: Template vs. Raw and Registered vs. Template (Scatter Plots)
        fname = sprintf("%s_correlations_scatter.png", fig_plane_name);
        
        f3 = figure('Visible', 'off', 'Units', 'normalized', 'OuterPosition', [0 0 1 1], 'Color', 'k');
        
        % Scatter plot: Template vs Raw Correlation
        ax1 = subplot(1, 2, 1); scatter(cY, cM1, 'MarkerEdgeColor', 'w'); hold on;
        plot([0.9 * min(cY), 1.05 * max(cM1)], [0.9 * min(cY), 1.05 * max(cM1)], '--r', 'LineWidth', 2);
        axis square;
        title('Template vs Raw Correlation', 'fontsize', 10, 'fontweight', 'bold', 'Color', 'w');
        xlabel('Raw data correlation', 'fontsize', 10, 'fontweight', 'bold', 'Color', 'w');
        ylabel('Template data correlation', 'fontsize', 10, 'fontweight', 'bold', 'Color', 'w');
        set(gca, 'Color', 'k', 'XColor', 'w', 'YColor', 'w', 'FontWeight', 'bold', 'FontSize', 10);
        
        % Scatter plot: Registered vs Template Correlation
        ax2 = subplot(1, 2, 2); scatter(cM1, cM2, 'MarkerEdgeColor', 'w'); hold on;
        plot([0.9 * min(cM1), 1.05 * max(cM2)], [0.9 * min(cM1), 1.05 * max(cM2)], '--r', 'LineWidth', 2);
        axis square;
        title('Registered vs Template Correlation', 'fontsize', 10, 'fontweight', 'bold', 'Color', 'w');
        xlabel('Rigid template', 'fontsize', 10, 'fontweight', 'bold', 'Color', 'w'); 
        ylabel('Non-rigid correlation', 'fontsize', 10, 'fontweight', 'bold', 'Color', 'w');
        set(gca, 'Color', 'k', 'XColor', 'w', 'YColor', 'w', 'FontWeight', 'bold', 'FontSize', 10);
        
        % Ensure both subplots have black backgrounds
        set(ax1, 'Color', 'k');
        set(ax2, 'Color', 'k');
        exportgraphics(f3, fname, 'Resolution', 600, 'BackgroundColor', 'black');
        close(f3);

    end
    
    log_message(fid, "Calculating registration shifts...\n");
    
    shifts_nr = cat(ndims(shifts2(1).shifts)+1,shifts2(:).shifts);
    shifts_nr = reshape(shifts_nr,[],ndims(Y)-1,T);
    shifts_x = squeeze(shifts_nr(:,1,:))';
    shifts_y = squeeze(shifts_nr(:,2,:))';
    if do_figures
        log_message(fid, "Plotting registration shifts...\n");
        
        fname = sprintf("%s_pixel_shifts.png", fig_plane_name);
        f = figure('Visible', 'off', 'Units', 'normalized', 'OuterPosition', [0 0 1 1], 'Color', 'k');
        
        % Correlation Coefficients Plot
        ax1 = subplot(3, 1, 1); 
        plot(1:T, cY, 'r', 'LineWidth', .5); hold on;
        plot(1:T, cM1, 'c', 'LineWidth', .5);
        plot(1:T, cM2, 'w', 'LineWidth', .8);
        hold off;
        
        title('Correlation Coefficients', 'Color', 'w', 'FontWeight', 'bold');
        legend('Raw data', 'Template', 'Registered', ...
            'TextColor', 'w', 'EdgeColor', 'w', 'FontSize', 8, 'Color', 'k', 'FontWeight', 'bold');
        
        set(gca, 'Color', 'k', 'XColor', 'w', 'YColor', 'w', 'LineWidth', 1);
        set(gca, 'XTick', []);
        
        % Displacements Along X
        ax2 = subplot(3, 1, 2);
        plot(mean(shifts_x, 2), 'w', 'LineWidth', 0.5);
        title('Mean X Displacements (per-patch)', 'Color', 'w', 'FontWeight', 'bold');
        set(gca, 'Color', 'k', 'XColor', 'w', 'YColor', 'w', 'LineWidth', 1);
        set(gca, 'XTick', []);
        
        % Displacements Along Y
        ax3 = subplot(3, 1, 3);
        plot(mean(shifts_y, 2), 'w', 'LineWidth', 0.5);
        title('Mean Y Displacements (per-patch)', 'Color', 'w', 'FontWeight', 'bold');
        xlabel('Timestep', 'Color', 'w', 'FontWeight', 'bold');
        set(gca, 'Color', 'k', 'XColor', 'w', 'YColor', 'w', 'LineWidth', 1);
        
        % Link axes for synchronized zooming
        linkaxes([ax1, ax2, ax3], 'x');
        
        % Save the figure with a black background
        exportgraphics(f, fname, 'Resolution', 600, 'BackgroundColor', 'black');
        close(f);

    end
    
    write_frames_3d(plane_name_save, M2,'/Y',true,4);
    
    h5create(plane_name_save,"/shifts_x",  size(shifts_x));
    h5create(plane_name_save,"/shifts_y",  size(shifts_y));
    h5create(plane_name_save,"/Ym",        size(mM2));
    
    h5write(plane_name_save, '/shifts_x',  shifts_x);
    h5write(plane_name_save, '/shifts_y',  shifts_y);
    h5write(plane_name_save, '/Ym',        mM2);
    
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
fclose('all');
