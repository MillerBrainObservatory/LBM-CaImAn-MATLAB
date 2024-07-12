function Y_out = read_plane(path, ds,varargin)
% Read a specific plane from an HDF5 or MAT file and return the data. If
% input is a MAT file, a matfile object is returned.
% 
% Parameters
% ----------
% path : str, optional
%     Path to the HDF5 or MAT file or the directory containing plane files. If empty, a file selection dialog will open.
% ds : str, optional
%     Dataset group name within the HDF5 file. If empty, the function will attempt to find a valid dataset or prompt the user.
% plane : int, optional
%     Plane number to read from the file. User is prompted if not given.
% frames : str or int, optional
%     Frames to read from the dataset. Can be 'all', a scalar frame number
%     i.e. 2, a slice i.e. 1:400, vector of size 2 with the start and stop
%     index i.e. [5 400]. Default is 'all'.
% 
% Returns
% -------
% Y_out : array-like or MAT-file object
%     The data read from the specified plane and frames in the file.
%
% Notes
% -----
% This function interactively prompts the user for input if any required
% parameter is not provided. It handles various errors and prompts the
% user again for correct input.
%
% Examples
% --------
% Use dialog and prompts only:
%     Y_out = read_plane();
% Read all frames from a file givin the full filepath:
%     Y_out = read_plane('data.h5');
% Use plane argument to read from a folder of files with _plane_ in the name:
%     Y_out = read_plane('C:/data/extracted_files', 'plane', 4);
% Read specific frames from a dataset in a folder:
%     Y_out = read_plane('data.h5', 4, 'all');
%
% Read specific frames from a dataset in a file:
%     Y_out = read_plane('path/to/file.h5', '/Y', [], 1:10);
%

p = inputParser;
addOptional(p, 'path', '', @(x) (ischar(x) || isstring(x)));
addOptional(p, 'ds', '', @(x) (ischar(x) || isstring(x)) && is_valid_group(x));
addOptional(p, 'plane', 0, @isnumeric);
addOptional(p, 'frames', 'all', @(x) (ischar(x) || isstring(x)) || isscalar(x) || ismatrix(x));
parse(p, path, ds, varargin{:});

path = p.Results.path;
ds = p.Results.ds;
plane = p.Results.plane;
frames = p.Results.frames;

if isempty(path)
    [file,path] = uigetfile({'*.h*';'.m*'},...
        'Select an extracted HDF5 or .mat file:');
    full_filepath = fullfile(path, file);
    if file == 0; error('No folder selected.'); end
    if full_filepath(end-2:end) == ".mat"
        Y_out = matfile(full_filepath);
        return
    end
elseif isfile(path)
    full_filepath = path;
elseif isfolder(path)
    files = dir(fullfile(path, '*_plane_*.h5'));
    if isempty(files); error('No plane files found in the given path: %s', path); end
    if ~isempty(plane)
        full_filepath = fullfile(path, files(plane).name);
    else
        plane = input(sprintf('Please enter the plane number (1:%d): ', numel(files)));
        if plane > numel(files); error("The given plane (%d) exceeds the number of planes found in this folder: %d\n", plane, numel(files)); end
        if ischar(plane); plane = str2double(plane); end
        if plane < 1 || plane > numel(files); error('Invalid plane number.'); end
        full_filepath = fullfile(path, files(plane).name);
    end
else
    error("No files found or selected.")
end

if isempty(ds)
    if is_valid_dataset(full_filepath, '/Y')
        warning("No ds (dataset group name) provided, however h5 file contains /Y... Using this group.\n")
        ds = "/Y";
    elseif is_valid_dataset(full_filepath, '/mov')
        warning("No ds (dataset group name) provided, however h5 file contains /mov... Using this group.\n")
        ds = "/mov";
    else
        display_dataset_names(full_filepath);
        ds = input('Please enter a valid dataset name (e.g. "/Y"): ', 's');
    end
end

try
    data_info = h5info(full_filepath, ds);
catch ME
    if strcmp(ME.identifier, 'MATLAB:imagesci:h5info:libraryError') || contains(ME.message, 'Unable to find object')
        fprintf('Dataset "%s" not found in file "%s".\n', ds, full_filepath);
        display_dataset_names(full_filepath);
        ds = input('Please enter a valid dataset name (e.g. "/Y"): ', 's');
        if is_valid_group(ds)
            data_info = h5info(full_filepath, ds);
        else
            fprintf('Given dataset_name "%s" is invalid. It must be quoted with a prepended \... try again.', ds);
            ds = input('Please enter a valid dataset name (e.g. "/Y"): ', 's');
            if ~is_valid_group(ds)
                error("%s is still not a valid dataset name.");
            end
        end
    else
        rethrow(ME);
    end
end
data_size = data_info.Dataspace.Size;
if ischar(frames) || isstring(frames)
    if convertCharsToStrings(frames) == "all"
        str = fprintf("All %d frames loaded.\n", frames);
        frames = data_size(end);
        slice_start = [ones(1, numel(data_size) - 1), 1];
        slice_count = [data_size(1:end-1), data_size(end)];
    else
        warning("Given argument for n_frames, if character/string, must be 'all', not: %s\n Try again!", frames);
        frames = input(sprintf('Please enter the frames to read as a number (i.e. 4), slice (i.e. 1:%d) or "all": ', data_size(end)));
        str = fprintf("All %d frames loaded.\n", frames);
        if max(frames) > data_size(end)
            error('Frames exceed the available range.');
        end
    end
elseif isscalar(frames)
    str = fprintf("Frame %d loaded.\n", frames);
    slice_start = [ones(1, numel(data_size) - 1), 1];
    slice_count = [data_size(1:end-1), frames];
elseif ismatrix(frames)
    str = fprintf("%d frames loaded.\n", numel(frames));
    slice_start = [ones(1, numel(data_size) - 1), frames(1)];
    slice_count = [data_size(1:end-1), frames(2) - frames(1) + 1];
else
    error('Invalid format for n_frames. It must be a scalar, a slice string, or a two-element array.');
end

try
    Y_out = h5read(full_filepath, ds, slice_start, slice_count);
catch ME
    fprintf('\nError: %s\n', ME.message);
    Y_out = [];
end
fprintf("%d frames loaded.\n", frames);
end
