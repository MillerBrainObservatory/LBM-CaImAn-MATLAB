function write_mean_images_to_png(directory)
% Create a grid of mean-images from HDF5 datasets in the specified directory.
%
% This function reads HDF5 files from a specified directory, extracts the '/Ym'
% dataset (assumed to be a 2D image) from each file, and creates a 5x6 grid of
% these images with no padding or tile spacing. The function processes up to
% 30 HDF5 files in the directory.
%
% Parameters
% ----------
% directory : char
%     The directory containing the HDF5 files.
% ds : char, optional
%     The group/dataset name. Default is '/Y'.
%
% Examples
% --------
% Example 1:
%     % Create an image grid from HDF5 files in a specified directory
%     write_image_grid('path/to/hdf5/files');
%
% Notes
% -----
% - The function processes up to 30 HDF5 files. If there are fewer than 30 files,
%   it will process all available files.
% - The function uses MATLAB's tiled layout feature to create a 5x6 grid of images
%   with no padding or tile spacing.

files = dir(fullfile(directory, '*.h5'));
num_files = 30;
tiledlayout(5, 6, 'Padding', 'none', 'TileSpacing', 'none');
for i = 1:num_files
	filepath = fullfile(directory, files(i).name);
	data = h5read(filepath, '/Ym');
	nexttile;
	imshow(data, []);
end
end
