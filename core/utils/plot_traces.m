function plot_traces(input_data, num_neurons, save_path)
% PLOT_TRACES Plots a heatmap of the top active neurons' activity and optionally saves it as a PNG.
%
% Parameters
% ----------
% input_data : char or numeric matrix
%     - If a string (char array), it is treated as the file path to an HDF5 file
%       from which '/T_all' will be read.
%     - If a numeric matrix, it is assumed to be the T_all matrix directly.
% num_neurons : int, optional
%     - The number of top neurons to plot (default = 100).
% save_path : char, optional
%     - Fully qualified file path to save the output figure as a `.png` file.
%       If empty or not provided, the figure is not saved.
%
% Raises
% ------
% - If `input_data` is a string but the file does not exist, an error is thrown.
% - If `input_data` is neither a valid file path nor a numeric matrix, an error is raised.
% - If `save_path` is provided but does not end in `.png`, an error is thrown.
%
% Example Usage
% ------------
% Plot from an HDF5 file:
% >> plot_traces('E:\W2_archive\demas_2021\high_resolution\matlab\collated\collated_planes.h5', 100)
%
% Plot and save as PNG:
% >> plot_traces(T_all, 50, 'C:\Users\flynn\Documents\heatmap.png')

if nargin < 2
    num_neurons = 100;
end
if nargin < 3
    save_path = ''; % Default: No save
end

if ischar(input_data) || isstring(input_data)
    if exist(input_data, 'file') ~= 2
        error('File not found: %s', input_data);
    end
    fprintf('Reading T_all from file: %s\n', input_data);
    T_all = h5read(input_data, '/T_all');
elseif isnumeric(input_data)
    T_all = input_data;
else
    error('Invalid input: must be an HDF5 file path or a numeric matrix.');
end

% Compute total activity for each neuron (sum across time)
total_activity = sum(T_all, 2);

% Sort neurons by descending activity
[~, sorted_indices] = sort(total_activity, 'descend');
top_traces = T_all(sorted_indices(1:num_neurons), :);

% Normalize each neuron's activity (row-wise)
top_traces = top_traces - min(top_traces, [], 2);
top_traces = top_traces ./ max(top_traces, [], 2);

figure_handle = figure;
set(figure_handle, 'Color', 'k');
set(figure_handle, 'InvertHardcopy', 'off');

% Plot heatmap
imagesc(top_traces);
colormap hot;
c = colorbar;
c.Color = 'w';

% Set axis properties
ax = gca;
ax.XColor = 'w';
ax.YColor = 'w';
ax.Color = 'k';

xlabel('Frames (Time)', 'FontWeight', 'bold', 'Color', 'w');
ylabel(sprintf('Top %d Most Active Neurons', num_neurons), 'FontWeight', 'bold', 'Color', 'w');
title('Neuronal Activity Heatmap', 'FontWeight', 'bold', 'Color', 'w');

if ~isempty(save_path)
    % Ensure save_path ends in '.png'
    if ~endsWith(save_path, '.png', 'IgnoreCase', true)
        error('save_path must be a fully qualified .png file path.');
    end
    
    saveas(figure_handle, save_path);
    fprintf('Saved figure as %s\n', save_path);
end
end
