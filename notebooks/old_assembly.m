
% filename = 'C:\Users\RBO\Documents\data\high_res\raw\MH70_0p6mm_FOV_50_550um_depth_som_stim_199mW_3min_M1_00001_00001.tif';
% %% Load in data and determine size of dimensions
% [roiData, roiGroup, header, ~] = scanimage.util.getMroiDataFromTiff(filename); % load in data throuhg scanimage utility
% numROIs = numel(roiData); % number of ROIs (ASSUMES THEY ARE ORDERED LEFT TO RIGHT)
% totalFrame = length(roiData{1}.imageData{1}); % total number of frames in data set
% totalChannel = length(roiData{1}.imageData); % number of channels
% frameRate = header.SI.hRoiManager.scanVolumeRate;
% sizeXY = roiGroup.rois(1,1).scanfields.sizeXY;
% FOV = 157.5.*sizeXY;
% numPX = roiGroup.rois(1,1).scanfields.pixelResolutionXY;
% pixelResolution = mean(FOV./numPX);

%% Assemble frames
imageData = [];
for channel = 1:totalChannel
    disp(['Assembling channel ' num2str(channel) ' of ' num2str(totalChannel) '...'])
    frameTemp = [];
    for strip = 1:numROIs

        % Generate the time series of each ROI in the data
        stripTemp = [];
        for frame = 1:totalFrame
            stripTemp = cat(4,stripTemp,single(roiData{1,strip}.imageData{1,channel}{1,frame}{1,1}{1}));
        end
        corr = returnScanOffset2(stripTemp,1); % find offset correction
        stripTemp = fixScanPhase(stripTemp,corr,1); % fix scan phase
        val = round(size(stripTemp,1)*0.03); % trim excess
        stripTemp = stripTemp(val:end,7:138,:,:);

        frameTemp = cat(2,frameTemp,stripTemp); % create each frame

    end
    imageData = single(cat(3,imageData,frameTemp));

end

function correction = returnScanOffset2(Iin,dim)

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

% figure; plot(lag,r)

[~,ind] = max(r);
correction = lag(ind);
end

function dataOut = fixScanPhase(dataIn,offset,dim)

[sy,sx,sc,sz] = size(dataIn);
dataOut = zeros(sy,sx,sc,sz);

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