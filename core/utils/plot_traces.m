function plot_traces(input_data, num_neurons)
% PLOT_TOP_NEURONS Plots a heatmap of the top active neurons' activity.
%
% Parameters
% ----------
% input_data : char or numeric matrix
%     - If a string (char array), it is treated as the file path to an HDF5 file
%       from which '/T_all' will be read.
%     - If a numeric matrix, it is assumed to be the T_all matrix directly.
% num_neurons : int, optional
%     - The number of top neurons to plot (default = 100).
%
% Raises
% ------
% - If `input_data` is a string but the file does not exist, an error is thrown.
% - If `input_data` is neither a valid file path nor a numeric matrix, an error is raised.
%
% Example Usage
% ------------
% Plot from an HDF5 file:
% >> plot_top_neurons('E:\W2_archive\demas_2021\high_resolution\matlab\collated\collated_planes.h5', 100)
%
% Plot from an existing matrix:
% >> plot_top_neurons(T_all, 50)

if nargin < 2
    num_neurons = 100;
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

% sum activity across time
total_activity = sum(T_all, 2);

% sort by activity
[~, sorted_indices] = sort(total_activity, 'descend');
top_traces = T_all(sorted_indices(1:num_neurons), :);

% normalize
top_traces = top_traces - min(top_traces, [], 2);
top_traces = top_traces ./ max(top_traces, [], 2);

% heatmap
figure;
imagesc(top_traces);
colormap hot;
colorbar;
xlabel('Frames (Time)');
ylabel(sprintf('Top %d Most Active Neurons', num_neurons));
title('Neuronal Activity Heatmap');
end