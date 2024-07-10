function write_frames_2d(file, Y_in, varargin)
% Write in-memory 2D data to an HDF5 file.
%
% Parameters
% ----------
% file : char
%     The name of the HDF5 file to write to.
% Y_in : array
%     The multidimensional array to be written to the HDF5 file.
% ds : char, optional
%     Group name of the dataset within the HDF5 file. Default is '/Y'.
% overwrite : logical, optional
%     Whether to overwrite to an existing HDF5 dataset. Dims must match.
%     Default is false.
% append : logical, optional
%     Whether to append to an existing HDF5 dataset. Dims must match.
%     Default is false.


p = inputParser;
p.addRequired('file', @(x) validateattributes(x, {'char', 'string'}, {'nonempty', 'scalartext'}, '', 'file'));
p.addRequired('Y_in', @(x) validateattributes(x, {'numeric'}, {'nonempty'}, '', 'Y_in'));
p.addOptional('ds', '/Y', @(x) is_valid_group(convertStringsToChars(x)));
p.addOptional('overwrite', false, @(x) validateattributes(x, {'logical'}, {'scalar'}));
p.addOptional('append', false, @(x) validateattributes(x, {'logical'}, {'scalar'}));

p.parse(file, Y_in, varargin{:});
ds = p.Results.ds;
append = p.Results.append;
overwrite = p.Results.overwrite;

assert(~(overwrite && append), "Cannot append AND overwrite frames. Please choose one argument to set to true.")

%% Setup Arguments ------

file = convertStringsToChars(file);
ds = convertStringsToChars(ds);
Y_in = squeeze(Y_in);
cl = class(Y_in);

%% Calculate chunk size (how many images to pack into 3rd dimension ------

sizY = size(Y_in);
ndY = numel(sizY);

try
    h5info(file, ds);
    valid_ds = true;
catch
    valid_ds = false;
end

if ~valid_ds % if there is no dataset, none of the other checks matter
    h5create(file, ds, sizY, 'Datatype', cl);
    current_position = 0;
    prev_size = 0;
elseif append
    prev_size = h5info(file, ds).Dataspace.Size;
    if ~isequal(prev_size(1:end), sizY(1:end))
        error('Dataset dimensions do not align.');
    end
    current_position = prev_size(end);
elseif overwrite
    current_position = 0;
    prev_size = 0;
else
    disp("Overwrite is set to false, skipping this dataset.");
    return
end

while current_position < prev_size(end) + sizY(end)
    chunk_end = min(current_position + num_images_per_chunk, prev_size(end) + sizY(end));
    chunk_data = Y_in(:, :, current_position - prev_size(end) + 1:chunk_end - prev_size(end));
    start = [ones(1, ndims(Y_in)-1), current_position + 1];
    if ismatrix(chunk_data)
        return
    end
    h5write(file, ds, chunk_data, start, size(chunk_data));
    current_position = chunk_end;
end
end
