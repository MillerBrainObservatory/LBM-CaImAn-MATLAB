function [session_images, session_labels] = convertScanImageTiffToVolume(data_path, save_path, varargin)
% convertScanImageTiffToVolume Convert ScanImage .tif files into a 4D volume.
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
% dataset_name : string, optional
%     Name of the group (h5 dataset) to save the extracted data. Default is
%     '/Y'. Must contain a leading slash.
% debug_flag : double, logical, optional
%     If set to 1, the function displays the files in the command window and does
%     not continue processing. Defaults to 0.
% overwrite : logical, optional
%     Whether to overwrite existing files (default is 1).
% fix_scan_phase : logical, optional
%     Whether to correct for bi-directional scan artifacts. (default is true).
% trim_pixels : double, optional
%     Pixels to trim from left, right,top, bottom of each scanfield before
%     horizontally concatenating the scanfields within an image. Default is
%     [6 6 10 0].
%
% Notes
% -----
% The function adds necessary paths for ScanImage utilities and processes each .tif
% file found in the specified directory. It checks if the directory exists, handles
% multiple or single file scenarios, and can optionally report the directory's contents
% based on the debug_flag.
%
% Each file processed is logged, assembled into a 4D volume, and saved in a specified
% directory as a .mat file with accompanying metadata. The function also manages errors
% by cleaning up and providing detailed error messages if something goes wrong during
% processing.
%
% See also FILEPARTS, ADDPATH, GENPATH, ISFOLDER, DIR, FULLFILE, ERROR, REGEXP, SAVEFAST
%
% .. _ScanImage: https://www.mbfbioscience.com/products/scanimage/

[currpath, ~, ~] = fileparts(fullfile(mfilename('fullpath')));
addpath(genpath(fullfile(currpath, '../packages/ScanImage/')));
addpath(genpath("utils")); addpath(genpath("io")); addpath(genpath("internal"));

import ScanImageTiffReader.*

p = inputParser;

addRequired(p, 'data_path', @(x) ischar(x) || isstring(x));
addOptional(p, 'save_path', data_path, @(x) ischar(x) || isstring(x));
addParameter(p, 'dataset_name', "/Y", @(x) (ischar(x) || isstring(x)) && is_valid_group(x));
addOptional(p, 'debug_flag', 0, @(x) isnumeric(x) || islogical(x));
addParameter(p, 'overwrite', 1, @(x) isnumeric(x) || islogical(x));
addParameter(p, 'fix_scan_phase', 1, @(x) isnumeric(x) || islogical(x));
addParameter(p, 'trim_pixels', [6 6 10 0], @isnumeric);
parse(p, data_path, save_path, varargin{:});

data_path = fullfile(p.Results.data_path);
save_path = fullfile(p.Results.save_path);
dataset_name = p.Results.dataset_name;
debug_flag = p.Results.debug_flag;
overwrite = p.Results.overwrite;
fix_scan_phase = p.Results.fix_scan_phase;
trim_pixels = p.Results.trim_pixels;

if fix_scan_phase == 0; warning("Setting fix_scan_phase = 0 not yet implemented."); end
if ~isfolder(data_path); error("Data path:\n %s\n ..does not exist", fullfile(data_path)); end
if debug_flag == 1; dir([data_path, '*.tif']); return; end

if isempty(save_path)
    warning("No save_path given. Saving data in data_path: %s\n", fullfile(data_path));
    save_path = data_path;
end

fig_save_path = fullfile(save_path, "figures");
if ~isfolder(fig_save_path); mkdir(fig_save_path); end

files = dir(fullfile(data_path, '*.tif*'));
if isempty(files); error('No suitable tiff files found in: \n  %s', data_path); end
num_files=length(files);

log_file_name = sprintf("%s_extraction.log", datestr(datetime("now"), 'dd_mmm_yyyy_HH_MM_SS'));
log_full_path = fullfile(save_path, log_file_name);
fid = fopen(log_full_path, 'w');
if fid == -1
    error('Cannot create or open log file: %s', log_full_path);
else
    fprintf('Log file created: %s\n', log_full_path);
end

firstFileFullPath = fullfile(files(1).folder, files(1).name);

% We add some values to the metadata to attach to H5 attributes and
% make file access / parameter access easier down the pipeline.
metadata = get_metadata(firstFileFullPath);
metadata.extraction_params = p.Results();

[t_left, t_right, t_top, t_bottom] = deal(trim_pixels(1), trim_pixels(2), trim_pixels(3), trim_pixels(4));
metadata.trim_pixels = [t_left, t_right, t_top, t_bottom]; % store the number of pixels to trim
raw_x = metadata.num_pixel_xy(1);
raw_x = min(raw_x, metadata.tiff_width);
raw_y = metadata.num_pixel_xy(2);

num_planes = metadata.num_planes;
num_rois = metadata.num_rois;
num_frames = metadata.num_frames;
data_type = metadata.sample_format;

metadata.dataset_name = dataset_name;
metadata.num_files = num_files;

offsets_plane = zeros(num_planes, 1);
offsets_roi = zeros(num_planes, num_rois);
try

    log_struct(fid,metadata,'metadata',log_full_path,);

    fprintf("Metadata:\n\n")
    disp(metadata)

    log_message(fid, "Aggregating data from %d file(s) with %d plane(s).",num_files, num_planes);
    % We dont know how many frames there are in each files are yet
    % We only know how many files there are
    offset_file = 0;
    Aout = zeros(metadata.tiff_length, metadata.tiff_width, num_planes, num_frames, data_type);
    for file_idx = 1:num_files
        if file_idx > 1; offset_file = offset_file + num_frames; end

        full_filename = fullfile(data_path, files(file_idx).name);

        log_message(fid, 'Loading data for file %d of %d...', file_idx, num_files);

        try
            hTif = ScanImageTiffReader(full_filename);
            hTif = hTif.data();
            % hTif = most.memfunctions.inPlaceTranspose(hTif);
            hTif = permute(hTif, [2 1 3 4]);
            size_y = size(hTif);
            if file_idx == 1; frames_file = size_y(end)/num_planes; end

            file_slice = (offset_file + 1):(offset_file + frames_file);
            Aout( ...
                :, ...
                :, ...
                :, ...
                file_slice ...
                ) = reshape(hTif, [size_y(1), size_y(2), num_planes,num_frames]);
        catch ME
            rethrow(ME);
        end
    end

    tfile = tic;
    
    log_message(fid, "Data loaded for file %d/%d in %.2f seconds...", file_idx, num_files, toc(tfile))

    session_images = {};
    session_labels = {};
    
    z_timeseries = zeros(raw_y, raw_x * metadata.num_rois, num_frames, 'like', Aout);
    for plane_idx = 1:num_planes
        tplane = tic;

        log_message(fid, 'Processing z-plane %d/%d...', plane_idx, num_planes);

        p_str = sprintf("plane_%d", plane_idx);
        plane_name_save = sprintf("%s/extracted_%s.h5", save_path, p_str);

        % /figures folder with /plane_n subdirectories
        plane_savepath = fullfile(fig_save_path, p_str);
        if ~isfolder(plane_savepath); mkdir(plane_savepath); end

        %% SCAN PHASE CORRECTION METHOD 1:
        % Our planar timeseries returned from Aout can be used
        % while it's still vertically tiled
        scan_offset = returnScanOffset(Aout(:,:,plane_idx,:), 1, 'int16');

        % We use the entire timeseries
        % [~] = fixScanPhase(Aout(:,:,plane_idx,:), scan_offset, 1, 'int16');
        % disp(toc);

        metadata.scan_offset = scan_offset;
        cnt = 1;
        offset_x = 0;
        raw_offset_y = 0;
        for roi_idx = 1:metadata.num_rois
            log_message(fid, "Processing ROI: %d/%d", roi_idx, num_rois);
            if cnt > 1
                raw_offset_y = raw_offset_y + raw_y + metadata.num_lines_between_scanfields;
            end

            % use the **untrimmed** roi in the phase offset correction
            raw_yslice = (raw_offset_y + 1):(raw_offset_y + raw_y);
            raw_timeseries = Aout(raw_yslice, 1:raw_x, plane_idx, :);

            %% SCAN PHASE CORRECTION METHOD 2:
            % Because the offsets could be different in each ROI depending
            % on the flourescence/contrast, so we can also evaluate get
            % an offset for each individual strip.
            offsets_roi(plane_idx, roi_idx) = returnScanOffset(Aout(raw_yslice,:,plane_idx,:), 1, 'int16');
            roi_arr = fixScanPhase(raw_timeseries, offsets_roi(plane_idx,roi_idx), 1, 'int16');

            % trimmed_xslice = (t_left+1:sx-t_right);
            trimmed_xslice = (t_left+1:raw_x-t_right);
            trimmed_yslice = (t_top+1:raw_y-t_bottom);

            % pre-trim this roi
            roi_arr = squeeze(roi_arr(trimmed_yslice, trimmed_xslice, :));
            if cnt > 1 % wait until the new array size is calculated
                offset_x = offset_x + size(roi_arr, 2);
            end

            z_timeseries( ...
                1: size(roi_arr,1), ...
                (offset_x + 1):(offset_x + size(roi_arr,2)), ...
                : ...
                ) = roi_arr;

            [yind, xind] = get_central_indices(raw_timeseries(:,:,2), 40);
            [yindr, xindr] = get_central_indices(roi_arr(:,:,2), 40);

            images = {raw_timeseries(yind,xind,2), roi_arr(yindr, xindr, 2)};
            zoomed_scale = calculate_scale(size(images{1},2),metadata.pixel_resolution);
            roi_scales = {zoomed_scale,zoomed_scale};
            labels = {'Pre-Corrected/Trimmed', 'Phase-Corrected/Trimmed'};

            roi_savename = fullfile(plane_savepath, sprintf('roi_%d.png', roi_idx));
            write_tiled_figure( ...
                images, ...
                metadata, ...
                'fig_title', sprintf('ROI %d', roi_idx), ...
                'titles', labels, ...
                'scales', roi_scales, ...
                'save_name', roi_savename ...
            );

            cnt = cnt + 1;
        end

        % remove padded 0's
        z_timeseries = z_timeseries( ...
            any(z_timeseries, [2, 3]), ...
            any(z_timeseries, [1, 3]), ...
            :);

        img_frame = z_timeseries(:,:,2);
        mean_img = mean(z_timeseries, 3);
        session_images{plane_idx} = mean_img;
        session_labels{plane_idx} = sprintf("Plane %d", plane_idx);

        [yind, xind] = get_central_indices(mean_img, 30); % 30 pixels around the center of the brightest part of an image frame
        images = {img_frame, mean_img, mean_img(yind, xind)};
        labels = {'Second Frame', 'Mean Image', 'Mean Image(Zoom)'};
        scale_full = calculate_scale(size(img_frame, 2), metadata.pixel_resolution);
        scale_roi = calculate_scale( size(img_frame(yind, xind),2), metadata.pixel_resolution);
        scales = {scale_full, scale_full, scale_roi};
        plane_save_path = fullfile(plane_savepath, sprintf('mean_frame_plane_%d.png', plane_idx));

        write_tiled_figure( ...
            images, ...
            metadata, ...
            'titles', labels, ...
            'scales', scales, ...
            'save_name', plane_save_path ...
        );

        if isfile(plane_name_save)
            if overwrite
                log_message(fid, "Deleting %s",plane_name_save);
                delete(plane_name_save);
            else
                log_message(fid, "Not Implemented Error:\nSave_file %s already exists\n" + ...
                    "User set overwrite = 0. Returning without extracting data.\n" + ...
                    "To extract this dataset, change the save_path, partial overwrites are not implemented.", plane_name_save);
                return
            end
        end

        metadata.scan_offset = offsets_plane(plane_idx);
        write_frames_to_h5(plane_name_save, z_timeseries, size(z_timeseries,3), dataset_name);
        h5create(plane_name_save,"/Ym",size(mean_img));
        h5write(plane_name_save, '/Ym', mean_img);
        write_metadata_h5(metadata, plane_name_save, '/');
        log_message(fid, "Plane %d processed in %.2f seconds",plane_idx, toc(tplane));

    end
    write_tiled_tight( ...
        session_images, ...
        'titles', session_labels, ...
        'save_name', fullfile(fig_save_path, "all_planes.png") ...
    );
catch ME
    if exist('log_full_path', 'var') && isfile(log_full_path)
        fprintf('Deleting errored logfile: %s', log_full_path);
        for k = 1:length(ME.stack)
            fprintf('Error in %s (line %d)\n', ME.stack(k).file, ME.stack(k).line);
        end
        delete(log_full_path);
    end
    rethrow(ME);
end

log_message(fid,"%s : Processing complete. Time: %.3f minutes.",toc(tfile)/60);
fclose('all');
end

function dataOut = fixScanPhase(dataIn,offset,dim, dtype)
% Find the lateral shift that maximizes the correlation between
% alternating lines for the resonant galvo. Correct for phase-offsets
% occur between each successive line.

[sy,sx,sc,sz] = size(dataIn);
dataOut = zeros(sy,sx,sc,sz, dtype);

if dim == 1
    if offset>0
        dataOut(1:2:sy,1:sx,:,:) = dataIn(1:2:sy,:,:,:);
        dataOut(2:2:sy,1+offset:(offset+sx),:) = dataIn(2:2:sy,:,:);

    elseif offset<0
        offset = abs(offset);
        dataOut(1:2:sy,1+offset:(offset+sx),:,:) = dataIn(1:2:sy,:,:,:);
        dataOut(2:2:sy,1:sx,:,:) = dataIn(2:2:sy,:,:,:);
    else
        dataOut(:,1+floor(offset/2):sx+floor(offset/2),:,:) = dataIn;
    end

elseif dim == 2

    if offset>0
        dataOut(1:sy,1:2:sx,:,:) = dataIn(:,1:2:sx,:,:);
        dataOut(1+offset:(offset+sy),2:2:sx,:) = dataIn(:,2:2:sx,:);

    elseif offset<0
        offset = abs(offset);
        dataOut(1+offset:(offset+sy),1:2:sx,:,:) = dataIn(:,1:2:sx,:,:);
        dataOut(1:sy,2:2:sx,:,:) = dataIn(:,2:2:sx,:,:);
    else
        dataOut(1+floor(offset/2):sy+floor(offset/2),:,:,:) = dataIn;
    end
end
% dataOut = dataOut(:, 1:sx-offset, :, :);
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
