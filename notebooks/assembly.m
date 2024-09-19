%% Test different pixel trimming values
clc;

% set a typical directory structure
tiff_path = fullfile('C:\Users\RBO\caiman_data\animal_01\session_01\');
assembly_path = fullfile(tiff_path, 'assembled');

metadata = get_metadata(fullfile(tiff_path, "MH70_0p6mm_FOV_50_550um_depth_som_stim_199mW_3min_M1_00001_00001.tif"));

%%
num_planes = 30;

% Load and normalize images
for plane_idx=1:num_planes
    filename = sprintf("C://Users/RBO/caiman_data/animal_01/session_01/saved/assembled_plane_%d.h5", plane_idx);
    if isfile(filename)
        Y = h5read(filename, '/Y');
        if plane_idx == 1
            sizeY = size(Y);
            frames = zeros(sizeY(1), sizeY(2), num_planes);
        end
        frames(:, :, plane_idx) = Y(:,:,2);  % Store each mean image
    end
end

% Normalize the images to the range [0, 255]
frames = uint8(255 * mat2gray(frames));

gif_filename = 'mean_images_saved_with_titles.gif';

for plane_idx = 1:num_planes
    % Add "z-plane N" title to each frame using insertText (creates an RGB image)
    labeled_frame_rgb = insertText(frames(:,:,plane_idx), [10, 10], ...
                                   sprintf('z-plane %d', plane_idx), ...
                                   'FontSize', 20, 'BoxOpacity', 0, 'TextColor', 'white');
    
    % Convert the RGB image back to grayscale
    labeled_frame_gray = rgb2gray(labeled_frame_rgb);
    
    % Convert grayscale image to indexed image for GIF
    [imind, cm] = gray2ind(labeled_frame_gray, 256); 
    
    % Write to GIF
    if plane_idx == 1
        imwrite(imind, cm, gif_filename, 'gif', 'Loopcount', inf, 'DelayTime', 0.2);
    else
        imwrite(imind, cm, gif_filename, 'gif', 'WriteMode', 'append', 'DelayTime', 0.2);
    end
end

disp('GIF with titles created successfully!');
% Create figure with increased size and set background color to black
figure('Position', [100, 100, 1200, 900], 'Color', 'black');

% Tiled layout with no space between images
tiledlayout(5, 6, 'TileSpacing', 'none', 'Padding', 'none'); 

for plane_idx = 1:num_planes
    nexttile;
    
    % Optimize contrast for each individual image
    current_frame = frames(:,:,plane_idx);
    clim = [min(current_frame(:)), max(current_frame(:))]; % Individual contrast limits
    
    % Display image with individual contrast optimization
    imagesc(current_frame, clim);
    colormap gray; % Set colormap to gray
    axis image;
    axis off;
    
    % Adjust the label position, make it larger, bold, and white
    text(sizeY(2)/2, -5, sprintf('z-plane %d', plane_idx), 'FontSize', 12, ...
        'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'bottom', 'Color', 'white'); % White text on black background
end

% Save the matrix as a separate image
saveas(gcf, 'z_plane_matrix_saved.png');

disp('Matrix saved as z_plane_matrix.png');

%%

clc; compute = 1;
if compute
    % vary the amount of pixels trimmed on the right of each roi
    for n_trim_px=0:6
        assembly_path = fullfile(parent_path, sprintf('extracted_%d_%d', i));
        convertScanImageTiffToVolume( ...
            data_path, ...
            assembly_path, ...
            'dataset_name', '/Y', ... % default
            'debug_flag', 0, ... % default, if 1 will display files and return
            'fix_scan_phase', 1, ... % default, keep to 1
            'trim_pixels', [n_trim_px n_trim_px 17 0], ... % default, num pixels to trim for each roi
            'overwrite', 1 ...
            );


%% output images of these trimmed images
clc;
parent_path = fullfile('C:\Users\RBO\Documents\data\high_res\');
folders = dir([parent_path 'extracted_*']);
for fold_idx=1:length(folders)

    this_folder = fullfile(folders(fold_idx).folder, folders(fold_idx).name);
    files = dir([this_folder '/*.h5']);
    for file_idx=1

        this_file = fullfile(files(file_idx).folder, files(file_idx).name);
        metadata = read_h5_metadata(this_file, '/Y');

        data = read_plane(this_folder, '/Y', 1, 2);
        imagesc(data); axis image; axis off; title("Right px trimmed: %d" ,file_idx);

    end
end
%%
images = {};
for i=1:size(vol, 3)
    images = {vol(:,:,i,1), vol(:,:,2,1)};
    titles = {"tile1", "tile2"};
end

N = size(vol,3);

for ii = 1:N
    images{ii} = vol(:,:,ii, 1);
    titles
end

%%
% Display the tiled images
display_tiled_images(images, titles);

filename = fullfile(assembly_path, "extracted_plane_1.h5");
%%
files = dir([assembly_path '*.h5']);
info = h5info(filename, '/Y');
h = zeros([1 length(files)]);
h2 = zeros([4 length(files)]);
for i=1:length(files)
    filename = fullfile(assembly_path, sprintf("extracted_plane_%d.h5", i));
    h(i) = h5read(filename, '/offsets_plane');
    metadata = read_h5_metadata(filename, '/Y');
    h2(:, i) = metadata.offsets_roi;
end

%% Analysis matching offsets taken for the entire plane, vs offsets 
%  taken for individual ROI's
clc;

for iplane=1:length(h2(1,:))
    roi_vals = h2(:,iplane); % size 4 double, 
    p_val = h(iplane);
    filename = fullfile(assembly_path, sprintf("extracted_plane_%d.h5", iplane));
    if any(diff(roi_vals))
        data = h5read(filename, '/Y');
        figure; 
        imagesc(data(:, :, 2)); 
        axis image; 
        axis tight; 
        axis off; 
        colormap gray; 
        title("Variable Scan Offset");
        
        % Display roi_vals at the top of the image
        hold on;
        num_vals = length(roi_vals);
        img_width = size(data, 2);
        positions = linspace(1, img_width, num_vals);
        for i = 1:num_vals
            text(positions(i), 10, num2str(roi_vals(i), '%.2f'), 'Color', 'white', 'FontSize', 12, 'HorizontalAlignment', 'center');
        end
        hold off;
    elseif roi_vals(1) ~= p_val    
        data = h5read(filename, '/Y'); % Add this line to load data if not already loaded
        figure; 
        imagesc(data(:, :, 2)); 
        axis image; 
        axis tight; 
        axis off; 
        colormap gray; 
        title("Between-ROI Offsets different from Plane Offset");
    else
    end
end

%% Analysis for what inputs to the scan phase algorithm lead to 
%  what offsets.

clc; clear;

gt_mf = matfile("E:\ground_truth\high_res\offset_data.mat");
gt_raw = single(gt_mf.Iin);
gt_cut = gt_raw(18:end, 7:end-6);

[yind, xind] = get_central_indices(gt_raw,50);

f = figure('Color', 'black', 'Visible', 'on', 'Position', [100, 100, 1400, 600]); % Adjust figure size as needed
sgtitle(sprintf('Scan-Correction Validation: Frame 2, Plane %d', plane_idx), 'FontSize', 16, 'FontWeight', 'bold', 'Color', 'w');
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact'); 

nexttile; imagesc(gt_raw);
axis image; axis tight; axis off; colormap('gray');
title('Raw ROI', 'FontSize', 14, 'FontWeight', 'bold', 'Color', 'k');
nexttile; imagesc(gt_raw(100:115,end-10:end));
axis image; axis tight; axis off; colormap('gray');
title('ROI 1: Cut', 'FontSize', 14, 'FontWeight', 'bold', 'Color', 'k');

gt_square = gt_raw(yind, xind);

scanphase = returnScanOffset(gt_raw, 1, 'single');
scanphase_cut = returnScanOffset(gt_cut, 1, 'single');
scanphase_square = returnScanOffset(gt_square, 1, 'single');

corrected = fixScanPhase(gt_raw, scanphase, 1, 'single');
corrected_cut = fixScanPhase(gt_cut, scanphase_cut, 1, 'single');
corrected_square = fixScanPhase(gt_square, scanphase_square, 1, 'single');

[xr, yr] = get_central_indices(corrected, 50);
[xc, yc] = get_central_indices(corrected_cut, 50);
[xs, ys] = get_central_indices(corrected_square, 50);

imagesc([corrected(xr, yr) corrected_cut(xc, yc) corrected_square(xs, ys)]);
