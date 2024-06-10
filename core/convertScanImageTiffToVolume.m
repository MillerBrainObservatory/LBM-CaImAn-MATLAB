function convertScanImageTiffToVolume(data_path, save_path, varargin)
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
%     [0 0 0 0].
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
addpath(genpath(fullfile(currpath, '../packages/ScanImage_Utilities/ScanImage/')));
addpath(genpath("utils"));

p = inputParser;
addRequired(p, 'data_path', @ischar);
addOptional(p, 'save_path', data_path, @ischar);
addParameter(p, 'dataset_name', "/Y", @(x) (ischar(x) || isstring(x)) && isValidGroupPath(x));
addOptional(p, 'debug_flag', 0, @(x) isnumeric(x) || islogical(x));
addParameter(p, 'overwrite', 1, @(x) isnumeric(x) || islogical(x));
addParameter(p, 'fix_scan_phase', 1, @(x) isnumeric(x) || islogical(x));
addParameter(p, 'trim_pixels', [0 0 0 0], @isnumeric);
parse(p, data_path, save_path, varargin{:});

data_path = p.Results.data_path;
save_path = p.Results.save_path;
dataset_name = p.Results.dataset_name;
debug_flag = p.Results.debug_flag;
overwrite = p.Results.overwrite;
fix_scan_phase = p.Results.fix_scan_phase;
trim_pixels = p.Results.trim_pixels;

if ~isfolder(data_path); error("Data path:\n %s\n ..does not exist", data_path); end
if debug_flag == 1; dir([data_path, '*.tif']); return; end

if isempty(save_path)
    warning("No save_path given. Saving data in data_path: %s\n", data_path);
    save_path = data_path;
end

fig_save_path = fullfile(save_path, "figures");
if ~isfolder(fig_save_path); mkdir(fig_save_path); end

files = dir(fullfile(data_path, '*.tif*'));
if isempty(files)
    error('No suitable tiff files found in: \n  %s', data_path);
end

fprintf("Files found in data path:\n");
for i = 1:length(files)
    fprintf('%d: %s\n', i, files(i).name);
end

log_file_name = sprintf("%s_extraction", datestr(datetime("now"), 'dd_mmm_yyyy_HH_MM_SS'));
log_full_path = fullfile(save_path, log_file_name);
fid = fopen(log_full_path, 'w');
if fid == -1
    error('Cannot create or open log file: %s', log_full_path);
else
    fprintf('Log file created: %s\n', log_full_path);
end
closeCleanupObj = onCleanup(@() fclose(fid));

firstFileFullPath = fullfile(files(1).folder, files(1).name);

% We add some values to the metadata to attach to H5 attributes and
% make file access / parameter access easier down the pipeline.
metadata = get_metadata(firstFileFullPath);
metadata.extraction_params = p.Results;

[t_left, t_right, t_top, t_bottom] = deal(trim_pixels(1), trim_pixels(2), trim_pixels(3), trim_pixels(4));
metadata.trim_pixels = [t_left, t_right, t_top, t_bottom]; % store the number of pixels to trim
raw_x = metadata.num_pixel_xy(1);
raw_y = metadata.num_pixel_xy(2);

trimmed_x = raw_x - t_left - t_right;
trimmed_y = raw_y - t_top - t_bottom;

num_planes = metadata.num_planes;
num_rois = metadata.num_rois;
metadata.dataset_name = dataset_name;

offsets_plane = zeros(num_planes, 1);
offsets_roi = zeros(num_planes, num_rois);

try
    fprintf(fid, '%s : Processing %d file(s) with %d planes.\n', datestr(datetime('now'), 'yyyy_mm_dd-HH_MM_SS'), length(files), num_planes);
    fprintf("Metadata:\n\n")
    disp(metadata)
    for i = 1:length(files)
        tfile = tic;
        full_filename = fullfile(data_path, files(i).name);
        try
            hTif = scanimage.util.ScanImageTiffReader(full_filename);
            Aout = hTif.data();
            Aout = most.memfunctions.inPlaceTranspose(Aout);
            num_frames_file = size(Aout, 3) / num_planes;

            Aout = reshape(Aout, [size(Aout, 1), size(Aout, 2), num_planes, num_frames_file]);
        catch ME
            [~, Aout] = scanimage_backup.util.opentif(full_filename);
        end

        z_timeseries = zeros(trimmed_y, trimmed_x * metadata.num_rois, num_frames_file, 'like', Aout);
        for plane_idx = 1:num_planes
            tplane = tic;
            p_str = sprintf("plane_%d", plane_idx);
            plane_fullfile = sprintf("%s/extracted_%s.h5", save_path, p_str);

            cnt = 1;
            offset_y = 0;
            offset_x = 0;
            tic;

            scan_offset = returnScanOffset(Aout(:,:,plane_idx,:), 1, 'int16');
            offsets_plane(plane_idx) = scan_offset;
            for roi_idx = 1:metadata.num_rois
                if cnt > 1
                    offset_y = offset_y + raw_y + metadata.num_lines_between_scanfields;
                    offset_x = offset_x + trimmed_x;
                end
                % use the untrimmed roi in the phase offset correction
                raw_yslice = (offset_y + 1):(offset_y + raw_y);
                
                trimmed_xslice = t_left+1:t_right+trimmed_x;
                trimmed_yslice = t_top+1:t_bottom+trimmed_y;

                roi_arr = fixScanPhase(Aout( ...
                    raw_yslice, ...
                    1:raw_x, ...
                    plane_idx, ...
                    : ...
                    ), offsets_roi(plane_idx,roi_idx), 1, 'int16');

                roi_arr = squeeze(roi_arr(trimmed_yslice, trimmed_xslice, :)); %pre-trim this roi
                z_timeseries( ...
                    1: size(roi_arr,1), ...
                    (offset_x + 1):(offset_x + size(roi_arr,2)), ...
                    : ...
                    ) = roi_arr;
                cnt = cnt + 1;
            end
            % 
            % pixel_resolution = metadata.pixel_resolution;
            % scale_fact = 10; % Length of the scale bar in microns
            % scale_length_pixels = scale_fact / pixel_resolution;
            % 
            % img_frame = z_timeseries(:,:,2);
            % [yind, xind] = get_central_indices(img_frame, 30); % 30 pixels around the center of the brightest part of an image frame
            % 
            % f = figure('Color', 'black');
            % sgtitle(sprintf('Scan-Correction Validation: Frame 2, Plane %d', plane_idx), 'FontSize', 16, 'FontWeight', 'bold', 'Color', 'w');
            % tiledlayout(1, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
            % 
            % % Post-correction image
            % nexttile;
            % imagesc(z_timeseries(yind, xind, 2));
            % axis image; axis tight; axis off; colormap('gray');
            % sgtitle(sprintf('Plane %d @ %.2f Hz | %.2f µm/px \nFOV: %.0fmm x %.0fmm', plane_idx, metadata.frame_rate, metadata.pixel_resolution, metadata.fov(1), metadata.fov(2)), 'FontSize', 14, 'FontWeight', 'bold', 'Color', 'k');
            % hold on;
            % 
            % % Scale bar coordinates relative to the cropped image
            % scale_bar_x = [size(xind, 2) - scale_length_pixels - 3, size(xind, 2) - 3]; % 10 pixels padding from the right
            % scale_bar_y = [size(yind, 2) - 3, size(yind, 2) - 3]; % 20 pixels padding from the bottom
            % line(scale_bar_x, scale_bar_y, 'Color', 'r', 'LineWidth', 5);
            % text(mean(scale_bar_x), scale_bar_y(1), sprintf('%d µm', scale_fact), 'Color', 'r', 'FontSize', 12, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
            % hold off;
            % 
            % saveas(f, fullfile(fig_save_path, sprintf('scan_correction_validation_plane_%d_offset_%d.png', plane_idx, abs(scan_offset))));
            % close(f);

            if isfile(plane_fullfile)
                if overwrite
                    fprintf(fid, "%s : Deleting %s\n", datestr(datetime('now'), 'yyyy_mm_dd:HH:MM:SS') ,plane_fullfile);
                    delete(plane_fullfile);
                else
                    fprintf("Not Implemented Error:\nSave_file %s already exists\nUser set overwrite = 0.\nReturning without extracting data.\nTo extract this dataset, change the save_path, partial overwrites are not implemented.", plane_fullfile);
                    return
                end
            end

            metadata.scan_offset = offsets_plane(plane_idx);

            write_chunk_h5(plane_fullfile, z_timeseries, size(z_timeseries,3), '/Y');
            write_metadata_h5(metadata, plane_fullfile, '/Y');
            fprintf(fid, "%s : Plane %d processed in %.2f seconds\n", datestr(datetime('now'), 'yyyy_mm_dd:HH:MM:SS'), plane_idx, toc(tplane));
        end
    end
    fprintf(fid, "%s : Processing complete. Time: %.3f minutes\n", datestr(datetime('now'), 'yyyy_mm_dd:HH:MM:SS'), toc(tfile)/60);
catch ME
    if exist('log_full_path', 'var') && isfile(log_full_path)
        fprintf('Deleting errored logfile: %s\n', log_full_path);
        for k = 1:length(ME.stack)
            fprintf('Error in %s (line %d)\n', ME.stack(k).file, ME.stack(k).line);
        end
        delete(log_full_path);
    end
    rethrow(ME);
end
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
dataOut = dataOut(:,abs(offset) + 1:end - abs(offset),:);
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
