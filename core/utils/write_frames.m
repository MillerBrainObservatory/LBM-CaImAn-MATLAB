function write_frames(file,Y_in,varargin)
% Write in-memory 3D or 4D data to an HDF5 file in chunks.
%
% This function writes a multidimensional array `Y_in` to an HDF5 file specified
% by `file` in chunks. It creates a dataset within the HDF5 file and writes the
% data in specified chunk sizes. If `dataset_name` is not provided, it defaults
% to '/Y'. If target_chunk_mb size is not provided, it defaults to 2000.
%
% Parameters
% ----------
% file : char
%     The name of the HDF5 file to write to.
% Y_in : array
%     The multidimensional array to be written to the HDF5 file.
% ds : char, optional
%     The name of the dataset group within the HDF5 file. Default is '/Y'.
% target_chunk_mb : int, optional
%     In MB, the chunk_size to include in each h5 write. Default is 4MB.
%
% Notes
% -----
% The function handles 3D or 4D arrays and writes them incrementally to the HDF5
% file to manage memory usage efficiently. It also trims the last frame of each
% chunk if the chunk size exceeds the remaining data size.
%
% Examples
% --------
% Write a 3D array to an HDF5 file with default chunk size and dataset name:
%
%     write_frames('data.h5', my_data);
%
% Write a 4D array to an HDF5 file with a specified chunk size:
%
%     write_frames('data.h5', my_data, 2); % 2Mb chunks
%
% Write a 3D array to an HDF5 file with a specified dataset name:
%
%     write_frames('data.h5', my_data, '/Y');
%
% See also
% --------
% h5create, h5write

p = inputParser;
p.addRequired('file', @(x) validateattributes(x, {'char', 'string'}, {'nonempty', 'scalartext'}, '', 'file'));
p.addRequired('Y_in', @(x) validateattributes(x, {'numeric'}, {'nonempty'}, '', 'Y_in'));
p.addOptional('ds', '/Y', @(x) is_valid_group(convertStringsToChars(x)));
p.addOptional('overwrite', 0, @(x) validateattributes(x, {'scalar', 'positive'}));
p.addOptional('target_chunk_mb', 4, @(x) validateattributes(x,{'numeric','scalar'},{'positive'}));

p.parse(file,Y_in,varargin{:});
target_chunk_mb = p.Results.target_chunk_mb;
ds = p.Results.ds;
overwrite = p.Results.overwrite;

%% Setup Arguments ------

file = convertStringsToChars(file);
ds = convertStringsToChars(ds);
Y_in = squeeze(Y_in);
cl = class(Y_in);

element_size_map = containers.Map(...
    {'double', 'single', 'uint64', 'int64', 'uint32', 'int32', 'uint16', 'int16', 'uint8', 'int8', 'char'}, ...
    [8, 4, 8, 8, 4, 4, 2, 2, 1, 1, 1]);

%% Setup Arguments ------

if isKey(element_size_map, cl)
    element_size = element_size_map(cl);
else
    error('Unsupported data type: %s', cl);
end

sizY = size(Y_in);
num_elements_per_image = prod(sizY(1:end-1));
imageSizeBytes = num_elements_per_image * element_size;
current_position = 0;
prev_size = 0;

target_chunk_size = target_chunk_mb * 1024 * 1024; % 4 MB
num_images_per_chunk = round(target_chunk_size / imageSizeBytes);

% at least one image per chunk, at most the largest dim size
num_images_per_chunk = max(1, num_images_per_chunk);
num_images_per_chunk = min(max(sizY), num_images_per_chunk);

chunk_size = [sizY(1:end-1), num_images_per_chunk];

valid_ds = is_valid_dataset(file, ds);
if ~valid_ds
    try
        h5info(file, ds); % even if its data is corruot check it exists
    catch
        h5create(file, ds, [sizY(1:end-1), Inf], 'ChunkSize', chunk_size, 'Datatype', cl);
    end
end

if ~overwrite
    prev_size = h5info(file, ds).Dataspace.Size;
    if ~isequal(prev_size(1:end-1), sizY(1:end-1))
        error('Dataset dimensions do not align.');
    end
    current_position = prev_size(end);
end

while current_position < prev_size(end) + sizY(end)
    chunk_end = min(current_position + num_images_per_chunk, prev_size(end) + sizY(end));
    if ndims(Y_in) == 3
        chunk_data = Y_in(:, :, current_position - prev_size(end) + 1:chunk_end - prev_size(end));
    elseif ndims(Y_in) == 4
        chunk_data = Y_in(:, :, :, current_position - prev_size(end) + 1:chunk_end - prev_size(end));
    end

    if ismatrix(chunk_data)
        % start = [1 1];
        % chunk_data = reshape(chunk_data, [size(chunk_data, 1), size(chunk_data, 2) 1]);
        % h5write(file, ds, chunk_data);
        return
    else 
        start = [ones(1, ndims(Y_in)-1), current_position + 1];
    end
    h5write(file, ds, chunk_data, start, size(chunk_data));
    current_position = chunk_end;
end
