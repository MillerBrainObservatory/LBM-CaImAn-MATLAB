function [offsets] = calculateZOffset(data_path, save_path, varargin)
% Parameters
% ----------
% data_path : string
%     Path to the directory containing the image data and calibration files.
%     The function expects to find 'pollen_sample_xy_calibration.mat' in this directory along with each caiman_output_plane_N.
% save_path : char
%     Path to the directory to save the motion vectors.
% dataset_name : string, optional
%     Group path within the hdf5 file that contains raw data.
%     Default is 'registration'.
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
% num_features : double, integer, positive
%     The number of features to identify and use in each plane for
%     calculating offsets. Default is 3 features/neurons compared across
%     z-plane/z-plane+1.
%
% Returns
% -------
% offsets : Nx2 array
%     An array of offsets between consecutive planes, where N is the number
%     of planes processed. Each row corresponds to a plane, and the two columns
%     represent the calculated offset in pixels along the x and y directions,
%     respectively.
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
% Example
% -------
% offsets = calculateZOffset('C:/data/images/', metadata, 1, 10, 5);
%
% See also LOAD, MAX, IND2SUB, XCORR2, GINPUT, NANMEAN

p = inputParser;
addRequired(p, 'data_path');
addRequired(p, 'save_path');
addParameter(p, 'dataset_name', "/extraction", @(x) (ischar(x) || isstring(x)) && isValidGroupPath(x));
addOptional(p, 'debug_flag', 0, @(x) isnumeric(x));
addParameter(p, 'overwrite', 1, @(x) isnumeric(x));
addParameter(p, 'num_cores', 1, @(x) isnumeric(x));
addParameter(p, 'start_plane', 1, @(x) isnumeric(x) && x > 0);
addParameter(p, 'end_plane', 1, @(x) isnumeric(x) && x >= p.Results.start_plane);
addParameter(p, 'num_features', 3, @(x) isnumeric(x) && isPositiveIntegerValuedNumeric(x));
parse(p, data_path, save_path, varargin{:});

data_path = p.Results.data_path;
save_path = p.Results.save_path;
dataset_name = p.Results.dataset_name; % here for param consistency but ignored
debug_flag = p.Results.debug_flag;
overwrite = p.Results.overwrite;
num_cores = p.Results.num_cores;
start_plane = p.Results.start_plane;
end_plane = p.Results.end_plane;
num_features = p.Results.num_features;

if ~isfolder(data_path)
    error("Data path:\n %s\n ..does not exist", data_path);
end

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

log_file_name = sprintf("%s_axial_offset_correction", datestr(datetime('now'), 'yyyy_mm_dd_HH_MM_SS'));
log_full_path = fullfile(save_path, log_file_name);
fid = fopen(log_full_path, 'w');
if fid == -1
    error('Cannot create or open log file: %s', log_full_path);
else
    fprintf('Log file created: %s\n', log_full_path);
end
% closeCleanupObj = onCleanup(@() fclose(fid));

calib_files = fullfile(data_path, 'pollen*');
calib_files = dir(calib_files);
if length(calib_files) < 2
    error("Missing pollen calibration files in folder:\n%s\n.", data_path);
else
    for i=length(calib_files)
        calib = fullfile(calib_files(i).folder, calib_files(i).name);
        if calib_files(i).name == "pollen_sample_xy_calibration.mat"
            load(calib);
        end
        fprintf("Loaded calibration file:\n");
        fprintf("%s\n",fullfile(calib_files(i).folder, calib_files(i).name));
    end
end

if ~exist("diffx", "var")
    error("Missing or incorrect pollen calibration file supplied.");
end

%% Pull metadata from attributes attached to this group
num_cores = max(num_cores, 23);
fprintf(fid, '%s : Beginning registration with %d cores...\n', datestr(datetime('now'), 'yyyy_mm_dd_HH_MM_SS'), num_cores); tall=tic;
for curr_plane = start_plane:end_plane
    if curr_plane+1 > end_plane
        fprintf("Current plane (%d) > Last Plane (%d)", curr_plane, end_plane)
        continue;
    end
    plane_name = sprintf("%s/segmented_plane_%d.h5", data_path, curr_plane);
    plane_name_next = sprintf("%s/segmented_plane_%d.h5", data_path, curr_plane+1);

    plane_name_save = sprintf("%s/axial_corrected_plane_%d.h5", save_path, curr_plane);
    if isfile(plane_name_save)
        fprintf(fid, '%s : %s already exists.\n', datestr(datetime('now'), 'yyyy_mm_dd_HH_MM_SS'), plane_name_save);
        if overwrite
            fprintf(fid, '%s : Parameter Overwrite=true. Deleting file: %s\n', datestr(datetime('now'), 'yyyy_mm_dd_HH_MM_SS'), plane_name_save);
            delete(plane_name_save)
        end
    end

    h5_data = h5info(plane_name, '/');
    metadata = struct();
    for k = 1:numel(h5_data.Attributes)
        attr_name = h5_data.Attributes(k).Name;
        attr_value = h5readatt(plane_name, sprintf("/%s",h5_data.Name), attr_name);
        metadata.(matlab.lang.makeValidName(attr_name)) = attr_value;
    end

    pixel_resolution = metadata.pixel_resolution;

    if ~(metadata.num_planes >= end_plane)
        error("Not enough planes to process given user supplied argument: %d as end_plane when only %d planes exist in this dataset.", end_plane, metadata.num_planes);
    end

    dy = round(diffy/pixel_resolution);
    dx = round(diffx/pixel_resolution);

    ddx = diff(dy);
    ddy = diff(dx);
    scale_fact = 10;
    nsize = ceil(scale_fact/pixel_resolution);

    offsets = zeros(metadata.num_planes, 2);
    p1 = h5read(plane_name, '/Ym');
    p2 = h5read(plane_name_next, '/Ym');

    gix = nan(1,3);
    giy = gix;

    %% search through the brightest features
    for feature_idx = 1:num_features
        try
            buffer = 10*nsize;
            p1m = p1;
            p1m(1:buffer,:) = 0;
            p1m(end-buffer:end,:) = 0;
            p1m(:,1:buffer) = 0;
            p1m(:,end-buffer:end) = 0;

            [mx,inds] = max(p1m(:));
            [yi,xi] = ind2sub(size(p1),inds);

            h1 = figure;
            set(h1,'position',[100 400 560 420])
            imagesc(p1); axis image
            xlim([xi-scale_fact*nsize xi+scale_fact*nsize])
            ylim([yi-scale_fact*nsize yi+scale_fact*nsize])

            figure(h1)
            [x1,y1] = ginput(1);

            h2 = figure;
            set(h2,'position',[700 400 560 420])
            imagesc(p2); axis image
            xlim([xi-scale_fact*nsize+ddx(curr_plane) xi+scale_fact*nsize+ddx(curr_plane)])
            ylim([yi-scale_fact*nsize+ddy(curr_plane) yi+scale_fact*nsize+ddy(curr_plane)])

            y1 = round(y1);
            x1 = round(x1);
            p1w = p1(y1-2*nsize:y1+2*nsize,x1-2*nsize:x1+2*nsize);

            figure(h2)
            [x2,y2] = ginput(1);

            if x2 > xi+scale_fact*nsize+ddx(curr_plane) || x2 < xi-scale_fact*nsize+ddx(curr_plane) || y2 >  yi+scale_fact*nsize+ddy(curr_plane) || y2 < yi-scale_fact*nsize+ddy(curr_plane)

                disp('Current point ignored.')

                gix(feature_idx) = NaN;
                giy(feature_idx) = NaN;

                close all
                p1(y1-nsize:y1+nsize,x1-nsize:x1+nsize) = 0;

            else

                y2 = round(y2);
                x2 = round(x2);
                p2w = p2(y2-nsize:y2+nsize,x2-nsize:x2+nsize);

                r = xcorr2(p1w,p2w);
                [mx,inds] = max(r(:));
                [yo,xo] = ind2sub(size(r),inds);
                yo = yo-ceil(size(r,1)/2);
                xo = xo-ceil(size(r,2)/2);

                oy = (y2-y1)-yo;
                ox = (x2-x1)-xo;

                gix(feature_idx) = ox;
                giy(feature_idx) = oy;

                close all
                p1(y1-nsize:y1+nsize,x1-nsize:x1+nsize) = 0;
                p2(y2-nsize:y2+nsize,x2-nsize:x2+nsize) = 0;

            end
        catch ME
            disp('Current mapping failed');
        end
    end
    offsets(curr_plane+1,:) = [round(nanmean(giy)) round(nanmean(gix))];
end

offsets = round(offsets);
save(fullfile(data_path, 'three_neuron_mean_offsets.mat'),'offsets')

end