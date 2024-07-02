function write_frames_to_h5(file, Y_in, chunk, dataset_name)
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
% chunk : int, optional
%     The size of the chunks in which data will be written. Default is 2000.
% dataset_name : char, optional
%     The name of the dataset within the HDF5 file. Default is '/Y'.
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
%     write_frames_to_h5('data.h5', my_data, 100); % for smaller files
%
% Write a 3D array to an HDF5 file with a specified dataset name:
%
%     write_frames_to_h5('data.h5', my_data, 2000, '/Y');
%
% See also
% --------
% h5create, h5write
if ~exist('dataset_name','var') || isempty(dataset_name);dataset_name = '/Y';end
if ~exist('chunk','var') || isempty(chunk) chunk = 2000; end
keep_reading = true;
cl = class(Y_in);
nd = ndims(Y_in) - 1;
sizY = size(Y_in);

if sizY(end) < chunk+1
    keep_reading = false;
else
    if nd == 2
        Y_in(:,:,end) = [];
    elseif nd == 3
        Y_in(:,:,:,end) = [];
    end
    sizY(end) = sizY(end)-1;
end

h5_filename = file;
h5create(h5_filename,dataset_name,[sizY(1:nd),Inf],'Chunksize',[sizY(1:nd),min(chunk,sizY(end))],'Datatype',cl);
h5write(h5_filename,dataset_name,Y_in,[ones(1,nd),1],sizY);
cnt = sizY(end);
while keep_reading
    Y_in = read_file(file,cnt+1,chunk+1);
    sizY = size(Y_in);
    if sizY(end) < chunk+1
        keep_reading = false;
    else
        if nd == 2
            Y_in(:,:,end) = [];
        elseif nd == 3
            Y_in(:,:,:,end) = [];
        end
        sizY(end) = sizY(end)-1;
    end
    h5write(h5_filename,dataset_name,Y_in,[ones(1,nd),cnt+1],sizY);
    cnt = cnt + sizY(end);
end
