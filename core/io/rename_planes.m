function rename_planes(h5path, order)
% REORDERPLANEFILES Reorder z-plane filenames.
%
% Parameters
% ----------
% h5path : char
%     Path to the directory containing the plane files.
% metadata : struct
%     Metadata containing information about the number of planes.
% order : array
%     Array specifying the new order of the planes.

% Get all relevant files in the directory
files = dir([h5path '/*_plane_*.h5']);
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
save(original_order_filename(fullfile(h5path, 'original_order.mat')), 'original_order', 'order');
fprintf('Plane files reordered successfully and original order saved the h5 attributes.\n');
end
