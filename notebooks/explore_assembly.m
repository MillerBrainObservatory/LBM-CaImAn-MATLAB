%% Test different pixel trimming values
% set a typical directory structure
parent_path = fullfile('C:\Users\RBO\Documents\data\high_res\');
data_path = fullfile(parent_path, 'raw');
save_path = fullfile(parent_path, 'extracted');

clc; compute = 1;
if compute
    % vary the amount of pixels trimmed on the right of each roi
    for n_trim_px=0:6
        save_path = fullfile(parent_path, sprintf('extracted_%d_%d', i));
        convertScanImageTiffToVolume( ...
            data_path, ...
            save_path, ...
            'dataset_name', '/Y', ... % default
            'debug_flag', 0, ... % default, if 1 will display files and return
            'fix_scan_phase', 1, ... % default, keep to 1
            'trim_pixels', [n_trim_px n_trim_px 17 0], ... % default, num pixels to trim for each roi
            'overwrite', 1 ...
            );
    end
end

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

filename = fullfile(save_path, "extracted_plane_1.h5");
%%
files = dir([save_path '*.h5']);
info = h5info(filename, '/Y');
h = zeros([1 length(files)]);
h2 = zeros([4 length(files)]);
for i=1:length(files)
    filename = fullfile(save_path, sprintf("extracted_plane_%d.h5", i));
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
    filename = fullfile(save_path, sprintf("extracted_plane_%d.h5", iplane));
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
        data = h5read(filename, '/Y');
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
