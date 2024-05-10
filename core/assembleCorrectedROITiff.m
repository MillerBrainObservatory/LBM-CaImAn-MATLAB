function [metadata] = assembleCorrectedROITiff(filename, metadata, nvargs) 
    arguments
        filename
        metadata (1,1) struct % Metadata values
        nvargs.dataset (1,1) string = "/Y"
        nvargs.group_path (1,1) string = "/data"
        nvargs.fileMode (1,1) string = "separate"
        nvargs.chunksize (1,:) = []
        nvargs.compression (1,1) double = 0
        nvargs.overwrite (1,1) logical = 1
    end

    [currpath, ~, ~] = fileparts(fullfile(mfilename('fullpath'))); % path to this script
    addpath(genpath(fullfile(currpath, '../packages/ScanImage_Utilities/ScanImage/')));
    addpath(genpath("utils"));

    hTif = scanimage.util.ScanImageTiffReader(filename);
    Aout = hTif.data();
    Aout = most.memfunctions.inPlaceTranspose(Aout); % the ScanImageTiffReader reads data in row major order

    % deinterleave zT
    Aout = reshape(Aout,[size(Aout,1) size(Aout,2) metadata.num_planes, metadata.num_frames_file]);
    
    raw_roi_width = metadata.num_pixel_xy(1);
    raw_roi_height = metadata.num_pixel_xy(2);

    trim_roi_width_start = 6;
    trim_roi_width_end = raw_roi_width - 6;

    new_roi_width_range = trim_roi_width_start:trim_roi_width_end;
    new_roi_width = size(new_roi_width_range, 2);

    trim_roi_height_start = round(raw_roi_height*0.03);
    trim_roi_height_end = raw_roi_height;

    new_roi_height_range = trim_roi_height_start:trim_roi_height_end; % controls the width on each side of the concatenated strips
    
    full_image_height = raw_roi_height - (trim_roi_height_start-1);
    full_image_width = new_roi_width*metadata.num_rois;

    for plane_idx = 1:metadata.num_planes
        frameTemp = zeros(full_image_height, full_image_width, metadata.num_frames_file, 'uint16');
        cnt=1;
        for roi_idx = 1:metadata.num_rois
            if cnt == 1 
                % The first one will be at the very top
                offset_y = 0;
                offset_x = 0;
            else
                % For the rest of the rois, there will be a recurring numLinesBetweenScanfields spacing
                offset_y = offset_y + raw_roi_height + metadata.num_lines_between_scanfields; 
                offset_x = offset_x + new_roi_width;
            end
            for frame_idx = 1:metadata.num_frames_file
                frameTemp(:, offset_x+new_roi_width_range, frame_idx) = Aout(offset_y+new_roi_height_range, new_roi_width_range, plane_idx, frame_idx);
            end
            cnt=cnt+1;
        end
        metadata.corr = returnScanOffset(frameTemp, 1);
        % frameTemp = fixScanPhase(frameTemp, corr, 1);

        filesavepath = sprintf("%s.h5", metadata.base_filename);
        datasavepath = sprintf("%s/plane_%d", nvargs.group_path, plane_idx);
        finalPath = fullfile(metadata.savepath, filesavepath);
        
        writeDataToH5(frameTemp, metadata, finalPath, datasavepath, nvargs);
    end
end

function dataOut = fixScanPhase(dataIn,offset,dim)
    % Find the lateral shift that maximizes the correlation between
    % alternating lines for the resonant galvo. Correct for phase-offsets
    % occur between each successive line.

    [sy,sx,sc,sz] = size(dataIn);
    dataOut = zeros(sy,sx,sc,sz, 'uint16');

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

function correction = returnScanOffset(Iin,dim)

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

            buffers = zeros(size(Iv1,1),n,  'uint16');

            Iv1 = cat(2,buffers,Iv1,buffers);
            Iv2 = cat(2,buffers,Iv2,buffers);

            Iv1 = reshape(Iv1',[],1);
            Iv2 = reshape(Iv2',[],1);

        case 2
            Iv1 = Iin(:,1:2:end);
            Iv2 = Iin(:,2:2:end);

            Iv1 = Iv1(:,1:min([size(Iv1,2) size(Iv2,2)]));
            Iv2 = Iv2(:,1:min([size(Iv1,2) size(Iv2,2)]),:);

            buffers = zeros(n,size(Iv1,2), 'uint16');

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
