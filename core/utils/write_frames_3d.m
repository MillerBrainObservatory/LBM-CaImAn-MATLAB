function write_frames_3d(file,Y_in,ds,append,chunk_mb)
% Write in-memory 3D or 4D data to an HDF5 file in chunks.
%
% This function writes a multidimensional array `Y_in` to an HDF5 file specified
% by `file` in chunks. It creates a dataset within the HDF5 file and writes the
% data in specified chunk sizes. If `dataset_name` is not provided, it defaults
% to '/Y'. If target_chunk_mb size is not provided, it defaults to 4MB.
%
% Parameters
% ----------
% file : char
%     The name of the HDF5 file to write to.
% Y_in : array
%     The multidimensional array to be written to the HDF5 file.
% ds : char, optional
%     The name of the dataset group within the HDF5 file. Default is '/Y'.
% append : logical, optional
%     Whether to append to an existing HDF5 dataset. Dims must match.
%     Default is false.
% chunk_mb : int, optional
%     In MB, the chunk_size to include in each HDF5 write. Default is 4MB.
%
% Notes
% -----
% This function trims the last frame of each chunk if the chunk size
% exceeds the remaining data size.
%
% Examples
% --------
% Write a 3D array to an HDF5 file with default chunk size and dataset name:
%
%     write_frames('data.h5', my_data);
%
% Write a 4D array to an HDF5 file with a specified chunk size:
%
%     write_frames('data.h5', my_data, 2); % 2MB chunks
%
% Write a 3D array to an HDF5 file with a specified dataset name:
%
%     write_frames('data.h5', my_data, '/Y', 2, true, false);

p = inputParser;
p.addRequired('file', @(x) validateattributes(x, {'char', 'string'}, {'nonempty', 'scalartext'}, '', 'file'));
p.addRequired('Y_in', @(x) validateattributes(x, {'numeric'}, {'nonempty'}, '', 'Y_in'));
p.addRequired('ds', @(x) is_valid_group(convertStringsToChars(x)));
p.addOptional('append', 0);
p.addOptional('chunk_mb', 4);

p.parse(file,Y_in,ds,append,chunk_mb);
chunk_mb = p.Results.chunk_mb;
ds = p.Results.ds;
append = p.Results.append;

%% Setup Arguments ------

file = convertStringsToChars(file);
ds = convertStringsToChars(ds);
Y_in = squeeze(Y_in);
cl = class(Y_in);

element_size_map = containers.Map(...
    {'double', 'single', 'uint64', 'int64', 'uint32', 'int32', 'uint16', 'int16', 'uint8', 'int8', 'char'}, ...
    [8, 4, 8, 8, 4, 4, 2, 2, 1, 1, 1]);

if isKey(element_size_map, cl)
    element_size = element_size_map(cl);
else
    error('Unsupported data type: %s', cl);
end

%% Calculate chunk size (how many images to pack into 3rd dimension ------

sizY = size(Y_in);
ndY = numel(sizY);
nd = ndY-1;
if ndY == 3
    num_elements_per_image = prod(sizY(1:nd));
    imageSizeBytes = num_elements_per_image * element_size;
    target_chunk_size = chunk_mb * 1024 * 1024; % 4 MB
    
    num_images_per_chunk = round(target_chunk_size / imageSizeBytes);
    
    % at least one image per chunk, at most the largest dim size
    num_images_per_chunk = max(1,  min(max(sizY), num_images_per_chunk));
    num_images_per_chunk = min(max(sizY), num_images_per_chunk);
    num_images_per_chunk = findClosestDivisor(num_images_per_chunk, size(Y_in, ndY)); %make it even
    % make sure we have an even number of images so our dimensions match
    % i.e. we avoid writing a 2D image to a 3D dataset. 
    chunk_size = [sizY(1:nd), num_images_per_chunk];
end

try
    h5info(file, ds);
    valid_ds = true;
catch
    valid_ds = false;
end

if ~valid_ds % if there is no dataset, none of the other checks matter
    if ndY == 3
        h5create(file, ds, [sizY(1:nd), Inf], 'ChunkSize', chunk_size, 'Datatype', cl);
    elseif ndY == 2
        h5create(file, ds, sizY, 'Datatype', cl);
    end
    prev_size = 0;
    current_position = 0;
elseif append
    if ndY == 2
        error("Appending on 2d datasets is not yet supported by this pipeline.")
    end
    if ~isempty(prev_ind)
        current_position=prev_ind;
    else
        prev_size = h5info(file, ds).Dataspace.Size;
        if ~isequal(prev_size(1:end-1), sizY(1:end-1))
            error('Dataset dimensions do not align.');
        end
        current_position = prev_size(end);
    end
else
    disp("User set append=false, but the dataset exists, skipping this dataset.");
    return
end

if ndY == 2
    h5write(file, ds, Y_in);
else
    while current_position < prev_size(end) + sizY(end)
        chunk_end = min(current_position + num_images_per_chunk, prev_size(end) + sizY(end));
        chunk_data = Y_in(:, :, current_position - prev_size(end) + 1:chunk_end - prev_size(end));
        start = [ones(1, nd), current_position + 1];
        h5write(file, ds, chunk_data, start, size(chunk_data));
        current_position = chunk_end;
    end
end
end
function closestDivisor = findClosestDivisor(N, M, minThreshold)
    if ~exist('minThreshold', 'var');minThreshold=2;end
    closestDivisor = 1;
    minDifference = inf;

    % iterate over possible divisors
    for i = 1:M
        if mod(M, i) == 0
            % calculate chunk size for this divisor
            chunkSize = M / i;
            if chunkSize >= minThreshold
                difference = abs(N - i);
                if difference < minDifference
                    closestDivisor = i;
                    minDifference = difference;
                end
            end
        end
    end

    % if no valid divisor was found, use the closest divisor without threshold
    if closestDivisor == 1
        for i = 1:M
            if mod(M, i) == 0
                difference = abs(N - i);
                if difference < minDifference
                    closestDivisor = i;
                    minDifference = difference;
                end
            end
        end
    end
end

