function Y_out = read_plane(varargin)
% READ_PLANE Reads the specified frames from a dataset in a folder or file.
%
% Parameters
% ----------
% path : char or string, optional
%     The path to the folder containing plane files or a fully qualified
%     path to an HDF5 file.
% dataset_name : char or string
%     The name of the dataset within the HDF5 file (e.g., '/Y').
% plane_number : int
%     The plane number to read from the folder. This is ignored if `folder` is a file path.
% n_frames : array of int, char, string, scalar, optinal
%     The specific frames to read from the dataset.
%     Can be a slice (e.g. 1:100). Can be a scalar (e.g. 2). Or, for all
%     frames, 'all' or "all". Default is 'all'.
%
% Returns
% -------
% Y_out : array
%     The read data from the specified frames of the dataset.
%
% Notes
% -----
% This function interactively prompts the user for input if any required
% parameter is not provided. It handles various errors and prompts the
% user again for correct input.
%
% Examples
% --------
% Read specific frames from a dataset in a folder:
%     Y_out = read_plane('path/to/folder', '/Y', 1, 1:10);
%
% Read specific frames from a dataset in a file:
%     Y_out = read_plane('path/to/file.h5', '/Y', [], 1:10);
%
% See also
% --------
% h5info, h5read

p = inputParser;
addOptional(p, 'path', "None", @(x) (ischar(x) || isstring(x)));
addParameter(p, 'dataset_name', "/Y", @(x) (ischar(x) || isstring(x)) && is_valid_group(x));
addParameter(p, 'plane_number', @isnumeric);
addParameter(p, 'n_frames', 'all', @(x) (ischar(x) || isstring(x)) || isscalar(x));
parse(p, varargin{:});

path = p.Results.path;
dataset_name = p.Results.dataset_name;
plane_number = p.Results.plane_number;
n_frames = p.Results.n_frames;

if path == "None"
    [file,path] = uigetfile({'*.h*';'.m*'},...
        'Select an extracted HDF5 or .mat file:');
    full_filepath = fullfile(path, file);
    if file == 0; error('No folder selected.'); end
elseif isfile(path)
    full_filepath = path;
elseif isfolder(path)
    files = dir(fullfile(path, '*_plane_*.h5'));
    if isempty(files); error('No plane files found in the given path: %s', path); end
    if ~isempty(plane_number)
        full_filepath = fullfile(path, files(plane_number).name);
    else
        plane_number = input(sprintf('Please enter the plane number (1:%d): ', numel(files)));
        if plane_number > numel(files); error("The given plane (%d) exceeds the number of planes found in this folder: %d\n", plane_number, numel(files)); end
        if ischar(plane_number); plane_number = str2double(plane_number); end
        if plane_number < 1 || plane_number > numel(files); error('Invalid plane number.'); end
        full_filepath = fullfile(path, files(plane_number).name);
    end
else
    error("No files found or selected.")
end

% Check if dataset_name was set via the default value
if any(strcmp(p.UsingDefaults, 'dataset_name')); defaults=true; end


% Handle dataset_name
try
    data_info = h5info(full_filepath, dataset_name);
catch ME
    if strcmp(ME.identifier, 'MATLAB:imagesci:h5info:libraryError') || contains(ME.message, 'Unable to find object')
        fprintf('Dataset "%s" not found in file "%s".\n', dataset_name, plane_file);
        display_dataset_names(plane_file);
        dataset_name = input('Please enter a valid dataset name (e.g. "/Y"): ', 's');
        if is_valid_group(dataset_name)
            data_info = h5info(plane_file, dataset_name);
        else
            fprintf('Given dataset_name "%s" is invalid. It must be quoted with a prepended \... try again.', dataset_name);
            dataset_name = input('Please enter a valid dataset name (e.g. "/Y"): ', 's');
            if ~is_valid_group(dataset_name)
                error("%s is still not a valid dataset name.");
            end
        end
    else
        rethrow(ME);
    end
end

data_size = data_info.Dataspace.Size;

% Frames selection
if ischar(n_frames) || isstring(n_frames)
    if convertCharsToStrings(n_frames) == "all"
        n_frames = data_size(end);
    else
        warning("Given argument for n_frames, if character/string, must be 'all', not: %s\n Try again!", n_frames);
        n_frames = input(sprintf('Please enter the frames to read (1:%d): ', data_size(end)));
        if max(n_frames) > data_size(end)
            error('Frames exceed the available range.');
        end
    end
end

slice_start = [ones(1, numel(data_size) - 1), n_frames(1)];
slice_count = [data_size(1:end-1), n_frames];

try
    Y_out = h5read(full_filepath, dataset_name, slice_start, slice_count);
catch ME
    fprintf('\nError: %s\n', ME.message);
    Y_out = [];
end
fprintf("%d frames loaded.", n_frames);
end
