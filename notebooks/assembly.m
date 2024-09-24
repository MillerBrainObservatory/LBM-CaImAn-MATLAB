% base TIFF directory
tiff_path = fullfile('C:\Users\RBO\caiman_data\animal_01\session_01\');

% where your assembled files are saved
assembly_path = fullfile(tiff_path, 'assembled');
% where you want to save the outputs
save_path = fullfile(tiff_path, 'outputs'); 

% Ensure the save_path directory exists; create it if it doesn't
if ~exist(save_path, 'dir')
    mkdir(save_path);
end

% Use the TIFF path to get the metadata file
metadata_file = fullfile(tiff_path, "MH70_0p6mm_FOV_50_550um_depth_som_stim_199mW_3min_M1_00001_00001.tif");
metadata = get_metadata(metadata_file);

%% After assembly, collect a single frame from each assembled image
num_planes = metadata.num_planes;

% Load and normalize images
for plane_idx = 1:num_planes
    % Construct the filename using assembly_path and plane index
    filename = fullfile(assembly_path, sprintf('assembled_plane_%d.h5', plane_idx));
    if isfile(filename)
        Y = h5read(filename, '/Y');
        if plane_idx == 1
            sizeY = size(Y);
            frames = zeros(sizeY(1), sizeY(2), num_planes);
        end
        frames(:, :, plane_idx) = Y(:, :, 2);  % Store each mean image
    end
end

% Normalize the images to the range [0, 255]
frames = uint8(255 * mat2gray(frames));

gif_filename = fullfile(save_path, 'mean_images_saved_with_titles.gif');

for plane_idx = 1:num_planes
    % Add "z-plane N" title to each frame using insertText (creates an RGB image)
    labeled_frame_rgb = insertText(frames(:, :, plane_idx), [10, 10], ...
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

%% Create figure with increased size and set background color to black
figure('Position', [100, 100, 1200, 900], 'Color', 'black');

% Tiled layout with no space between images
tiledlayout(5, 6, 'TileSpacing', 'none', 'Padding', 'none'); 

for plane_idx = 1:num_planes
    nexttile;
    
    current_frame = frames(:, :, plane_idx);
    clim = [min(current_frame(:)), max(current_frame(:))]; % Individual contrast limits
    
    % Display image with individual contrast optimization
    imagesc(current_frame, clim);
    colormap gray; % Set colormap to gray
    axis image;
    axis off;
    
    % Adjust the label position, make it larger, bold, and white
    text(sizeY(2)/2, 80, sprintf('z-plane %d', plane_idx), 'FontSize', 12, ...
        'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'bottom', 'Color', 'white'); % White text on black background
end

% Save the matrix as a separate image
saveas(gcf, 'z_plane_matrix.png');

disp('Matrix saved as z_plane_matrix.png');
