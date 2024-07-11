function convertScanImageTiffToVolume(data_path, save_path, ds, debug_flag, do_figures, overwrite, fix_scan_phase, save_temp, varargin)
% Convert ScanImage .tif files into a 4D volume.
%
% Convert raw `ScanImage`_ multi-roi .tif files from a single session
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
%     Name of the group (h5 dataset) to save the extracted data. Default is
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
%     will be deleted. Default is 1.
% trim_pixels : double, optional
%     Pixels to trim from [left, right, top, bottom] of each **individual ROI** before
%     horizontally concatenating the ROI's within an image. Default is
%     [0 0 0 0]. Only applies to ScanImage multi-ROI recordings.
% fix_scan_phase : logical, optional
%     Whether to correct for bi-directional scan artifacts. Default is true.
% save_temp : logical, optional
%     Whether to save each raw plane as a temporary hdf5 file. Default is
%     true.
%
% Examples
% --------
% % Print all files in the data folder '/data' and exit without processing.
% convertScanImageTiffToVolume('data/', 'output/', '/Y', 1);
%
% % Convert ScanImage TIFF files to 4D volume
% convertScanImageTiffToVolume('data/', 'output/', '/Y', 0, 0, 1);
%
% % Trim 5 pixels from the left and right of each ROI, 10 on the top, none
% % on the bottom.
% convertScanImageTiffToVolume('data/', 'output/', '/Y', 0, 1, 1, 'fix_scan_phase', true, 'trim_pixels', [5 5 10 0]);
%
% Warnings
% --------
% A logfile will accompany each time this function is ran. Sometimes MATLAB
% likes to hang onto the file nice and tight. You may need to restart
% MATLAB (in some cases your entire computer) to be able to delete a
% logfile you don't want.
%
% .. _ScanImage: https://www.mbfbioscience.com/products/scanimage/

% Add necessary paths
[currpath, ~, ~] = fileparts(fullfile(mfilename('fullpath')));
addpath(genpath(fullfile(currpath, '../packages/ScanImage/')));
addpath(genpath("utils"));
addpath(genpath("internal"));

import ScanImageTiffReader.*

p = inputParser;

% Define the parameters
addRequired(p, 'data_path', @(x) ischar(x) || isstring(x));
addOptional(p, 'save_path', data_path, @(x) ischar(x) || isstring(x));
addOptional(p, 'ds', "/Y", @(x) (ischar(x) || isstring(x)) && is_valid_group(x));
addOptional(p, 'debug_flag', 0, @(x) isnumeric(x) || islogical(x));
addOptional(p, 'do_figures', 0, @(x) isnumeric(x) || islogical(x));
addOptional(p, 'overwrite', true, @(x) isnumeric(x) || islogical(x));
addParameter(p, 'fix_scan_phase', true, @(x) isnumeric(x) || islogical(x));
addParameter(p, 'trim_pixels', [0 0 0 0], @isnumeric);
addParameter(p, 'save_temp', true, @(x) isnumeric(x) || islogical(x));

% Parse the input arguments
parse(p, data_path, save_path, ds, debug_flag, do_figures, overwrite, fix_scan_phase, save_temp, varargin{:});

% Retrieve the parsed input arguments
data_path = fullfile(p.Results.data_path);
save_path = fullfile(p.Results.save_path);

ds = p.Results.ds;
debug_flag = p.Results.debug_flag;
overwrite = p.Results.overwrite;
fix_scan_phase = p.Results.fix_scan_phase;
trim_pixels = p.Results.trim_pixels;
do_figures = p.Results.do_figures;
sav_temp = p.Results.save_temp;

if ~isfolder(data_path); error("Data path:\n %s\n ..does not exist", fullfile(data_path)); end
if debug_flag == 1; dir([data_path, '*.tif']); return; end

if isempty(save_path)
    warning("No save_path given. Saving data in data_path: %s\n", fullfile(data_path));
    save_path = data_path;
else
    % save path exists; display whats there with the size
    contents = dir([save_path, '*.h5']);
    raw_files = [];
    extracted_files = [];
    for i = 1:length(contents)
        if contains(contents(i).name, 'raw_plane_')
            raw_files = [raw_files; contents(i)];
        elseif contains(contents(i).name, 'extracted_plane_')
            extracted_files = [extracted_files; contents(i)];
        end
    end
end
if ~isempty(raw_files)
    fprintf("Previously extracted raw files in save_path : (%s):\n", save_path);
    fprintf('%-30s %-20s %-10s\n', 'Name', 'Date', 'Size (Gb)');
    fprintf('%-30s %-20s %-10s\n', '----', '----', '------------');
    for i = 1:length(raw_files)
        fprintf('%-30s %-20s %.2f\n', raw_files(i).name, raw_files(i).date, raw_files(i).bytes / 1e9);
    end
end
if ~isempty(extracted_files)
    fprintf("Previously extracted/pre-processed files in save_path : (%s):\n", save_path);
    fprintf('%-30s %-20s %-10s\n', 'Name', 'Date', 'Size (Gb)');
    fprintf('%-30s %-20s %-10s\n', '----', '----', '------------');
    for i = 1:length(extracted_files)
        fprintf('%-30s %-20s %.2f\n', extracted_files(i).name, extracted_files(i).date, extracted_files(i).bytes / 1e9);
    end
end

log_file_name = sprintf("%s_extraction.log", datestr(datetime("now"), 'dd_mmm_yyyy_HH_MM_SS'));
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

files = dir(fullfile(data_path, '*.tif*'));
if isempty(files)
    error('No suitable tiff files found in: \n  %s', data_path);
end

num_files=length(files);
if num_files > 1
    multifile=true;
else
    multifile=false;
end

firstFileFullPath = fullfile(files(1).folder, files(1).name);

% We add some values to the metadata to attach to H5 attributes and
% make file access / parameter access easier down the pipeline.
metadata = get_metadata(firstFileFullPath);

[t_left, t_right, t_top, t_bottom] = deal(trim_pixels(1), trim_pixels(2), trim_pixels(3), trim_pixels(4));
metadata.trim_pixels = [t_left, t_right, t_top, t_bottom]; % store the number of pixels to trim
raw_x = metadata.num_pixel_xy(1);
raw_x = min(raw_x, metadata.tiff_width);
raw_y = metadata.num_pixel_xy(2);
raw_y = min(raw_y, metadata.tiff_length);
trimmed_yslice = (t_top+1:raw_y-t_bottom);
trimmed_xslice = (t_left+1:raw_x-t_right);

metadata.multifile=multifile;
metadata.num_files=num_files;
num_planes = metadata.num_planes;
num_rois = metadata.num_rois;
num_frames = metadata.num_frames;
data_type = metadata.sample_format;

metadata.dataset_name = ds;
metadata.num_files = num_files;
log_message(fid, "------- Metadata ------------");
log_struct(fid,metadata,'Metadata',log_full_path);
log_message(fid, "-----------------------------");
log_message(fid, "Aggregating data from %d file(s) with %d plane(s).\n",num_files, num_planes);

if save_temp
    if multifile
        append=true;
    else
        append=false;
    end
    offset_file = 0;
    % Aout = zeros(metadata.tiff_length, metadata.tiff_width, num_planes, num_frames*num_files, data_type);
    for file_idx = 1:num_files
        if file_idx > 1; offset_file = offset_file + num_frames; end
        tpf = tic;
        raw_file = fullfile(data_path, files(file_idx).name);
        log_message(fid, 'Loading file %d of %d...\n', file_idx, num_files);

        hTif=ScanImageTiffReader(raw_file);
        hTif=hTif.data();
        size_y=size(hTif);
        hTif=reshape(hTif, [size_y(1), size_y(2), num_planes, num_frames]);
        hTif=permute(hTif, [2 1 3 4]);

        log_message(fid, '%.2f Gb tiff data loaded. Saving data to file...\n', whos('hTif').bytes / 1e9);
        for pi = 1:num_planes
            tps = tic;
            plane_name = sprintf("raw_plane_%d.h5", pi);
            full_name = fullfile(save_path, plane_name);
            if isfile(full_name)
                if overwrite
                    log_message(fid, "File %s exists, deleting...\n", full_name);
                    delete(full_name)
                else
                    log_message(fid, 'Raw data for plane %d exists, but user chose not to overwrite. Skipping.\n',pi);
                    continue
                end
            end
            write_frames_3d(full_name,hTif(:,:,pi,:),ds,append,4);
            log_message(fid, 'Plane %d saved in %.2f seconds.\n',pi,toc(tps));
        end
        log_message(fid, 'File %d loaded and saved in %.2f seconds.\n',pi,toc(tpf));
    end
    clear hTif size_y plane_name
end
tfile = tic;
z_timeseries = zeros(raw_y, raw_x * metadata.num_rois, num_frames, data_type);
for plane_idx = 1:num_planes
    tplane = tic;

    log_message(fid, 'Processing z-plane %d/%d...\n', plane_idx, num_planes);

    p_str = sprintf("plane_%d", plane_idx);
    raw_p_str = sprintf("raw_%s", p_str);
    extracted_p_str = sprintf("extracted_%s", p_str);
    plane_name = sprintf("%s.h5",fullfile(data_path,raw_p_str));
    frame_name = sprintf("%s.h5",fullfile(data_path,extracted_p_str));

    if isfile(frame_name)
        if overwrite
            log_message(fid, "File %s exists, deleting...\n", frame_name);
            delete(frame_name)
        else
            continue
        end
    end

    vol = h5read(plane_name,'/Y');

    if fix_scan_phase

        osv = size(vol,2);
        log_message(fid, "Correcting for scan phase...\n")
        log_message(fid, "Original movie contains %d x pixels.\n", osv)

        plane_offset = returnScanOffset(vol,1,data_type);
        log_message(fid, "Optimal phase: %d px shift.\n", abs(plane_offset));

        % new_min_size = (1+(abs(plane_offset)):osv-abs(plane_offset));
        vol = fixScanPhase(vol,plane_offset,1,data_type);
        log_message(fid, "Post-offset corrected movie contains %d x pixels....", size(vol, 2));

        vol = vol(:,trimmed_xslice,:);
    end

    cnt = 1;
    offset_x = 0;
    raw_offset_y = 0;
    for roi_idx = 1:metadata.num_rois
        log_message(fid, "Processing ROI: %d/%d...\n", roi_idx, num_rois);
        if cnt > 1
            raw_offset_y = raw_offset_y + raw_y + metadata.num_lines_between_scanfields;
        end

        % use the **untrimmed** roi in the phase offset correction
        raw_yslice = (raw_offset_y + 1):(raw_offset_y + raw_y);
        roi_arr = vol(raw_yslice, :, :);

        % pre-trim this roi
        roi_arr = squeeze(roi_arr(trimmed_yslice, :, :));
        if cnt > 1 % wait until the new array size is calculated
            offset_x = offset_x + size(roi_arr, 2);
        end

        z_timeseries( ...
            1: size(roi_arr,1), ...
            (offset_x + 1):(offset_x + size(roi_arr,2)), ...
            : ...
            ) = roi_arr;

        %% Figures
        if do_figures
            [yind, xind] = get_central_indices(roi_arr(:,:,2), 40);
            [yindr, xindr] = get_central_indices(roi_arr(:,:,2), 40);

            images = {roi_arr(yind,xind,2), roi_arr(yindr, xindr, 2)};
            zoomed_scale = calculate_scale(size(images{1},2),metadata.pixel_resolution);
            roi_scales = {zoomed_scale,zoomed_scale};
            labels = {'Pre-Corrected/Trimmed', 'Phase-Corrected/Trimmed'};

            roi_savename = fullfile(fig_save_path, sprintf('plane_%d_roi_%d.png',plane_idx,roi_idx));
            write_tiled_figure( ...
                images, ...
                metadata, ...
                'fig_title', sprintf('ROI %d', roi_idx), ...
                'titles', labels, ...
                'scales', roi_scales, ...
                'save_name', roi_savename ...
                );
        end

        cnt = cnt + 1;
    end

    % remove padded 0's
    z_timeseries = z_timeseries( ...
        any(z_timeseries, [2, 3]), ...
        any(z_timeseries, [1, 3]), ...
        :);

    mean_img = mean(z_timeseries, 3);
    if do_figures
        img_frame = z_timeseries(:,:,2);
        [yind, xind] = get_central_indices(mean_img, 30); % 30 pixels around the center of the brightest part of an image frame
        images = {img_frame, mean_img, mean_img(yind, xind)};
        labels = {'Second Frame', 'Mean Image', 'Mean Image(Zoom)'};
        scale_full = calculate_scale(size(img_frame, 2), metadata.pixel_resolution);
        scale_roi = calculate_scale( size(img_frame(yind, xind),2), metadata.pixel_resolution);
        scales = {scale_full, scale_full, scale_roi};
        plane_save_path = fullfile(fig_save_path, sprintf('plane_%d_mean_frame.png', plane_idx));

        write_tiled_figure( ...
            images, ...
            metadata, ...
            'titles', labels, ...
            'scales', scales, ...
            'save_name', plane_save_path ...
            );
    end
    write_frames_3d(frame_name, z_timeseries,ds,append,4);
    try
        h5create(frame_name,"/Ym",size(mean_img));
    catch
    end
    try
        h5write(frame_name, '/Ym', mean_img);
    catch ME
        warning(ME.identifier, '%s\n', ME.message)
    end
    write_metadata_h5(metadata, frame_name, '/');
    if getenv("OS") == "Windows_NT"
        mem = memory;
        max_avail = mem.MemAvailableAllArrays / 1e9;
        mem_used = mem.MemUsedMATLAB / 1e9;
        log_message(fid, "MEMORY USAGE (max/available/used): %.2f/%.2f\n", max_avail, mem_used)
    end
    log_message(fid, "---- Complete: Plane %d processed in %.2f seconds ----\n",plane_idx, toc(tplane));
    close all hidden;
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
    d = size(dataOut,2);
    di = size(dataOut(:, 1+abs(offset):end-abs(offset), :, :),2);
    dif = d - di;
    dataOut = dataOut(:, 1+dif/2:end-dif/2, :, :);
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
