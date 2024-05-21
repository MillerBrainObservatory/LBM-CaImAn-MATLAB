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
%     not exist. Defaults to the filePath if not provided.
% debug_flag : double, logical, optional
%     If set to 1, the function displays the files in the command window and does
%     not continue processing. Defaults to 0.
% fix_scan_phase : logical, optional
%     Whether to correct for bi-directional scan artifacts. (default is true).
% overwrite : logical, optional
%     Whether to overwrite existing files (default is 1).
% group_path : string, optional
%     Group path within the file (default is "/raw").
% chunk_size : array, optional
%     Chunk size for the file.
% compression : double, optional
%     Compression level for the file (default is 0).

%
% Notes
% -----
% The function adds necessary paths for ScanImage utilities and processes each .tif
% file found in the specified directory. It checks if the directory exists, handles
% multiple or single file scenarios, and can optionally report the directory's contents
% based on the diagnosticFlag.
%
% Each file processed is logged, assembled into a 4D volume, and saved in a specified
% directory as a .mat file with accompanying metadata. The function also manages errors
% by cleaning up and providing detailed error messages if something goes wrong during
% processing.
%
% Examples
% --------
% convertScanImageTiffToVolume('C:/data/session1/', 'C:/processed/', 0);
% convertScanImageTiffToVolume('C:/data/session1/', 'C:/processed/', 1); % Diagnostic mode
%
% See also FILEPARTS, ADDPATH, GENPATH, ISFOLDER, DIR, FULLFILE, ERROR, REGEXP, SAVEFAST
%
% .. _ScanImage: https://www.mbfbioscience.com/products/scanimage/

    p = inputParser;
    addRequired(p, 'data_path', @ischar);
    addOptional(p, 'save_path', data_path, @ischar);
    addOptional(p, 'debug_flag', 0, @(x) isnumeric(x) || islogical(x));
    addParameter(p, 'fix_scan_phase', 1, @(x) isnumeric(x) || islogical(x));
    addParameter(p, 'overwrite', 1, @(x) isnumeric(x) || islogical(x));
    addParameter(p, 'trim_pixels', [0 0 0 0], @isnumeric);
    addParameter(p, 'group_path', "/raw", @isstring);
    addParameter(p, 'chunk_size', [], @isnumeric);
    addParameter(p, 'compression', 0, @isnumeric);
    parse(p, data_path, save_path, varargin{:});

    data_path = p.Results.data_path;
    save_path = p.Results.save_path;
    debug_flag = p.Results.debug_flag;
    fix_scan_phase = p.Results.fix_scan_phase;
    overwrite = p.Results.overwrite;
    trim_pixels = p.Results.trim_pixels;
    group_path = p.Results.group_path;
    chunk_size = p.Results.chunk_size;
    compression = p.Results.compression;

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

    try
        clck = clock;
        logFileName = sprintf('extraction_log_%d_%02d_%02d_%02d_%02d.txt', clck(1), clck(2), clck(3), clck(4), clck(5));
        logFullPath = fullfile(data_path, logFileName);
        fid = fopen(logFullPath, 'a');
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
        metadata = get_metadata(firstFileFullPath);

        [t_left, t_right, t_top, t_bottom] = deal(trim_pixels(1), trim_pixels(2), trim_pixels(3), trim_pixels(4));
        raw_x = metadata.num_pixel_xy(1);
        raw_y = metadata.num_pixel_xy(2);
        trimmed_x = raw_x - t_left - t_right;
        trimmed_y = raw_y - t_top - t_bottom;
        num_planes = metadata.num_planes;
        num_frames_file = metadata.num_frames_file;

        h5_filename = fullfile(save_path, sprintf('%s.h5', metadata.raw_filename));
        if overwrite && isfile(h5_filename)
            fprintf("Deleting file: %s\n", h5_filename);
            delete(h5_filename);
        end

        for i = 1:length(files)
            fprintf(fid, '%d: %s\n', i, files(i).name);

            % Read and process the TIFF file
            hTif = scanimage.util.ScanImageTiffReader(fullfile(data_path, files(i).name));
            Aout = hTif.data();
            Aout = most.memfunctions.inPlaceTranspose(Aout);
            Aout = reshape(Aout, [size(Aout, 1), size(Aout, 2), num_planes, num_frames_file]);

            for plane_idx = 1:num_planes

                dataset_path = sprintf('%s/plane_%d', group_path, plane_idx);

                if i == 1  % Only create the dataset once per plane
                    h5create(h5_filename, dataset_path, [trimmed_y, trimmed_x * metadata.num_strips, Inf], 'Datatype', metadata.sample_format, ...
                        'ChunkSize', [trimmed_y, trimmed_x * metadata.num_strips, 1], 'Deflate', compression);
                end

                frameTemp = zeros(trimmed_y, trimmed_x * metadata.num_strips, metadata.num_frames_file, 'like', Aout);
                cnt = 1;
                offset_y = 0;
                offset_x = 0;

                tic;
                for roi_idx = 1:metadata.num_strips
                    if cnt > 1
                        offset_y = offset_y + raw_y + metadata.num_lines_between_scanfields;
                        offset_x = offset_x + trimmed_x;
                    end
                    for frame_idx = 1:num_frames_file
                        frameTemp(:, (offset_x + 1):(offset_x + trimmed_x), frame_idx) = Aout((offset_y + t_top + 1):(offset_y + raw_y - t_bottom), (t_left + 1):(raw_x - t_right), plane_idx, frame_idx);
                    end
                    cnt = cnt + 1;
                end
                h5write(h5_filename, dataset_path, frameTemp, [1, 1, (i-1) * num_frames_file + 1], [trimmed_y, trimmed_x * metadata.num_strips, num_frames_file]);
                toc
            end
        end
        fields = string(fieldnames(metadata));
        for f = fields'
            h5writeatt(h5_filename, '/raw', f, metadata.(f));
        end

        tt = toc / 3600;
        disp(['Volume loaded and processed. Elapsed time: ' num2str(tt) ' hours. Saving volume to temp...']);
    catch ME
        if exist('fid','var')
            fprintf('closing logfile: %s\n', logFullPath);
            fclose(fid);
        end
        if exist('logFullPath','var') && isfile(logFullPath)
            fprintf('deleting logfile: %s\n', logFullPath);
            delete(logFullPath);
        end
        rethrow(ME);
    end
end

function closeLogFile(fid)
    fclose(fid);
end

function cleanupLogFile(fid, logFullPath)
    fclose(fid);
    if exist('logFullPath', 'var') && isfile(logFullPath)
        fprintf('deleting logfile: %s\n', logFullPath);
        delete(logFullPath);
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
