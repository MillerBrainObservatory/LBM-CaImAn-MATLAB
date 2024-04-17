%% Load Data 

clc
addpath(genpath(fullfile("Pre_Processing_Executable/ScanImage_Utilities/SI2016bR1_2017-09-28-140040_defde478ed/")))
filename = 'C:\Users\RBO\Documents\MATLAB\benchmarks\high_resolution\MH70_0p6mm_FOV_50_550um_depth_som_stim_199mW_3min_M1_00001_00001.tif';
[roiData2, roiGroup2, header2, ~] = scanimage.util.getMroiDataFromTiff(filename); 

%% Load Data, again 

[header, aout] = scanimage.util.opentif(filename);

%% 
clc
clearvars -except aout filename
hTiff = Tiff(filename);
roiStr = hTiff.getTag('Artist'); % where scanimage decided to store image data
roiStr(roiStr == 0) = []; % remove null termination
mdata = most.json.loadjson(roiStr);
mdata = mdata.RoiGroups.imagingRoiGroup.rois;
num_rois = length(mdata);
mdata = mdata{:};
scanfields = mdata.scanfields;

center_xy = scanfields.centerXY;
size_xy = scanfields.sizeXY;
num_pixel_xy = scanfields.pixelResolutionXY;

clear mdata;

[header,~] = scanimage.util.private.getHeaderData(hTiff);
image_length = hTiff.getTag('ImageLength'); %% Really the only value we need
image_width = hTiff.getTag('ImageWidth'); 

num_frames = header.SI.hStackManager.framesPerSlice;
num_planes = length(header.SI.hChannels.channelSave);

assert(num_frames == size(aout, 4)); % sanity check
assert(num_planes == size(aout, 3)); % sanity check

lines_per_frame = header.SI.hRoiManager.linesPerFrame;
pixels_per_line = header .SI.hRoiManager.pixelsPerLine;
num_lines_between_scanfields = round(header.SI.hScan2D.flytoTimePerScanfield/header.SI.hRoiManager.linePeriod);

frame_rate = header.SI.hRoiManager.scanVolumeRate;
objective_resolution = header.SI.objectiveResolution;

fov = round(objective_resolution.*size_xy);
pixel_resolution = mean(fov./num_pixel_xy);

img_size_y = num_pixel_xy(2) - ((num_pixel_xy(2)*0.03)-1);
img_size_x = (132)*num_rois; %% to match the slice of stripTemp(val:end, 7:138 ...
strip_width_slice = (7:138); % width to slice each strip

clear mdata roiStr

%% new tiff extraction 

strip_width_px = length(strip_width_slice);
for plane = 1:2
    plane_temp = zeros(img_size_y, img_size_x, num_frames, 'int16');
    for roi_idx = 1:num_rois
        height_range = 1:num_pixel_xy(2);
        if roi_idx == 1
            image_offset_y = 0; 
        else         
            image_offset_y = image_offset_y + roi_height_px + num_lines_between_scanfields;
        end

	    scan_offset = returnScanOffset2(aout(image_offset_y + height_range, :, :, plane), 1);
	    strip_temp = fixScanPhase(aout(row_indices, col_indices, :, plane), scan_offset, 1);
	    rows_to_trim = round(height(stripTemp)*0.03);
	    frame_col_idx = [
		    (roi_idx-1)*strip_width_px+1
		    roi_idx*strip_width_px
		    ];
	    plane_temp(:, frame_col_idx(1):frame_col_idx(2), :) = strip_temp;
    end
end

%% Original 

imageData = zeros(dim1, dim2, numChannels, num_frames, 'int16');
for channel = 1:numChannels
    frameTemp = zeros(dim1, dim2, num_frames, 'int16');
    for roi_idx = 1:num_rois
        stripTemp = zeros(1000,144,num_frames, 'int16');
        stripTemp = cell2mat(permute(cellfun(@(x) x{1}, roiData{1, roi_idx}.imageData{1, channel}, 'UniformOutput', false), [1, 3, 2]));
        corr = returnScanOffset2(stripTemp,1); % find offset correction
        stripTemp = fixScanPhase(stripTemp,corr,1); % fix scan phase
        val = round(size(stripTemp,1)*0.03); % trim excess
        stripTemp = stripTemp(val:end,strip_width_slice,:,:);
        frameTemp(:, (roi_idx-1)*length(strip_width_slice)+1:roi_idx*length(strip_width_slice), :) = stripTemp;
    end
    imageData(:, :, channel, :) = frameTemp;
    % h5write(filename, dataset_name, stripTemp, [1 1 1 channel], size(stripTemp);
end

%% Vectorized Approach
tStart = tic;
T = zeros(1, 3);
DATA = [horzcat(roiData{:}).imageData]; % collapse inner cell arrays
DATA = [DATA{:}];
DATA = [DATA{:}];
DATA = reshape(DATA, 1, 1, num_frames, numChannels, num_rois); % leave space for trimmed data
tMid1 = toc(tStart);
fprintf('Collapsing array, data shape: %s\n', num2str(size(DATA)));
DATA = cell2mat(DATA);
tMid2 = toc(tStart);
fprintf('Converting to numeric array, data shape: %s\n', num2str(size(DATA)));
DATA = num2cell(permute(DATA, [1 2 3 5 4]), [1 2 3 4]);
DATA = cat(4, DATA{:});
tEnd = toc(tStart);
fprintf('Permuting and concatenating cell array, data shape: %s\n', num2str(size(DATA)));

%% Loop with pre-initialized arrays

imageData = zeros(img_size_y, img_size_x, numChannels, num_frames, 'int16');
for channel = 1:numChannels
    frameTemp = zeros(img_size_y, img_size_x, num_frames, 'int16');
    for roi_idx = 1:num_rois
        stripTemp = cell2mat(permute(cat(roiData{1, roi_idx}.imageData{1, channel}, frameTemp), [1, 3, 2]));
        corr = returnScanOffset2(stripTemp,1); % find offset correction
        stripTemp = fixScanPhase(stripTemp,corr,1); % fix scan phase
        val = round(size(stripTemp,1)*0.03); % trim excess
        stripTemp = stripTemp(val:end,strip_width_slice,:,:);
        frameTemp(:, (roi_idx-1)*length(strip_width_slice)+1:roi_idx*length(strip_width_slice), :) = stripTemp;
    
        elapsed = toc / 60;
        fprintf('Elapsed Time: %.2f min\n', elapsed);    
    end
    imageData(:, :, channel, :) = frameTemp;
end

%% Non-modified 

[roiData, roiGroup, header, ~] = scanimage.util.getMroiDataFromTiff(filename); % load in data throuhg scanimage utility
numROIs = numel(roiData); % number of ROIs (ASSUMES THEY ARE ORDERED LEFT TO RIGHT)
totalFrame = length(roiData{1}.imageData{1}); % total number of frames in data set
totalChannel = length(roiData{1}.imageData); % number of channels
frameRate = header.SI.hRoiManager.scanVolumeRate;
sizeXY = roiGroup.rois(1,1).scanfields.sizeXY;
FOV = 157.5.*sizeXY;
numPX = roiGroup.rois(1,1).scanfields.pixelResolutionXY;
pixelResolution = mean(FOV./numPX);

image_data_og = [];
for channel = 1:totalChannel
    disp(['Assembling channel ' num2str(channel) ' of ' num2str(totalChannel) '...'])
    frameTemp = [];
    for strip = 1:numROIs
        % Generate the time series of each ROI in the data
        stripTemp = [];
        for frame = 1:totalFrame
            stripTemp = cat(4,stripTemp,single(roiData{1,strip}.imageData{1,channel}{1,frame}{1,1}));
        end
        corr = returnScanOffset2(stripTemp,1); % find offset correction
        stripTemp = fixScanPhase(stripTemp,corr,1); % fix scan phase
        val = round(size(stripTemp,1)*0.03); % trim excess
        stripTemp = stripTemp(val:end,7:138,:,:);
        frameTemp = cat(2,frameTemp,stripTemp); % create each frame
    end
    image_data_og = single(cat(3,image_data_og,frameTemp));
end