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
%     '/extraction. Must contain a leading slash.
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

p = inputParser;
addRequired(p, 'data_path', @ischar);
addOptional(p, 'save_path', data_path, @ischar);
addParameter(p, 'dataset_name', "/extraction", @(x) (ischar(x) || isstring(x)) && isValidGroupPath(x));
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

if isempty(save_path)
    save_path = data_path;
end

[currpath, ~, ~] = fileparts(fullfile(mfilename('fullpath')));
addpath(genpath(fullfile(currpath, '../packages/ScanImage_Utilities/ScanImage/')));
addpath(genpath("utils"));

data_path = fullfile(data_path);
if ~isfolder(data_path)
    error("Filepath %s does not exist", data_path);
end

if ~isfolder(save_path)
    fprintf('Given savepath %s does not exist. Creating this directory...\n', save_path);
    mkdir(save_path);
end

if debug_flag == 1
    dir([data_path, '*.tif']);
    return;
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

files = dir(fullfile(data_path, '*.tif'));
if isempty(files)
    error('No suitable tiff files found in: \n  %s', data_path);
end

fprintf("Files found in data path:\n");
for i = 1:length(files)
    fprintf('%d: %s\n', i, files(i).name);
end

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
num_frames_total = metadata.num_frames_total;

h5_fullfile = fullfile(save_path, sprintf('%s.h5', metadata.raw_filename));
metadata.h5_fullfile = h5_fullfile; % store the location of our h5 file
metadata.dataset_name = dataset_name;

if isfile(h5_fullfile)
    if overwrite
        fprintf("Deleting file: %s\n", h5_fullfile);
        delete(h5_fullfile);
    else
        fprintf("Not Implemented Error:\nSave_file %s already exists\nUser set overwrite = 0.\nReturning without extracting data.\nTo extract this dataset, change the save_path, partial overwrites are not implemented.", h5_fullfile);
        return
    end
end

try
    for i = 1:length(files)
        tfile = tic;
        fprintf(fid, 'Processing %d: %s\n', i, files(i).name);

        hTif = scanimage.util.ScanImageTiffReader(fullfile(data_path, files(i).name));
        Aout = hTif.data();

        % high_res dataset, metadata.num_frames_file gives 1750, should
        % give 1730. Get frames from the actual dataset instead.
        num_frames_file = size(Aout, 3) / num_planes;
        if num_frames_file ~= metadata.num_frames_file
            warning("Frames inconsistent: metadata frames per file: %d\nCalculated from Aout: %d", metadata.num_frames_file, num_frames_file)
        end
        Aout = most.memfunctions.inPlaceTranspose(Aout);
        Aout = reshape(Aout, [size(Aout, 1), size(Aout, 2), num_planes, num_frames_file]);

        for plane_idx = 1:num_planes
            tplane = tic;
            dataset_path = sprintf('%s/plane_%d', dataset_name, plane_idx);

            frameTemp = zeros(trimmed_y, trimmed_x * metadata.num_strips, num_frames_file, 'like', Aout);
            cnt = 1;
            offset_y = 0;
            offset_x = 0;

            for roi_idx = 1:metadata.num_strips
                if cnt > 1
                    offset_y = offset_y + raw_y + metadata.num_lines_between_scanfields;
                    offset_x = offset_x + trimmed_x;
                end
                for frame_idx = 1:num_frames_total
                    frameTemp(:, (offset_x + 1):(offset_x + trimmed_x), frame_idx) = ...
                        Aout((offset_y + t_top + 1):(offset_y + raw_y - t_bottom), ...
                        (t_left + 1):(raw_x - t_right), plane_idx, frame_idx);
                end
                cnt = cnt + 1;
            end
            write_chunk_h5(h5_fullfile, frameTemp, size(frameTemp,3), dataset_path);
        end
        if i == 1
            metadata.new_imagesize = size(frameTemp);
            writeMetadataToAttribute(metadata, h5_fullfile, dataset_name);
        end
        fprintf(fid, "File %d of %d processed: %.2f seconds\n", i, length(files), toc(tplane));
    end
    fprintf(fid, "Processing complete. Time: %.2f seconds\n", i, length(files), toc(tfile));
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
