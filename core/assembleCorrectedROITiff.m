function [imageData,metadata] = assembleCorrectedROITiff(varargin) 
    if nargin == 1
        filename = varargin{1};
        if ~isfile(filename)
            [f, p] = uigetfile({'*.tif;*.tiff'},'Select Image File');
            if f == 0
                most.idioms.warn('Invalid arguments'); 
                return;
            end
            filename = fullfile(p,f); 
        end
        % tic
        % [header, aout] = scanimage.util.opentif(filename);
        % toc
        [roiData, roiGroup, header, ~] = scanimage.util.getMroiDataFromTiff(filename);
    else
        disp('No filename provided');
	    return;
    end

    metadata = get_metadata(filename);
    val = round(metadata.num_pixel_xy(2)*0.03);

    imageData = zeros(metadata.img_size_y, metadata.img_size_x, metadata.num_planes, metadata.num_frames, 'int16');
    for plane = 1:metadata.num_planes
        frameTemp = zeros(metadata.img_size_y, metadata.img_size_x, metadata.num_frames, 'int16');
        for roi_idx = 1:metadata.num_rois
            stripTemp = cell2mat(permute(cellfun(@(x) x{1}, roiData{1, roi_idx}.imageData{1, plane}, 'UniformOutput', false), [1, 3, 2]));
            corr = returnScanOffset2(stripTemp,1); % find offset correction
            stripTemp = fixScanPhase(stripTemp,corr,1); % fix scan phase
            stripTemp = stripTemp(val:end,metadata.strip_width_slice,:,:);
            frameTemp(:, (roi_idx-1)*length(metadata.strip_width_slice)+1:roi_idx*length(metadata.strip_width_slice), :) = stripTemp;
        end
        % Add to preallocated array
        % ..or, save straight to H5
        imageData(:, :, plane, :) = frameTemp;
    end
end

function dataOut = fixScanPhase(dataIn,offset,dim)
    % Find the lateral shift that maximizes the correlation between
    % alternating lines for the resonant galvo. Correct for phase-offsets
    % occur between each successive line.

    [sy,sx,sc,sz] = size(dataIn);
    dataOut = zeros(sy,sx,sc,sz);

    if dim == 1 % time series
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

    elseif dim == 2 % volume

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

            buffers = zeros(size(Iv1,1),n);

            Iv1 = cat(2,buffers,Iv1,buffers);
            Iv2 = cat(2,buffers,Iv2,buffers);

            Iv1 = reshape(Iv1',[],1);
            Iv2 = reshape(Iv2',[],1);

        case 2
            Iv1 = Iin(:,1:2:end);
            Iv2 = Iin(:,2:2:end);

            Iv1 = Iv1(:,1:min([size(Iv1,2) size(Iv2,2)]));
            Iv2 = Iv2(:,1:min([size(Iv1,2) size(Iv2,2)]),:);

            buffers = zeros(n,size(Iv1,2));

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
