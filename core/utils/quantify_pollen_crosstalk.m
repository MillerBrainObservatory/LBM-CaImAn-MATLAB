clear;

%% Pick Dataset to Compare
clc;
parent_path = fullfile("C:/Users/RBO/Documents/data/ground_truth/high_speed/");
input_crosstalk = matfile(fullfile(parent_path, 'cross_talk_data_set.mat')).v;
save_folder = fullfile(parent_path, 'results');
if ~isfolder(save_folder); mkdir(save_folder); end

%% Load in Pollen Data from TIFF

clc;
tiff_name = fullfile(parent_path, 'pollen_calibration_MAxiMuM_30x_00001.tif');
vv = tiffreadVolume(tiff_name); % 144x145x9030
vv = reshape(vv, [size(vv, 1) size(vv,2) 30 size(vv, 3)/30]); %144x145x30x301

%% Find Crosstalk Percent between Z-Planes
% Define the channel mapping
channel_map = {
    "B", 15, 30;
    "B", 14, 29;
    "B", 13, 28;
    "B", 12, 27;
    "B", 11, 26;
    "B", 10, 25;
    "B", 9, 24;
    "B", 8, 4;
    "B", 7, 23;
    "B", 6, 22;
    "B", 5, 21;
    "B", 4, 20;
    "B", 3, 19;
    "B", 2, 18;
    "B", 1, 3;
    "A", 15, 17;
    "A", 14, 16;
    "A", 13, 15;
    "A", 12, 14;
    "A", 11, 13;
    "A", 10, 12;
    "A", 9, 11;
    "A", 8, 2;
    "A", 7, 10;
    "A", 6, 9;
    "A", 5, 8;
    "A", 4, 7;
    "A", 3, 6;
    "A", 2, 5;
    "A", 1, 1
};

order = fliplr([1 5:10 2 11:17 3 18:23 4 24:30]);

% Convert channel map to table for easier processing
channel_table = cell2table(channel_map, 'VariableNames', {'Cavity', 'RealBeam', 'ChannelIndex'});

num_comparisons = size(order, 2) / 2;

%%
clc;
BG = vv(1:10,1:10,:, :);
BG = mean(BG(:));
voltemp = vv-BG;

image_files = {};
results = zeros(15, 3);

for plane_idx = 1:num_comparisons

    next_idx = plane_idx + 15;
    cavity_pair = channel_table([channel_table.RealBeam] == plane_idx, :);
    cavity_a = cavity_pair(strcmp(cavity_pair.Cavity, "A"), :);
    cavity_b = cavity_pair(strcmp(cavity_pair.Cavity, "B"), :);

    cavity_a.pos = plane_idx;
    cavity_b.pos = next_idx;

    cavity_a.label = sprintf('Cavity A | p %d | chid %d', cavity_a.pos, cavity_a.ChannelIndex);
    cavity_b.label = sprintf('Cavity B | p %d | chid %d', cavity_b.pos, cavity_b.ChannelIndex);

    CAVITYA = squeeze(vv(:, :, cavity_a.ChannelIndex, :));

    CAVITYA(CAVITYA<0)=0;
    CAVITYB = squeeze(vv(:, :, cavity_b.ChannelIndex, :));
    CAVITYB(CAVITYB<0)=0;

    % mean X/Y intensity for each plane/channel
    a_intensity = squeeze(mean(mean(CAVITYA, 1), 2));
    b_intensity = squeeze(mean(mean(CAVITYB, 1), 2));

    % Find the area where Channel 1 is > Channel 3
    fill_area = a_intensity > b_intensity;
    fill_steps = (1:length(a_intensity))';

    % Integrate areas under the curves
    a_auc = trapz(a_intensity);
    b_auc = trapz(b_intensity);
    
    % Calculate the overlapping area
    overlap_area = min(a_intensity, b_intensity);
    overlap_auc = trapz(overlap_area);
    
    xtalk_percent = (overlap_auc / a_auc) * 100;

    % intensity profiles
    f = figure;
    plot(a_intensity, 'r', 'LineWidth', 1.5);
    hold on;
    plot(b_intensity, 'b', 'LineWidth', 1.5);
    fill_steps_fill = fill_steps(fill_area);
    intensity_fill = b_intensity(fill_area);

    % Fill the overlap area
    fill([fill_steps; flipud(fill_steps)], ...
        [zeros(size(overlap_area)); flipud(overlap_area)], ...
        'r', 'FaceAlpha', 0.3, 'EdgeColor', 'none');

    % Adding labels and legend
    xlabel('Depth (µm)');
    ylabel('Normalized Intensity (au)');
    title('Cavity Crosstalk: Z-Intensity Profile');
    legend(cavity_a.label, cavity_b.label, 'Overlap');

    % Adding crosstalk percentage text
    text(55, max(a_intensity) * 0.9, sprintf('%%Crosstalk: %.2f%%', xtalk_percent), 'FontSize', 12, 'Color', 'w');

    hold off;

    save_name = sprintf("%s/plane_%d_vs_plane_%d.png", save_folder, cavity_a.pos, cavity_b.pos);
    exportgraphics(f, save_name, 'Resolution', 300);
    close(gcf);

    image_files{end+1} = save_name;  % Add the filename to the list
    results(plane_idx, :) = [cavity_a.pos, cavity_b.pos, xtalk_percent];
end
channel_table = [channel_table array2table(results, 'VariableNames', {'ChannelA', 'ChannelB', 'XtalkPercent'})];
%%

clc;
save_folder = "C://Users/RBO/Desktop/figs/"; % windows letting this work is ew
gif_filename = fullfile(save_folder, 'crosstalk_profiles_bg_subtracted.gif');
delay_time = 0.5;  % time between frames (s)
for i = 1:length(image_files)
    [img, cmap] = rgb2ind(imread(image_files{i}), 256);
    if i == 1
        imwrite(img, cmap, gif_filename, 'gif', 'LoopCount', Inf, 'DelayTime', delay_time);
    else
        imwrite(img, cmap, gif_filename, 'gif', 'WriteMode', 'append', 'DelayTime', delay_time);
    end
end


