%%
import scanimage.util.ScanImageTiffReader;

[currpath, ~, ~] = fileparts(fullfile(mfilename('fullpath'))); % path to this script
addpath(genpath(fullfile(currpath, '../core/')));
full_filepath = fullfile("C:/Users/RBO/Documents/data/high_res/raw/MH70_0p6mm_FOV_50_550um_depth_som_stim_199mW_3min_M1_00001_00001.tif");
reader=ScanImageTiffReader(full_filepath);
vol=reader.data();

%% FILEPATHS

parent_path = 'C:/Users/RBO/Documents/data/';
ds1 = fullfile(parent_path, "high_res");
raw_path = fullfile(ds1, "raw");
extract_path = fullfile(ds1, 'extracted_4px_4px_17px_0px');

files = dir(fullfile(extract_path, '*.h5'));

%%
parent_path = 'C:/Users/RBO/Documents/data/';
ds1 = fullfile(parent_path, "high_res");
contents = dir(ds1);
for dataset_idx = 1:length(contents)
    % Check if the entry is a directory and starts with 'extracted_'
    if contents(dataset_idx).isdir && startsWith(contents(dataset_idx).name, 'extracted_')
        % Get the files within the 'extracted_*' directory
        extracted_contents = dir(fullfile(contents(dataset_idx).folder, contents(dataset_idx).name));
        for plane_idx = 1:length(extracted_contents)
            % Skip '.' and '..' entries
            if ~extracted_contents(plane_idx).isdir
                full_filepath = fullfile(extracted_contents(plane_idx).folder, extracted_contents(plane_idx).name);

                datasets{plane_idx}.data = h5read(full_filepath, '/Y');
                datasets{plane_idx}.metadata = read_h5_metadata(full_filepath, '/Y');
            end
        end
    end
end




%% Interactive Widget

exploreImageFrames(datasets);

%% Functions


function exploreImageFrames(files)
    % Initial values
    plane = 1;
    frame = 1;
    y_start = 1;
    
    maxPlane = length(files);

    maxFrame = size(files{plane}.data, 3);
    maxY = size(files{plane}.data, 1);
    y_end = maxY;

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
        maxFrame = size(files{plane}.data, 3);
        maxY = size(files{plane}.data, 1);
        set(frameSlider, 'Max', maxFrame, 'Value', 1);
        set(yStartSlider, 'Max', maxY, 'Value', 1);
        set(yEndSlider, 'Max', maxY, 'Value', maxY);
        frame = 1;
        y_start = 1;
        y_end = maxY;
        updatePlots();
    end

    function updatePlots()
        currentDataset = files{plane};
        adjustedYStart = min(size(currentDataset.data, 1), y_start);
        adjustedYEnd = min(size(currentDataset.data, 1), y_end);

        roi_data = currentDataset.data(adjustedYStart:adjustedYEnd, :, frame);
        imagesc(roi_data);
        axis image;
        colormap('gray');
        if isfield(currentDataset.metadata, 'numLinesBetweenScanfields') && ...
           currentDataset.metadata.numLinesBetweenScanfields > y_start && ...
           currentDataset.metadata.numLinesBetweenScanfields < y_end
            yline(currentDataset.metadata.numLinesBetweenScanfields, '--');
        end
        title(sprintf('Plane: %d | Frame: %d | Y-slice: %d-%d', plane, frame, y_start, y_end));
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

% 
% function exploreImageFrames(dataset)
% 
%     % Initial values
%     plane = 1;
%     frame = 1;
%     y_start = 1;
%     y_end = 100;
%     num_planes = length(dataset);
% 
%     maxPlane = num_planes;
%     maxFrame = size(dataset{1}.data, 4);
%     maxY = size(dataset{1}.data, 1);
% 
%     % Initialize figure
%     f = figure(1);
%     clf(f);
%     set(f, 'Units', 'Normalized', 'Position', [0.1, 0.1, 0.8, 0.6]);  % Adjusted for additional control space
% 
%     % Slider for y-slice start navigation
%     yStartSlider = createSlider(0.18, 'Y Slice Start', maxY, y_start, @(src, event) updateYSliceStart(round(src.Value)));
%     % Slider for y-slice end navigation
%     yEndSlider = createSlider(0.14, 'Y Slice End', maxY, y_end, @(src, event) updateYSliceEnd(round(src.Value)));
%     % Slider for frame navigation
%     frameSlider = createSlider(0.10, 'Frame', maxFrame, frame, @(src, event) updateFrame(round(src.Value)));
%     % Slider for plane navigation
%     planeSlider = createSlider(0.06, 'Plane', maxPlane, plane, @(src, event) updatePlane(round(src.Value)));
% 
%     % Update plots with initial values
%     updatePlots();
% 
%     % Callback functions for sliders
%     function updateYSliceStart(newYStart)
%         y_start = max(1, min(newYStart, y_end - 1));
%         updatePlots();
%     end
% 
%     function updateYSliceEnd(newYEnd)
%         y_end = max(y_start + 1, min(newYEnd, maxY));
%         updatePlots();
%     end
% 
%     function updateFrame(newFrame)
%         frame = newFrame;
%         updatePlots();
%     end
% 
%     function updatePlane(newPlane)
%         plane = newPlane;
%         updatePlots();
%     end
% 
%     function updatePlots()
%         for nd = 1:num_datasets
%             currentDataset = dataset{nd};
%             adjustedYStart = min(size(currentDataset.data, 1), y_start);
%             adjustedYEnd = min(size(currentDataset.data, 1), y_end);
% 
%             roi_data = currentDataset.data(adjustedYStart:adjustedYEnd, :, plane, frame);
%             sp = subplot(1, num_datasets, nd);
%             imagesc(roi_data);
%             axis image;
%             colormap('gray');
%             if currentDataset.numLinesBetweenScanfields > y_start && currentDataset.numLinesBetweenScanfields < y_end
%                 yline(currentDataset.numLinesBetweenScanfields, '--');
%             end
%             title(sprintf('%s\n%.2f um/px | %.2f Hz\n %s FOV', currentDataset.name, currentDataset.pixel_resolution, currentDataset.frame_rate));
% 
%             pos = get(sp, 'Position');
%             pos(2) = pos(2) + 0.05;
%             pos(4) = pos(4) * 0.85;
%             set(sp, 'Position', pos);
%         end
%         sgtitle(sprintf('Plane: %d | Frame: %d | Y-slice: %d-%d', plane, frame, y_start, y_end));
%     end
% 
%     % Helper function to create sliders
%     function s = createSlider(position, label, maxValue, defaultValue, callback)
%         uicontrol('Style', 'text', 'String', label, ...
%                   'Units', 'normalized', 'Position', [0.01 position 0.08 0.03]);
%         s = uicontrol('Style', 'slider', 'Min', 1, 'Max', maxValue, 'Value', defaultValue, ...
%                       'Units', 'normalized', 'Position', [0.1 position 0.8 0.03], ...
%                       'SliderStep', [1/maxValue 10/maxValue], ...
%                       'Callback', callback);
%     end
% end
