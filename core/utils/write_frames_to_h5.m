function write_frames_to_h5(file, Y_in, ds)
% Write in-memory 3D or 4D data to an HDF5 file in chunks.
%
% This function writes a multidimensional array `Y_in` to an HDF5 file specified
% by `file` in chunks. It creates a dataset within the HDF5 file and writes the
% data in specified chunk sizes. If `dataset_name` is not provided, it defaults
% to '/Y'. If `chunk` size is not provided, it defaults to 2000.
%
% Parameters
% ----------
% file : char
%     The name of the HDF5 file to write to.
% Y_in : array
%     The multidimensional array to be written to the HDF5 file.
% ds : char, optional
%     The name of the dataset group within the HDF5 file. Default is '/Y'.
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
%     write_frames_to_h5('data.h5', my_data);
%
% Write a 4D array to an HDF5 file with a specified chunk size:
%
%     write_frames_to_h5('data.h5', my_data);
%
% Write a 3D array to an HDF5 file with a specified dataset name:
%
%     write_frames_to_h5('data.h5', my_data,'/Y');
%
% See also
% --------
% h5create, h5write
if nargin > 0
    file = convertStringsToChars(file);
end

if nargin > 1
    Y_in = convertStringsToChars(Y_in);
end

if nargin > 2
    ds = convertStringsToChars(ds);
end

if ~exist('ds', 'var') || isempty(ds)
    ds = '/Y';
end

p = inputParser;
p.addRequired('file', ...
    @(x) validateattributes(x, {'char', 'string'}, {'nonempty', 'scalartext'}, '', 'file'));
p.addRequired('Y_in', ...
    @(x) validateattributes(x, {'numeric'}, {'nonempty'}, '', 'Y_in'));
p.addOptional('ds', '/Y', ...
    @(x) validateattributes(x, {'char', 'string'}, {'nonempty', 'scalartext'}, '', 'ds'));

p.parse(file, Y_in, ds);
options = p.Results;

keep_reading = true;
cl = class(Y_in);
nd = ndims(Y_in) - 1;
sizY = size(Y_in);

% if sizY(end) < chunk + 1
%     keep_reading = false;
% else
%     if nd == 2
%         Y_in(:, :, end) = [];
%     elseif nd == 3
%         Y_in(:, :, :, end) = [];
%     end
%     sizY(end) = sizY(end) - 1;
% end

h5_filename = options.file;
dataset_exists = false;
try
    h5info(h5_filename, options.ds);
    dataset_exists = true;
catch
    % Dataset does not exist
end

imageSizeMBytes = (prod(sizY(1:2)) * 2) / 1e6;
chunk_size = round(4/imageSizeMBytes);

if ~dataset_exists
    h5create(h5_filename,options.ds,[sizY(1:nd), Inf],'ChunkSize',[size(1:nd) chunk_size],'Datatype',cl);
    h5write(h5_filename, options.ds, Y_in);
else
    dset_info = h5info(h5_filename, options.ds);
    current_size = dset_info.Dataspace.Size;
    % Extend the dataset
    h5write(h5_filename, options.ds, Y_in, [ones(1, nd), current_size(end) + 1], sizY);
end

cnt = sizY(end);
while keep_reading
    Y_in = read_file(options.file, cnt + 1, chunk + 1);
    sizY = size(Y_in);
    if sizY(end) < chunk + 1
        keep_reading = false;
    else
        if nd == 2
            Y_in(:, :, end) = [];
        elseif nd == 3
            Y_in(:, :, :, end) = [];
        end
        sizY(end) = sizY(end) - 1;
    end
    h5write(h5_filename, options.ds, Y_in, [ones(1, nd), cnt + 1], sizY);
    cnt = cnt + sizY(end);
end

end
