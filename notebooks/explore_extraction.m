%% Explore ScanImage Data Extraction

clc
[fpath, fname, ~] = fileparts(fullfile(mfilename('fullpath'))); % path to this script
addpath(genpath(fullfile(fpath, 'core/')));

result = validateRequirements();
if ischar(result)
    error(result); 
else
    disp('Proceeding with execution...');
end

parent_path = 'C:\Users\RBO\Documents\data\bi_hemisphere\';
raw_path = [ parent_path 'raw\'];
extract_path = [ parent_path 'extracted_gt_strip\'];
mc_path = [ parent_path 'registration\'];
traces_path = [ parent_path 'traces\'];
metadata = get_metadata(fullfile(raw_path ,"MH184_both_6mm_FOV_150_600um_depth_410mW_9min_no_stimuli_00001_00001.tif"));
metadata.base_filename = "MH184_both_6mm_FOV_150_600um_depth_410mW_9min_no_stimuli_00001";

mkdir(extract_path); mkdir(raw_path); mkdir(mc_path); mkdir(traces_path);
%%

% grab the first 3D planar time-series
plane = combinePlanes(fullfile(extract_path, "MH184_both_6mm_FOV_150_600um_depth_410mW_9min_no_stimuli_00001_00001.h5"), 1);

% figure; imshow(plane(:,:,floor(size(plane,3)/2)),[]);

%% Edge Detection

num_frames = 200;
tileHeight = size(plane, 1); 
tileWidth = 132; 
% Get the size of the time series
[height, width, numFrames] = size(plane);

% Number of tiles in each dimension
numTilesY = height / tileHeight;
numTilesX = width / tileWidth;

% Define the edge detection method
edgeMethod = 'Canny'; % You can use 'Sobel', 'Prewitt', etc.

% Initialize consistency data array
consistencyData = zeros(numFrames, numTilesY, numTilesX-1); % for horizontal boundaries
consistencyDataVertical = zeros(numFrames, numTilesY-1, numTilesX); % for vertical boundaries

% Process each frame
for t = 1:num_frames
    % Detect edges for each tile in the frame
    edges = cell(numTilesY, numTilesX);
    for i = 1:numTilesY
        for j = 1:numTilesX
            % Extract tile
            tile = plane((i-1)*tileHeight+1:i*tileHeight, (j-1)*tileWidth+1:j*tileWidth, t);
            % Detect edges
            edges{i, j} = edge(tile, edgeMethod);
        end
    end
    
    % Compare edges at horizontal boundaries
    for i = 1:numTilesY
        for j = 1:(numTilesX-1)
            edge1 = edges{i, j}(:, end); % Right edge of the current tile
            edge2 = edges{i, j+1}(:, 1); % Left edge of the next tile
            consistencyData(t, i, j) = compareEdges(edge1, edge2);
        end
    end
    
    % Compare edges at vertical boundaries
    for i = 1:(numTilesY-1)
        for j = 1:numTilesX
            edge1 = edges{i, j}(end, :); % Bottom edge of the current tile
            edge2 = edges{i+1, j}(1, :); % Top edge of the next tile
            consistencyDataVertical(t, i, j) = compareEdges(edge1, edge2);
        end
    end
end

% Calculate mean consistency for horizontal and vertical edges over time
meanConsistencyHorizontal = mean(mean(consistencyData, 2), 3);
meanConsistencyVertical = mean(mean(consistencyDataVertical, 2), 3);

% Plot consistency over time
figure;
subplot(2, 1, 1);
plot(meanConsistencyHorizontal);
xlabel('Frame');
ylabel('Mean Horizontal Edge Consistency');
title('Horizontal Edge Consistency Between Tiles Over Time');

subplot(2, 1, 2);
plot(meanConsistencyVertical);
xlabel('Frame');
ylabel('Mean Vertical Edge Consistency');
title('Vertical Edge Consistency Between Tiles Over Time');

%%
% Define the range of frames to visualize
startFrame = 199;
endFrame = 210;

% Define the tile dimensions
tileHeight = size(plane, 1); % example tile height
tileWidth = size(plane, 2);  % example tile width

% Get the size of the volume
[height, width, numFrames] = size(plane);

% Define the edge detection method
edgeMethod = 'Canny';

% Initialize a structure array to store frames
numFramesToShow = endFrame - startFrame + 1;
frames(numFramesToShow) = struct('cdata', [], 'colormap', []);

% Create a figure and make it minimized
hFig = figure('Visible', 'on', 'WindowState', 'minimized');

for frameIdx = startFrame:endFrame
    edges = edge(plane(:, :, frameIdx), edgeMethod);
    
    imshow(edges);
    title(['Edge Detection: Frame ' num2str(frameIdx)]);
    
    % Capture the current frame
    frames(frameIdx) = getframe(hFig);
end

% Close the minimized figure
close(hFig);

% % Create a new figure for playing the movie
% hFig = figure;
% movie(hFig, frames, 1, 2); % Adjust the playback speed with the last parameterS
%%
function consistency = compareEdges(edge1, edge2)
    % Calculate difference between edges
    diff = abs(edge1 - edge2);
    % Consistency can be measured as the inverse of the sum of differences
    consistency = 1 - sum(diff(:)) / numel(diff);
end

