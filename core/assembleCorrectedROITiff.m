function [metadata] = assembleCorrectedROITiff(filename, metadata, varargin)
% assembleCorrectedROITiff Assembles a corrected ROI TIFF file.
%
% Parameters
% ----------
% filename : string
%     The name of the TIFF file to be read.
% dataset : string, optional
%     Dataset path within the file (default is "/Y").
% group_path : string, optional
%     Group path within the file (default is "/data").
% fileMode : string, optional
%     Mode for the file handling (default is "separate").
% chunksize : array, optional
%     Chunk size for the file.
% compression : double, optional
%     Compression level for the file (default is 0).
% overwrite : logical, optional
%     Whether to overwrite existing files (default is true).
% fix_scan_phase : logical, optional
%     Whether to fix scan phase (default is true).
%
% Returns
% -------
% metadata : struct
%     Updated metadata after processing the TIFF file. This will be the
%     same metadata attached to the h5 attributes and can be used in
%     subsequent steps of the pipeline.
%
% Examples
% --------
% metadata = assembleCorrectedROITiff('file.tif', metadata);
%
% Notes
% -----
% This function requires the ScanImage utilities package.

p = inputParser;
addRequired(p, 'filename', @ischar);
addRequired(p, 'metadata', @isstruct);
addParameter(p, 'dataset', "/Y", @isstring);
addParameter(p, 'group_path', "/data", @isstring);
addParameter(p, 'fileMode', "separate", @isstring);
addParameter(p, 'chunksize', [], @isnumeric);
addParameter(p, 'compression', 0, @isnumeric);
addParameter(p, 'overwrite', true, @islogical);
addParameter(p, 'fix_scan_phase', true, @islogical);
parse(p, filename, metadata, varargin{:});
    
nvargs = p.Results;

% This may not be needed since it's called from another package
% function.
[currpath, ~, ~] = fileparts(fullfile(mfilename('fullpath'))); % path to this script
addpath(genpath(fullfile(currpath, '../packages/ScanImage_Utilities/ScanImage/')));
addpath(genpath("utils"));

%% Load data for entire file
hTif = scanimage.util.ScanImageTiffReader(filename);
Aout = hTif.data();
Aout = most.memfunctions.inPlaceTranspose(Aout); % the ScanImageTiffReader reads data in row major order

% de-interleave zplanes and timepoints
Aout = reshape(Aout,[size(Aout,1) size(Aout,2) metadata.num_planes, metadata.num_frames_file]);

%% Pre-compute some dimensions given the timmed pixel size
raw_roi_width = metadata.num_pixel_xy(1); % before trimming
raw_roi_height = metadata.num_pixel_xy(2);

trim_roi_width_start = 7;
trim_roi_width_end = 138;

new_roi_width_range = trim_roi_width_start:trim_roi_width_end;
new_roi_width = size(new_roi_width_range, 2);

trim_roi_height_start = round(raw_roi_height*0.03);
trim_roi_height_end = raw_roi_height;

new_roi_height_range = trim_roi_height_start:trim_roi_height_end; % controls the width on each side of the concatenated strips

if nvargs.fix_scan_phase
    % trimmed_height = trim_roi_height_end - (trim_roi_height_start - 1);
    % trimmed_width = new_roi_width * metadata.num_rois;
    arr_dtype = 'single';
    % trimmed_array = zeros(trimmed_width, trimmed_height, metadata.num_frames_file, arr_dtype);
else
    arr_dtype='uint16';
end
full_image_height = raw_roi_height - (trim_roi_height_start-1);
full_image_width = new_roi_width*metadata.num_rois;

for plane_idx = 1:metadata.num_planes
    frameTemp = zeros(full_image_height, full_image_width, metadata.num_frames_file, arr_dtype);
    cnt=1;
    for roi_idx = 1:metadata.num_rois
        if cnt == 1 
            % The first one will be at the very top
            % This could be the cause for the first frame containing 
            % irregular pixels on the top of the strip.
            offset_y = 0;
            offset_x = 0;
        else
            % For the rest of the rois, there will be a recurring numLinesBetweenScanfields spacing
            offset_y = offset_y + raw_roi_height + metadata.num_lines_between_scanfields; 
            offset_x = offset_x + new_roi_width;
        end
        for frame_idx = 1:metadata.num_frames_file
            frameTemp(:, offset_x+(1:length(new_roi_width_range)), frame_idx) = Aout(offset_y+new_roi_height_range, new_roi_width_range, plane_idx, frame_idx);
        end
        cnt=cnt+1;
    end

    % metadata.corr = returnScanOffset(frameTemp, 1, arr_dtype);
    % metadata.image_size = size(frameTemp);
    % if metadata.corr ~= 0 && nvargs.fix_scan_phase
    %     trimmed_array = fixScanPhase(frameTemp, ...
    %         metadata.corr, ...
    %         1, ...
    %         arr_dtype ...
    %     );
    % end

    filesavepath = sprintf("%s.h5", metadata.base_filename);
    datasavepath = sprintf("%s/plane_%d", nvargs.group_path, plane_idx);
    finalPath = fullfile(metadata.savepath, filesavepath);
    if ~isfile(filePath)
        fprintf("%s does not exist, Creating the h5 file... \n", filePath)
       h5create(filePath, datasetPath, size(data), 'Datatype', 'uint16', ...
            'ChunkSize', [size(data, 1), size(data, 2), 1], 'Deflate', nvargs.compression); 
        h5write(filePath, datasetPath, data);

    else
        h5create(filePath, datasetPath, size(data), 'Datatype', 'uint16', ...
            'ChunkSize', [size(data, 1), size(data, 2), 1], 'Deflate', nvargs.compression); 
        h5write(filePath, datasetPath, data);

        if nvargs.overwrite == 1
            fprintf('File: %s \n ...with dataset-path: %s already exists, but user input overwrite = 1, writing over the file...', filePath, datasetPath);
            delete(filePath);

            h5create(filePath, datasetPath, [size(data,1), size(data,2), Inf], 'Datatype', 'uint16', ...
            'ChunkSize', [size(data, 1), size(data, 2), 1], 'Deflate', nvargs.compression);
        
            h5write(filePath, datasetPath, data, [1, 1, startFrame], [size(data,1), size(data,2), size(data,3)]);

        else
            fprintf('File: %s \n ...with dataset-path: %s already exists, skipping this file...', filePath, datasetPath);
        end
    end
    fields = string(fieldnames(metadata));
    for f = fields'
        h5writeatt(filePath, datasetPath, f, metadata.(f));
    end
    writeDataToH5(frameTemp, metadata, finalPath, datasavepath, nvargs);
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
