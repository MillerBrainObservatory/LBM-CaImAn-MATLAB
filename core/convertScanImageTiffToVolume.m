function convertScanImageTiffToVolume(data_path, varargin)
% Convert ScanImage .tif files into a 4D volume.
%
% Convert raw scanimage multi-roi .tif files from a single session
% into a single 4D volumetric time-series (x, y, z, t). It's designed to process files for the
% ScanImage Version: 2016 software.
%
% Parameters
% ----------
% data_path : char
%     The directory containing the raw .tif files. Only raw .tif files from one
%     session should be in the directory.
% save_path : char, optional
%     The directory where processed files will be saved. It is created if it does
%     not exist. Defaults to the data_path directory.
% ds : string, optional
%     Name of the group (h5 dataset) to save the assembled data. Default is
%     '/Y'. Must contain a leading slash.
% debug_flag : double, logical, optional
%     If set to 1, the function displays the files in the command window and does
%     not continue processing. Defaults to 0.
% do_figures : logical, optional
%     If set to 1, mean image and single frame figures are generated and
%     saved to save_path. Defaults to 1. Note, figures will impact
%     performance, particularly on datasets with many ROI's.
% overwrite : logical, optional
%     Whether to overwrite existing files. In many instances, entire file
%     will be deleted. Default is 0.
% fix_scan_phase : logical, optional
%     Whether to correct for bi-directional scan artifacts. Default is true.
% trim_roi : double, optional
%     Pixels to trim from [left, right, top, bottom] edge of each **INDIVIDUAL ROI** before
%     horizontally concatenating the ROI's within an image. Default is
%     [0 0 0 0]. Only applies to ScanImage multi-ROI recordings.
% trim_image : double, optional
%     Pixels to trim from [left, right, top, bottom] edge of each **TILED IMAGE** before
%     horizontally concatenating the ROI's within an image. Default is
%     [0 0 0 0]. Only applies to ScanImage multi-ROI recordings.
% z_plane_order : double, optional
%     If interleaved z-planes are not ordered from 1-n_planes, reorder the
%     stack using this array as index.

% Add necessary paths
[currpath, ~, ~] = fileparts(fullfile(mfilename('fullpath')));
addpath(genpath(fullfile(currpath, '../packages/')));
addpath(genpath(fullfile(currpath, 'utils')));
addpath(genpath(fullfile(currpath, 'internal')));

import ScanImageTiffReader.*

p = inputParser;

% Define the parameters
addRequired(p, 'data_path', @(x) ischar(x) || isstring(x));
addParameter(p, 'save_path', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'ds', "/Y", @(x) (ischar(x) || isstring(x)));
addParameter(p, 'debug_flag', 0, @(x) isnumeric(x) || islogical(x));
addParameter(p, 'do_figures', 1, @(x) isnumeric(x) || islogical(x));
addParameter(p, 'overwrite', 0, @(x) isnumeric(x) || islogical(x));
addParameter(p, 'num_cores', 1, @(x) isnumeric(x));

%% additional parameters for assemblyn/pre-proccessing
addParameter(p, 'fix_scan_phase', true, @(x) isnumeric(x) || islogical(x));
addParameter(p, 'trim_roi', [0 0 0 0], @isnumeric);
addParameter(p, 'trim_image', [0 0 0 0], @isnumeric);
addParameter(p, 'z_plane_order', [], @isnumeric);

parse(p, data_path, varargin{:});

% Retrieve the parsed input arguments
data_path = convertStringsToChars(p.Results.data_path);
save_path = convertStringsToChars(p.Results.save_path);

if ~isfolder(data_path); error("Data path:\n %s\n ..does not exist", fullfile(data_path)); end

% Make the save path in data_path/assembly, if not given
if isempty(save_path)
    save_path = fullfile(data_path, '../', 'assembled');
    if ~isfolder(save_path); mkdir(save_path);
        warning('Creating save path since one was not provided, located: %s', save_path);
    end
elseif ~isfolder(save_path)
    mkdir(save_path);
end

ds = p.Results.ds;
debug_flag = p.Results.debug_flag;
overwrite = p.Results.overwrite;
fix_scan_phase = p.Results.fix_scan_phase;
do_figures = p.Results.do_figures;
% num_cores = p.Results.num_cores;
trim_roi = p.Results.trim_roi;
trim_image = p.Results.trim_image;
z_plane_order = p.Results.z_plane_order;

if debug_flag == 1; dir([data_path '/' '*.tif']); return; end

files = dir(fullfile(data_path, '*.tif*'));
if isempty(files)
    error('No suitable tiff files found in: \n  %s', data_path);
end

% Until a firm scanimage metadata value can be used for the number of files
% in a recording session, just count them.
num_files=length(files);
if num_files > 1
    multifile=true;
else
    multifile=false;
end

log_file_name = sprintf("%s_assembly.log", datestr(datetime("now"), 'dd_mmm_yyyy_HH_MM_SS'));
log_full_path = fullfile(save_path, log_file_name);
fid = fopen(log_full_path, 'w');
if fid == -1
    error('Cannot create or open log file: %s', log_full_path);
else
    fprintf('Log file created: %s\n', log_full_path);
end

if do_figures
    fig_save_path = fullfile(save_path, "figures");
    if ~isfolder(fig_save_path); mkdir(fig_save_path); end
end

% Use the first tiff file to pull out metadata
firstFileFullPath = fullfile(files(1).folder, files(1).name);
metadata = get_metadata(firstFileFullPath);

metadata.multifile=multifile;
metadata.num_files=num_files;
num_planes = metadata.num_planes;
num_rois = metadata.num_rois;
num_frames = metadata.num_frames;
data_type = metadata.sample_format;
tiff_width = metadata.tiff_width;

[t_left, t_right, t_top, t_bottom] = deal(trim_roi(1), trim_roi(2), trim_roi(3), trim_roi(4));
[t_left_image, t_right_image, t_top_image, t_bottom_image] = deal(trim_image(1), trim_image(2), trim_image(3), trim_image(4));

metadata.trim_roi = [t_left, t_right, t_top, t_bottom]; % store the number of pixels to trim
metadata.trim_edge = [t_left_image, t_right_image, t_top_image, t_bottom_image]; % store the number of pixels to trim

% Calculate ROI dims and Image dims
raw_x_roi = metadata.roi_width_px;
raw_x_roi = min(raw_x_roi, tiff_width);
raw_x = raw_x_roi * num_rois;

raw_y_roi = metadata.roi_height_px;
raw_y_roi = min(raw_y_roi, metadata.tiff_length);

% ROI slices
trimmed_yslice = (t_top+1:raw_y_roi-t_bottom); % used to slice roi_arr, which already is separated as an individual roi
trimmed_xslice = (t_left+1:raw_x_roi-t_right);

%% File structure setup
raw_files = []; assembled_files = [];

% display whats there with the size
contents = dir([save_path '/' '*.h5']);
for i = 1:length(contents)
    if contains(contents(i).name, 'raw_plane_')
        raw_files = [raw_files; contents(i)];
    elseif contains(contents(i).name, 'assembled_plane_')
        assembled_files = [assembled_files; contents(i)];
    end
end
if ~isempty(raw_files)
    fprintf("Previously assembled raw files in save_path : (%s):\n", save_path);
    fprintf('%-30s %-20s %-10s\n', 'Name', 'Date', 'Size (Gb)');
    fprintf('%-30s %-20s %-10s\n', '----', '----', '------------');
    for i = 1:length(raw_files)
        fprintf('%-30s %-20s %.2f\n', raw_files(i).name, raw_files(i).date, raw_files(i).bytes / 1e9);
    end
end
if ~isempty(assembled_files)
    fprintf("Previously assembled/pre-processed files in save_path : (%s):\n", save_path);
    fprintf('%-30s %-20s %-10s\n', 'Name', 'Date', 'Size (Gb)');
    fprintf('%-30s %-20s %-10s\n', '----', '----', '------------');
    for i = 1:length(assembled_files)
        fprintf('%-30s %-20s %.2f\n', assembled_files(i).name, assembled_files(i).date, assembled_files(i).bytes / 1e9);
    end
end

metadata.dataset_name = ds;
metadata.num_files = num_files;
log_message(fid, "------- Metadata ------------\n");
log_struct(fid,metadata,'Metadata',log_full_path);
log_message(fid, "-----------------------------\n");
log_message(fid, "Aggregating data from %d file(s) with %d plane(s).\n",num_files, num_planes);

if numel(assembled_files) == num_planes
    if overwrite
        log_message(fid, 'Save path contains assembled data. Overwrite = true, deleting assembled files...');
        for di=1:num_planes
            pstr=sprintf("assembled_plane_%d.h5", di);
            delete(fullfile(save_path,pstr));
        end
    else
        log_message(fid, 'Save path contains assembled data. Overwrite = false, returning...');
        return
    end
end

offset_file = 0;
for file_idx = 1:num_files
    if file_idx > 1; offset_file = offset_file + num_frames; end
    tpf = tic;
    raw_tiff_file = fullfile(data_path, files(file_idx).name);

    log_message(fid, 'Creating temporary file %d of %d...\n', file_idx, num_files);

    hTif=ScanImageTiffReader(raw_tiff_file);
    hTif=hTif.data();
    size_y=size(hTif);

    hTif=reshape(hTif, [size_y(1), size_y(2), num_planes, num_frames]);
    hTif=permute(hTif, [2 1 3 4]);
    
    if z_plane_order
        hTif = hTif(:,:,z_plane_order,:);
    end

    for pi = 1:num_planes
        tps = tic;
        raw_full_path = sprintf("raw_plane_%d.h5", pi);
        full_name = fullfile(save_path, raw_full_path);
        if isfile(full_name)
            if overwrite
                log_message(fid, "File %s exists, deleting...\n", full_name);
                delete(full_name)
            else
                log_message(fid, 'Raw data for plane %d exists, but user chose not to overwrite. Skipping.\n',pi);
                continue
            end
        end
        write_frames_3d(full_name,hTif(:,:,pi,:),ds,multifile,4);
        write_metadata_h5(metadata,full_name, '/');
        log_message(fid, 'Plane %d saved in %.2f seconds.\n',pi,toc(tps));
    end
    log_message(fid, 'Temporary file %d loaded and saved in %.2f seconds.\n',pi,toc(tpf));
end

clear hTif size_y raw_full_path
tfile = tic;

% Initialize a container to hold our final, re-tiled image
% - Should have the height of a single ROI
% - Should have the width of a single ROI * num_rois (variable held by raw_x)
z_timeseries = zeros(raw_y_roi, raw_x, num_frames, data_type);
for plane_idx = 1:num_planes

    tplane = tic;

    log_message(fid, 'Processing z-plane %d/%d...\n', plane_idx, num_planes);

    p_str = sprintf("plane_%d", plane_idx);
    raw_p_str = sprintf("raw_%s", p_str);
    assembled_p_str = sprintf("assembled_%s", p_str);
    raw_full_path = sprintf("%s.h5",fullfile(save_path,raw_p_str));
    assembled_full_path = sprintf("%s.h5",fullfile(save_path,assembled_p_str));

    if ~isfile(raw_full_path)
        error("Processing stopped due to missing temporary file. Try re-processing with overwrite=True to delete a corrupted file.")
    end

    if isfile(assembled_full_path)
        warning("File:\n%s\n...already exists.")
        if overwrite
            log_message(fid, "Overwrite set to true, deleting...\n", assembled_full_path);
            delete(assembled_full_path)
        else
            continue
        end
    end

    vol = h5read(raw_full_path,'/Y');
    if fix_scan_phase

        log_message(fid, "Correcting for scan phase...\n")
        plane_offset = returnScanOffset(vol,1,data_type);
        log_message(fid, "Optimal phase: %d px shift.\n", abs(plane_offset));

        % new_min_size = (1+(abs(plane_offset)):osv-abs(plane_offset));
        vol = fixScanPhase(vol,plane_offset,1,data_type);
    end

    % resize if our array had pixels trimmed
    trimmed_xslice = trimmed_xslice(trimmed_xslice <= size(vol, 2));
    vol = vol(:,trimmed_xslice,:);
    log_message(fid, "Post-offset corrected and trimmed movie contains %d x pixels...\n", size(vol, 2));

    cnt = 1;
    offset_x = 0;
    raw_offset_y = 0;
    for roi_idx = 1:metadata.num_rois
        log_message(fid, "Processing ROI: %d/%d...\n", roi_idx, num_rois);
        if cnt > 1
            raw_offset_y = raw_offset_y + raw_y_roi + metadata.num_lines_between_scanfields;
        end

        % assemble the **UNTRIMMED ROI**
        raw_yslice = (raw_offset_y + 1):(raw_offset_y + raw_y_roi);
        roi_arr = vol(raw_yslice, :, :);

        % apply trim
        roi_arr = squeeze(roi_arr(trimmed_yslice, :, :));
        if cnt > 1 % wait until the new array size is calculated
            offset_x = offset_x + size(roi_arr, 2);
        end

        % place this ROI in the final image
        z_timeseries( ...
            1: size(roi_arr,1), ...
            (offset_x + 1):(offset_x + size(roi_arr,2)), ...
            : ...
            ) = roi_arr;
        cnt = cnt + 1;
    end
    % remove padded 0's
    z_timeseries = z_timeseries( ...
        any(z_timeseries, [2, 3]), ...
        any(z_timeseries, [1, 3]), ...
        :);

    fsize = size(z_timeseries);
    z_timeseries=z_timeseries( ...
        1+t_top_image:fsize(1)-t_bottom_image, ...
        1+t_left_image:fsize(2)-t_right_image, ...
        : ...
        );

    mean_img = mean(z_timeseries, 3);
    if do_figures
        img_frame = z_timeseries(:,:,2);
        images = {img_frame, mean_img};
        labels = {'Second Frame', 'Mean Image'};
        scale_full = calculate_scale(size(img_frame, 2), metadata.pixel_resolution);
        scales = {scale_full, scale_full};

        plane_save_path = fullfile(fig_save_path, sprintf('plane_%d.png', plane_idx));
        plane_save_path_fig = fullfile(fig_save_path, sprintf('plane_%d.fig', plane_idx));

        write_images_to_tile( ...
            images, ...
            metadata, ...
            'titles', labels, ...
            'fig_title',  sprintf('plane_%d', plane_idx), ...
            'scales', scales, ...
            'save_name', plane_save_path ...
            );

        savefig(plane_save_path_fig);
    end
    write_frames_3d(assembled_full_path, z_timeseries,ds,multifile,4);
    try
        h5create(assembled_full_path,"/Ym",size(mean_img));
    catch
    end
    try
        h5write(assembled_full_path, '/Ym', mean_img);
    catch ME
        warning(ME.identifier, '%s\n', ME.message)
    end
    write_metadata_h5(metadata, assembled_full_path, '/');
    if getenv("OS") == "Windows_NT"
        mem = memory;
        max_avail = mem.MemAvailableAllArrays / 1e9;
        mem_used = mem.MemUsedMATLAB / 1e9;
        log_message(fid, "MEMORY USAGE (max/available/used): %.2f/%.2f\n", max_avail, mem_used)
    end
    log_message(fid, "---- Complete: Plane %d processed in %.2f seconds ----\n",plane_idx, toc(tplane));
    close all hidden;
end

% Cleanup temporarily created files
raw_files = dir([save_path '/' '*raw_plane_*.h5']);
for i = 1:length(raw_files)
    file_to_delete = fullfile(raw_files(i).folder, raw_files(i).name);
    delete(file_to_delete);
end

log_message(fid,"Processing complete. Time: %.3f minutes.",toc(tfile)/60);
fclose('all');
end

function dataOut = fixScanPhase(dataIn, offset, dim, dtype)
% Find the lateral shift that maximizes the correlation between
% alternating lines for the resonant galvo. Correct for phase-offsets
% occurring between each successive line.

[sy, sx, sc, sz] = size(dataIn);
dataOut = zeros(sy, sx, sc, sz, dtype);

if dim == 1
    if offset > 0
        dataOut(1:2:sy, 1:sx, :, :) = dataIn(1:2:sy, :, :, :);
        dataOut(2:2:sy, 1+offset:(offset+sx), :, :) = dataIn(2:2:sy, :, :, :);

    elseif offset < 0
        offset = abs(offset);
        dataOut(1:2:sy, 1+offset:(offset+sx), :, :) = dataIn(1:2:sy, :, :, :);
        dataOut(2:2:sy, 1:sx, :, :) = dataIn(2:2:sy, :, :, :);
    else
        dataOut(:, 1+floor(offset/2):sx+floor(offset/2), :, :) = dataIn;
    end
end
if offset ~= 0
    dataOut = dataOut(:, 1+ceil(abs(offset)/2):end-(abs(offset)/2), :, :);
end
end

function correction = returnScanOffset(Iin,dim,dtype)

if numel(size(Iin)) == 3
    Iin = mean(Iin,3);
elseif numel(size(Iin)) == 4
    Iin = mean(mean(Iin,4),3);
end

n = 8;
switch dim
    case 1
        Iv1 = Iin(1:2:end,:);
        Iv2 = Iin(2:2:end,:);

        Iv1 = Iv1(1:min([size(Iv1,1) size(Iv2,1)]),:);
        Iv2 = Iv2(1:min([size(Iv1,1) size(Iv2,1)]),:);

        buffers = zeros(size(Iv1,1),n, dtype);

        Iv1 = cat(2,buffers,Iv1,buffers);
        Iv2 = cat(2,buffers,Iv2,buffers);

        Iv1 = reshape(Iv1',[],1);
        Iv2 = reshape(Iv2',[],1);

    case 2
        Iv1 = Iin(:,1:2:end);
        Iv2 = Iin(:,2:2:end);

        Iv1 = Iv1(:,1:min([size(Iv1,2) size(Iv2,2)]));
        Iv2 = Iv2(:,1:min([size(Iv1,2) size(Iv2,2)]),:);

        buffers = zeros(n,size(Iv1,2), dtype);

        Iv1 = cat(1,buffers,Iv1,buffers);
        Iv2 = cat(1,buffers,Iv2,buffers);

        Iv1 = reshape(Iv1,[],1);
        Iv2 = reshape(Iv2,[],1);
end

Iv1 = Iv1-mean(Iv1); Iv1(Iv1<0) = 0;
Iv2 = Iv2-mean(Iv2); Iv2(Iv2<0) = 0;
[r,lag] = xcorr(Iv1,Iv2,n,'unbiased');
[~,ind] = max(r);
correction = lag(ind);
end
