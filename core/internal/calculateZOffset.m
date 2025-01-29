function [offsets, metadata] = calculateZOffset(data_path, varargin)
% Parameters
% ----------
% data_path : string
%     Path to the directory containing the image data and calibration files.
%     The function expects to find 'pollen_sample_xy_calibration.mat' in this directory along with each caiman_output_plane_N.
% motion_corrected_path: string
%     Path to motion corrected data. Default is
%     data_path/../motion_corrected/,
% debug_flag : double, logical, optional
%     If set to 1, the function displays the files in the command window and does
%     not continue processing. Default is 0.
% overwrite : logical, optional
%     Whether to overwrite existing files. Default is 0.
% start_plane : double, integer, positive
%     The starting plane index for processing. Default is 1.
% end_plane : double, integer, positive
%     The ending plane index for processing. Must be greater than or equal to
%     start_plane. Default is 1.
% num_features : double, integer, positive
%     The number of features to identify and use in each plane for
%     calculating offsets. Default is 2 features (neurons) compared across
%     z-plane/z-plane+1.
%
%
% Returns
% -------
% offsets : Nx2 array
%     An array of offsets between consecutive planes, where N is the number
%     of planes processed. Each row corresponds to a plane, and the two columns
%     represent the calculated offset in pixels along the x and y directions,
%     respectively.
%
% metadata: struct
%
% Notes
% -----
% - This function requires calibration data in input datapath:
%   - pollen_sample_xy_calibration.mat
% - The function uses MATLAB's `ginput` function for manual feature selection
%   on the images. It expects the user to manually select the corresponding
%   points on each plane.
% - The function assumes that the consecutive images will have some overlap
%   and that features will be manually identifiable and trackable across planes.
%
% Examples
% --------
% [offsets, metadata] = calculateZOffset('C:/data/images/', metadata, 1, 10, 5);
%

p = inputParser;
addRequired(p, 'data_path', @(x) ischar(x) || isstring(x));
addParameter(p, 'motion_corrected_path', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'debug_flag', 0, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'overwrite', 1, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'start_plane', 1, @(x) isnumeric(x) && x > 0);
addParameter(p, 'end_plane', 2, @(x) isnumeric(x) && x > 0); % Remove dependence on start_plane
addParameter(p, 'num_features', 3, @(x) isnumeric(x) && isPositiveIntegerValuedNumeric(x));

parse(p, data_path, varargin{:});

% ensure end_plane is greater than or equal to start_plane
if p.Results.end_plane < p.Results.start_plane
    error('end_plane must be greater than or equal to start_plane.');
end

data_path = p.Results.data_path;
motion_corrected_path = p.Results.motion_corrected_path;
debug_flag = p.Results.debug_flag;
overwrite = p.Results.overwrite;
start_plane = p.Results.start_plane;
end_plane = p.Results.end_plane;
num_features = p.Results.num_features;

if ~isfolder(data_path); error("%s does not exist", data_path); end
if isempty(motion_corrected_path)
    motion_corrected_path = fullfile(data_path, '..', 'motion_corrected');
    if ~isfolder(motion_corrected_path)
        error("The filepath for motion corrected videos does not exist. Use 'motion_corrected_path' parameter pointing to this folder.")
    end
end

if debug_flag == 1
    dir([data_path '/' '*.mat*'])
    dir([data_path '/' '*.h*']) 
    dir([data_path '/' '*.fig*'])
    return; 
end

if ~(start_plane<=end_plane); error("Start plane must be < end plane"); end

log_file_name = sprintf("%s_axial_offset_correction.log", datestr(datetime('now'), 'yyyy_mm_dd_HH_MM_SS'));
log_full_path = fullfile(data_path, log_file_name);
fid = fopen(log_full_path, 'w');
if fid == -1
    error('Cannot create or open log file: %s', log_full_path);
else
    fprintf('Log file created: %s\n', log_full_path);
end

calib_files = dir(fullfile(data_path, 'pollen*'));
if length(calib_files) < 2
    error("Missing pollen calibration files in folder:\n%s\n", data_path);
else
    for i=length(calib_files)
        calib = fullfile(calib_files(i).folder, calib_files(i).name);
        if calib_files(i).name == "pollen_sample_xy_calibration.mat"
            pollen_offsets = matfile(calib);
            diffx = pollen_offsets.diffx;
            diffy = pollen_offsets.diffy;
        end
        fprintf("Loaded calibration file:\n");
        fprintf("%s\n",fullfile(calib_files(i).folder, calib_files(i).name));
    end
end

if ~exist("diffx", "var")
    error("Missing or incorrect pollen calibration file supplied.");
end

%% Pull metadata from attributes attached to this group
% Initialize the persistent figure
persistent h1;
if isempty(h1) || ~isvalid(h1)
    h1 = figure('Position', [100, 400, 1120, 420]);
else
    clf(h1);
end

fprintf(fid, '%s : Beginning axial offset correction...\n', datestr(datetime('now'), 'yyyy_mm_dd_HH_MM_SS'));
fprintf('%s : Beginning axial offset correction...\n', datestr(datetime('now'), 'yyyy_mm_dd_HH_MM_SS'));

for plane_idx = start_plane:end_plane

    if plane_idx == end_plane
        disp('Plane_idx == end_plane, resuming...')
        continue
    end

      % Check if the figure was closed
    if ~isvalid(h1)
        disp('User closed the GUI. Exiting...');
        fclose(fid);  % Close the log file
        return;
    end

    plane_name = sprintf("%s/motion_corrected_plane_%d.h5",motion_corrected_path,plane_idx);
    plane_name_next = sprintf("%s/motion_corrected_plane_%d.h5",motion_corrected_path,plane_idx + 1);

    plane_name_save = sprintf("%s/axial_corrected_plane_%d.h5", data_path, plane_idx);
    if isfile(plane_name_save)
        fprintf(fid, '%s : %s already exists.\n', datestr(datetime('now'), 'yyyy_mm_dd_HH_MM_SS'), plane_name_save);
        if overwrite
            fprintf(fid, '%s : Parameter Overwrite=true. Deleting file: %s\n', datestr(datetime('now'), 'yyyy_mm_dd_HH_MM_SS'), plane_name_save);
            delete(plane_name_save)
        end
    end

    metadata = read_h5_metadata(plane_name, '/');
    if isempty(fieldnames(metadata)); error("No metadata found for this filepath."); end
    log_struct(fid,metadata,'metadata', log_full_path);

    pixel_resolution = metadata.pixel_resolution;

    dy = round(diffy/pixel_resolution);
    dx = round(diffx/pixel_resolution);

    ddx = diff(dy);
    ddy = diff(dx);
    scale_fact = 10;
    nsize = ceil(scale_fact/pixel_resolution);

    offsets = zeros(metadata.num_planes, 2);
    p1 = h5read(plane_name, '/Ym');
    p2 = h5read(plane_name_next, '/Ym');

    if ~isfile(plane_name_next)
        disp('Final plane reached.')
        continue
    end

    gix = nan(1, num_features);
    giy = gix;

    % search through the brightest features
    for feature_idx = 1:num_features
        try
            buffer = 10 * nsize;
            p1m = p1;
            p1m(1:buffer, :) = 0;
            p1m(end-buffer:end, :) = 0;
            p1m(:, 1:buffer) = 0;
            p1m(:, end-buffer:end) = 0;

            [mx, inds] = max(p1m(:));
            [yi, xi] = ind2sub(size(p1), inds);

            % current plane
            figure(h1);
            ax1 = subplot(1, 2, 1);
            imagesc(p1); axis image;
            xlim(ax1, [xi-scale_fact*nsize xi+scale_fact*nsize]);
            ylim(ax1, [yi-scale_fact*nsize yi+scale_fact*nsize]);
            title(sprintf('Plane %d', plane_idx));

            % next plane
            ax2 = subplot(1, 2, 2);
            imagesc(p2); axis image;
            title(sprintf('Plane %d', plane_idx + 1));

            % plot the current plane
            figure(h1);
            ax1 = subplot(1, 2, 1);
            imagesc(p1); axis image;
            xlim(ax1, [xi-scale_fact*nsize xi+scale_fact*nsize]);
            ylim(ax1, [yi-scale_fact*nsize yi+scale_fact*nsize]);
            title(sprintf('Plane %d', plane_idx));

            % highlight left subplot
            set(ax1, 'XColor', 'r', 'YColor', 'r');
            [x1, y1] = safe_ginput(ax1, ax2);
            set(ax1, 'XColor', 'k', 'YColor', 'k'); % reset left subplot color

            % update next plane plot limits based on first input
            y1 = round(y1);
            x1 = round(x1);

            % update ax2 limits
            xlim(ax2, [x1-scale_fact*nsize+ddx(plane_idx) x1+scale_fact*nsize+ddx(plane_idx)]);
            ylim(ax2, [y1-scale_fact*nsize+ddy(plane_idx) y1+scale_fact*nsize+ddy(plane_idx)]);

            % highlight right subplot
            set(ax2, 'XColor', 'r', 'YColor', 'r');
            [x2, y2] = safe_ginput(ax2, ax1);
            set(ax2, 'XColor', 'k', 'YColor', 'k'); % reset right subplot color

            p1w = p1(y1-2*nsize:y1+2*nsize, x1-2*nsize:x1+2*nsize);

            if x2 > xi + scale_fact * nsize + ddx(plane_idx) || x2 < xi - scale_fact * nsize + ddx(plane_idx) || y2 > yi + scale_fact * nsize + ddy(plane_idx) || y2 < yi - scale_fact * nsize + ddy(plane_idx)
                disp('Current point ignored.');
                gix(feature_idx) = NaN;
                giy(feature_idx) = NaN;
                p1(y1-nsize:y1+nsize, x1-nsize:x1+nsize) = 0;
            else
                y2 = round(y2);
                x2 = round(x2);
                p2w = p2(y2-nsize:y2+nsize, x2-nsize:x2+nsize);

                r = xcorr2(p1w, p2w);
                [mx, inds] = max(r(:));
                [yo, xo] = ind2sub(size(r), inds);
                yo = yo - ceil(size(r, 1) / 2);
                xo = xo - ceil(size(r, 2) / 2);

                oy = (y2 - y1) - yo;
                ox = (x2 - x1) - xo;

                gix(feature_idx) = ox;
                giy(feature_idx) = oy;

                p1(y1-nsize:y1+nsize, x1-nsize:x1+nsize) = 0;
                p2(y2-nsize:y2+nsize, x2-nsize:x2+nsize) = 0;
            end
        catch ME
            disp(ME.message);
        end
    end
    offsets(plane_idx + 1, :) = [round(nanmean(giy)) round(nanmean(gix))];
end

offsets = round(offsets);
save(fullfile(data_path, sprintf('mean_%d_neuron_offsets.mat', num_features)), 'offsets');
fclose('all');

function [x, y] = safe_ginput(active_ax, other_ax)
    valid = false;
    while ~valid
        [x, y] = ginput(1);
        % Get the current point in the normalized coordinates
        pt = get(gca, 'CurrentPoint');
        % Check if the point is within the active axis limits
        if gca == active_ax
            xlim = get(active_ax, 'XLim');
            ylim = get(active_ax, 'YLim');
            if x >= xlim(1) && x <= xlim(2) && y >= ylim(1) && y <= ylim(2)
                valid = true;
            else
                warndlg('Please select a point within the highlighted subplot.', 'Invalid Selection');
            end
        elseif gca == other_ax
            % Do nothing if the other subplot is clicked
        else
            % Do nothing if clicked outside any subplot
        end
    end
end

end
