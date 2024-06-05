%% extract scanimage tiff data
% scanimage version: 2016
% using the scanimage.opentiff() utility, we avoid the overhead of extracting roi's
% extract header data with scanimage.extractheaderdata()
% numpixels should not be used, this was deprecated in scanimage 2016 (current version being used)
% ...this includes si.hroiManager.pixelsPerLine
% scanimage 2016 does not use scanimagetiffreader()
% for image [H x W], the standard tiff imagelength and imagewidth values are used
% to get the distance between rois/scanfields:
%       - flytotimeperscanfield / hroiManager.lineperiod

import ScanImageTiffReader.ScanImageTiffReader;

[currpath, ~, ~] = fileparts(fullfile(mfilename('fullpath'))); % path to this script
addpath(genpath(fullfile(currpath, '../core/')));
addpath(genpath(fullfile(currpath, '../packages/ScanImage_Utilities/SI2016bR1_2017-09-28-140040_defde478ed/')));

filename = 'C:\Users\RBO\Documents\MATLAB\benchmarks\high_resolution\MH70_0p6mm_FOV_50_550um_depth_som_stim_199mW_3min_M1_00001_00001.tif';

reader=ScanImageTiffReader(filename);
vol=reader.data();
%%
vol2 = reshape(vol, [145 2478 30 1730]);
vol2 = permute(vol2, [2 1 3 4]);
slice = vol2(:, :, 21, 2:202);
%%
clear all
data = matfile("C:\\Users\RBO\Documents\MATLAB\benchmarks\high_resolution\MH70_0p6mm_FOV_50_550um_depth_som_stim_199mW_3min_M1_00001_00001.mat");

%%
metadata = get_metadata(filename);

% imshow(vol(:,:,floor(size(vol,3)/2)),[]);

%% extract data for the 4 datasets before any scanimage manipulations
% base = "C:\Users\RBO\Documents\MATLAB\benchmarks\";

% filepaths = {
%     % fullfile('C:\Users\RBO\Documents\MATLAB\benchmarks\test\mh89_hemisphere_FOV_50_550um_depth_250mW_dual_stimuli_30min_00001_00001.tif');
%     'C:\Users\RBO\Documents\MATLAB\benchmarks\exploration\mh89_hemisphere_FOV_50_550um_depth_250mW_dual_stimuli_30min_00001_00001.tif'; %singlehemi
%     'C:\Users\RBO\Documents\MATLAB\benchmarks\exploration\MH70_0p6mm_FOV_50_550um_depth_som_stim_199mW_3min_M1_00001_00001.tif'; % highres
%     'C:\Users\RBO\Documents\MATLAB\benchmarks\exploration\MH70_0p9mm_FOV_50_550um_depth_som_stim_199mW_3min_M1_00001_00001.tif'; % highspeed
%     'C:\Users\RBO\Documents\MATLAB\benchmarks\exploration\MH184_both_6mm_FOV_150_600um_depth_410mW_9min_no_stimuli_00001_00001.tif'; % bihemi
%     };

%% Pipeline Setup

plane = 1;
h5path = fullfile('C:\Users\RBO\Documents\data\bi_hemisphere\extracted_final\MH184_both_6mm_FOV_150_600um_depth_410mW_9min_no_stimuli_00001_00001.h5');
reg_str = '/registration';
ds_str = sprintf('%s/plane_%d/Y', reg_str, plane);
data = h5read(h5path, ds_str);

%% ground truth setup

data_gt = matfile(fullfile("../../Documents/data/ground_truth/MH184_both_6mm_FOV_150_600um_depth_410mW_9min_no_stimuli_00001_plane_30.mat")).Y;

data_diff = (mean(data_gt, 3) - mean(data, 3));
imagesc(data_diff); axis image; % confirm all 0s
%% reorder

clc
order = [1 5:10 2 11:17 3 18:23 4 24:30];

% reorderPlanes(h5path, loc, fliplr(order));
%%

lbm_data = cell(size(filepaths));
for i = 1:length(filepaths)
    lbm_data{i} = struct;
    lbm_data{i}.name = filepaths{i, 1};
    lbm_data{i}.data = filepaths{i, 2};
end

%% Interactive Widget
exploreImageFrames(lbm_data);

%% Extract neuronal footprints to add to dataset
for d=1:length(lbm_data)
    dataset = lbm_data{d};
    datapath = dataset.path;
    [fpath, fname, ext] = fileparts (datapath);
    for plane=length(dataset.numPlanes)
        planeIdentifier = sprintf("caiman_output_plane_%d.mat", plane);
        caiman_path = fullfile(base, dataset.name, planeIdentifier);
        matvars = matfile(caiman_path);
        lbm_data{i}.caiman_vars = matvars;
    end
end

%% Edge Detection
figure(1);
% plane = 1;
frame = 2;
t1 = tiledlayout(1, 2);
nexttile;

num_roi = 9;
sy = size(new, 1);
roi_data = new(:, :, frame);
imagesc([old(:, :, frame) new(:, :, frame) imshowpair(old(:, :, frame), new(:, :, frame),"diff")]); axis image;
set(gca,'xtick',[1, size(roi_data, 2)]);

%%
nexttile;
num_roi = 9;
sy = size(new, 1);
roi_datao = old(:, :, frame);
imagesc(roi_data); axis image;
set(gca,'xtick',[1, size(roi_data, 2)]);

d = imshowpair(roi_data, roi_datao,"diff");
%% Functions

function exploreImageFrames(dataset)

    % Initial values
    plane = 1;
    frame = 1;
    y_start = 1;
    y_end = 100;
    num_datasets = length(dataset);
    if length(size(dataset)) == 3
        maxFrame = size(dataset{1}.data, 3);
        maxPlane = 1;
    elseif length(size(dataset)) == 4
        maxPlane = size(dataset{1}.data, 3);
        maxFrame = size(dataset{1}.data, 4);
    end
    maxY = size(dataset{1}.data, 1);  % Maximum y value

    % Initialize figure
    f = figure(1);
    clf(f);
    set(f, 'Units', 'Normalized', 'Position', [0.1, 0.1, 0.8, 0.6]);  % Adjusted for additional control space

    % Slider for y-slice start navigation
    yStartSlider = createSlider(0.18, 'Y Slice Start', maxY, y_start, @(src, event) updateYSliceStart(round(src.Value)));
    % Slider for y-slice end navigation
    yEndSlider = createSlider(0.14, 'Y Slice End', maxY, y_end, @(src, event) updateYSliceEnd(round(src.Value)));
    % Slider for frame navigation
    frameSlider = createSlider(0.10, 'Frame', maxFrame, frame, @(src, event) updateFrame(round(src.Value)));
    % Slider for plane navigation
    planeSlider = createSlider(0.06, 'Plane', maxPlane, plane, @(src, event) updatePlane(round(src.Value)));

    % Update plots with initial values
    updatePlots();

    % Callback functions for sliders
    function updateYSliceStart(newYStart)
        y_start = max(1, min(newYStart, y_end - 1));
        updatePlots();
    end

    function updateYSliceEnd(newYEnd)
        y_end = max(y_start + 1, min(newYEnd, maxY));
        updatePlots();
    end

    function updateFrame(newFrame)
        frame = newFrame;
        updatePlots();
    end

    function updatePlane(newPlane)
        plane = newPlane;
        updatePlots();
    end

    function updatePlots()
        for nd = 1:num_datasets
            currentDataset = dataset{nd};
            adjustedYStart = min(size(currentDataset.data, 1), y_start);
            adjustedYEnd = min(size(currentDataset.data, 1), y_end);

            roi_data = currentDataset.data(adjustedYStart:adjustedYEnd, :, plane, frame);
            sp = subplot(1, num_datasets, nd);
            imagesc(roi_data);
            axis image;
            colormap('gray');
            if currentDataset.numLinesBetweenScanfields > y_start && currentDataset.numLinesBetweenScanfields < y_end
                yline(currentDataset.numLinesBetweenScanfields, '--');
            end
            title(sprintf('%s\n%.2f um/px | %.2f Hz\n %s FOV', currentDataset.name, currentDataset.pixel_resolution, currentDataset.frame_rate));

            pos = get(sp, 'Position');
            pos(2) = pos(2) + 0.05;
            pos(4) = pos(4) * 0.85;
            set(sp, 'Position', pos);
        end
        sgtitle(sprintf('Plane: %d | Frame: %d | Y-slice: %d-%d', plane, frame, y_start, y_end));
    end

    % Helper function to create sliders
    function s = createSlider(position, label, maxValue, defaultValue, callback)
        uicontrol('Style', 'text', 'String', label, ...
                  'Units', 'normalized', 'Position', [0.01 position 0.08 0.03]);
        s = uicontrol('Style', 'slider', 'Min', 1, 'Max', maxValue, 'Value', defaultValue, ...
                      'Units', 'normalized', 'Position', [0.1 position 0.8 0.03], ...
                      'SliderStep', [1/maxValue 10/maxValue], ...
                      'Callback', callback);
    end
end

function [data] = extract_data(filepath)
    data = struct;

    [fpath, fname, ext] = fileparts(filepath);
    matname = fullfile(fpath, [fname '.mat']);
    data.path = filepath;
    data.matpath = matname;

    if isfile(matname)
        ext = '.mat';
    end

    switch lower(ext)
        case {'.tif', '.tiff'}
            disp('loading tiff');
            [~, si_data] = scanimage.util.opentif(filepath);
            si_data = squeeze(si_data(:, :, :, 1:5));
            savefast(matname, 'si_data')
            data.data = si_data;
            clear si_data matname;
        case '.mat'
            si_data = load(matname, 'si_data');
            data.data = si_data.si_data;
        otherwise
            error(['Unsupported file extension: ', ext]);
    end

    % Scanfield metadata
    hTiff = Tiff(data.path);
    roiStr = hTiff.getTag('Artist'); % where scanimage decided to store image data
    roiStr(roiStr == 0) = []; % remove null termination
    mdata = most.json.loadjson(roiStr);
    mdata = mdata.RoiGroups.imagingRoiGroup.rois;

     % Tiff-wide metadata (header) / Frame-specific metadata (frameDescs)
    [header, frameDescs] = scanimage.util.private.getHeaderData(hTiff);
    verInfo = scanimage.util.private.getSITiffVersionInfo(header);
    header = scanimage.util.private.parseFrameHeaders(header,frameDescs,verInfo);
    hdr = scanimage.util.private.extractHeaderData(header,verInfo);
    data.scanimage = header.SI;

    % even though our ROIS are aligned vertically
    data.objective_resolution = header.SI.objectiveResolution; % objective scan angle um/deg
    data.sizeXY = mdata{1, 1}.scanfields.sizeXY; % size in deg
    data.centerXY = mdata{1, 1}.scanfields.centerXY; % center location in deg
    data.numPixXY = mdata{1, 1}.scanfields.pixelResolutionXY; % number of pixels per roi
    data.FOV = round(data.objective_resolution.*data.sizeXY); % in PX
    data.lateral_sampling = data.FOV./data.numPixXY; % um/px in X and Y
    data.pixel_resolution = mean(data.FOV./data.numPixXY); % use the mean for computations

    data.numImages = numel(frameDescs);
    data.numPlanes = length(hdr.savedChans);
    data.numFrames = hdr.numFrames;
    data.numLinesBetweenScanfields = round(header.SI.hScan2D.flytoTimePerScanfield/header.SI.hRoiManager.linePeriod);
    data.frame_rate = header.SI.hRoiManager.scanFrameRate;
    data.numROI = length(mdata);

    data.lines_per_frame = header.SI.hRoiManager.linesPerFrame;
    data.pixels_per_line = header .SI.hRoiManager.pixelsPerLine;
    data.num_frames_total = header.SI.hStackManager.framesPerSlice;
    data.num_frames_file = header.SI.hScan2D.logFramesPerFile;

    data.flybacktime = header.SI.hScan2D.flybackTimePerFrame;
    data.flytotime = header.SI.hScan2D.flytoTimePerScanfield;
    data.time_per_pixel = header.SI.hScan2D.scanPixelTimeMean;

end

function [data] = extract_roi_data(filepath)
    data = struct;

    [fpath, fname, ext] = fileparts(filepath);
    matname = fullfile(fpath, [fname '.mat']);
    data.path = filepath;
    data.matpath = matname;

    if isfile(matname)
        ext = '.mat';
    end

    switch lower(ext)
        case {'.tif', '.tiff'}
            disp('loading tiff');
            [roiData, roiGroup, header, ~] = scanimage.util.getMroiDataFromTiff(filepath);
            numROIs = numel(roiData); % number of ROIs (ASSUMES THEY ARE ORDERED LEFT TO RIGHT)
            totalFrame = length(roiData{1}.imageData{1});
            si_data = squeeze(si_data(:, :, :, 1:5));
            savefast(matname, 'si_data')
            data.data = si_data;
            clear si_data matname;
        case '.mat'
            si_data = load(matname, 'si_data');
            data.data = si_data.si_data;
        otherwise
            error(['Unsupported file extension: ', ext]);
    end

    % Scanfield metadata
    hTiff = Tiff(data.path);
    roiStr = hTiff.getTag('Artist'); % where scanimage decided to store image data
    roiStr(roiStr == 0) = []; % remove null termination
    mdata = most.json.loadjson(roiStr);
    mdata = mdata.RoiGroups.imagingRoiGroup.rois;

     % Tiff-wide metadata (header) / Frame-specific metadata (frameDescs)
    [header, frameDescs] = scanimage.util.private.getHeaderData(hTiff);
    verInfo = scanimage.util.private.getSITiffVersionInfo(header);
    header = scanimage.util.private.parseFrameHeaders(header,frameDescs,verInfo);
    hdr = scanimage.util.private.extractHeaderData(header,verInfo);
    data.scanimage = header.SI;

    % even though our ROIS are aligned vertically
    data.objective_resolution = header.SI.objectiveResolution; % objective scan angle um/deg
    data.sizeXY = mdata{1, 1}.scanfields.sizeXY; % size in deg
    data.centerXY = mdata{1, 1}.scanfields.centerXY; % center location in deg
    data.numPixXY = mdata{1, 1}.scanfields.pixelResolutionXY; % number of pixels per roi
    data.FOV = round(data.objective_resolution.*data.sizeXY); % in PX
    data.lateral_sampling = data.FOV./data.numPixXY; % um/px in X and Y
    data.pixel_resolution = mean(data.FOV./data.numPixXY); % use the mean for computations

    data.numImages = numel(frameDescs);
    data.numPlanes = length(hdr.savedChans);
    data.numFrames = hdr.numFrames;
    data.numLinesBetweenScanfields = round(header.SI.hScan2D.flytoTimePerScanfield/header.SI.hRoiManager.linePeriod);
    data.frame_rate = header.SI.hRoiManager.scanFrameRate;
    data.numROI = length(mdata);

    data.lines_per_frame = header.SI.hRoiManager.linesPerFrame;
    data.pixels_per_line = header .SI.hRoiManager.pixelsPerLine;
    data.num_frames_total = header.SI.hStackManager.framesPerSlice;
    data.num_frames_file = header.SI.hScan2D.logFramesPerFile;

    data.flybacktime = header.SI.hScan2D.flybackTimePerFrame;
    data.flytotime = header.SI.hScan2D.flytoTimePerScanfield;
    data.time_per_pixel = header.SI.hScan2D.scanPixelTimeMean;
end

