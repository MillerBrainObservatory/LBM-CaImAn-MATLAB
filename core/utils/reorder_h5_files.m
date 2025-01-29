function reorder_h5_files(h5path, order)
% Reorder and rename HDF5 files based on a specified order.
%
% This function reorders and renames HDF5 files in a specified directory (`h5path`)
% based on the provided `order` array. It temporarily renames files to avoid conflicts,
% updates the HDF5 attributes to store the original order, and saves the original order
% as a .mat file.
%
% Parameters
% ----------
% h5path : char or string
%     The path to the directory containing the HDF5 files to be reordered.
% order : array
%     An array specifying the new order of the HDF5 files. The length of this array
%     must match the number of HDF5 files in the directory.
%
% Notes
% -----
% The function ensures that the HDF5 files are sorted, renames them to temporary names
% to avoid conflicts, and then renames them to their new ordered names. The original
% order is stored as an attribute in each HDF5 file and saved as a .mat file.
%
% Examples
% --------
% Reorder HDF5 files in a directory based on a specified order:
%
%     h5path = 'path/to/h5/files';
%     order = [3, 1, 2, 4];
%     reorder_h5_files(h5path, order);

% Get all relevant files in the directory

if isstring(h5path)
    h5path = convertStringsToChars(h5path);
end
files = dir([h5path '/*plane*.h5']);
if isempty(files)
    fprintf('No files found in %s\n', h5path);
    return;
end

% Ensure that the files are sorted
[~, idx] = sort({files.name});
files = files(idx);

num_files = length(files);
% Rename all files to temporary names to avoid conflicts
temp_files = cell(num_files, 1);
for i = 1:num_files
    [folder, name, ext] = fileparts(files(i).name);
    temp_files{i} = fullfile(files(i).folder, [name '_temp' ext]);
    movefile(fullfile(files(i).folder, files(i).name), temp_files{i});
end

% Rename temporary files to new ordered names
for i = 1:num_files
    original_name = temp_files{i};
    [~, name, ext] = fileparts(original_name);
    tokens = regexp(name, '(.*)_plane_(\d+)', 'tokens');
    if isempty(tokens)
        error('Filename %s does not match expected pattern: _plane_.', name);
    end
    base_name = tokens{1}{1};
    new_name = fullfile(files(i).folder, sprintf('%s_plane_%d%s', base_name, order(i), ext));
    h5writeatt(original_name, '/', 'original_plane', i);
    movefile(original_name, new_name);
end

% Store the original order as a .mat file
original_order = 1:num_files;
original_order_filename = fullfile(h5path, 'original_order.mat');
save(original_order_filename, 'original_order', 'order');
fprintf('Plane files reordered successfully and original order saved the h5 attributes.\n');
end
