function prepH5(frames, folder, filename, metadata, nvargs)
%PREPH5 Save 3D array of image frames to an HDF5 file, optionally appending to an existing file.

%Parameters
%----------
%frames : uint16 array
%    3D time-series of image data for a single recording plane.
%    Each slice along the third dimension represents one image frame (timepoint).
%folder : string
%    The directory path where the HDF5 file will be saved. Throw if doesn't exist.
%filename : string
%    The name of the HDF5 file to create or append to. Automatically appends ".h5" if not included.
%metadata : struct
%    A structure containing metadata to be saved as attributes in the HDF5 file.
%nvargs : struct (optional)
%    A structure containing named variables:
%    dataset : string, default '/Y'
%        The name of the dataset within the HDF5 file.
%    chunksize : double array, default [height(frames), width(frames), 1]
%        The size of data chunks for HDF5 storage. Affects performance and compression.
%    compression : double, default 0
%        Compression level for the data. 0 means no compression, and higher numbers increase compression at the cost of performance.
%
%Returns
%-------
%None

%Raises
%------
%AssertionError
%    If `frames` is not a 3D uint16 array.
%Error
%    If the file specified by `folder` doesn't exist.

%Examples
%--------
%% Create some example data and metadata
%frames = uint16(randi([0, 255], 100, 100, 10));
%metadata = struct('date', '2023-10-01', 'device', 'Camera X');

%% Save data to HDF5
%folder = 'path_to_directory';
%filename = 'example_data';
%nvargs.dataset = '/experiment1';
%nvargs.chunksize = [100, 100, 1];
%nvargs.compression = 5;
%planeToH5(frames, folder, filename, metadata, nvargs);

%Notes
%-----
%If the file already exists and `isfile(final_path)` is true, the function appends the `frames` to the existing dataset specified. It handles creating a new file or appending data based on the existence of the file.
%This function handles both creating a new HDF5 file with the given data and metadata, or appending to an existing file if it already exists. Care must be taken with file paths and ensuring that directories exist before writing files.
%The function uses temporary files during the writing process to avoid corruption of the data in case of errors. The temporary file is moved to the final location after successful writing.
%%}
arguments
	frames		{mustBeA(frames,"uint16")}
	folder		(1,1)	string	{mustBeFolder}
	filename	(1,1)	string	% File name
	metadata	(1,1)	struct	% Struct containing metadata values
	nvargs.dataset		(1,1)	string	= "/Y"
	nvargs.chunksize	(1,:)	double	= [height(frames), width(frames), 1]
	nvargs.compression	(1,1)	double	= 0
end
%% Set file paths
filename = regexprep(filename,"(?i)(\.h5)?$",".h5");
temp_path = tempname(folder)+".h5";
filename = filename+".h5"; % Temporary file
final_path = fullfile(folder,filename);	% Desired final filename
metadata.h5path = final_path;
%% Do some extra validation checks
assert(ndims(frames)==3, "Input frames must be 3D array")
% Throw an error if the destination path already exists
if isfile(final_path)

    %% write frames
    h5write(final_path, nvargs.dataset, frames, 'WriteMode', 'append');

    %% Write metadata
    metadata_fields = string(fieldnames(metadata));
    for f = metadata_fields(:).'
	    h5writeatt(temp_path, nvargs.dataset, f, metadata.(f));
    end
    %% Now rename the file to the actual desired filename
    movefile(temp_path,final_path);

else
    %% Create h5 file
    h5create(...
	    temp_path ...
	    , nvargs.dataset ...
	    , size(frames) ...
	    , datatype	= "uint16" ...
	    , chunksize	= nvargs.chunksize ...
	    , deflate	= nvargs.compression ...
	    );
    %% write frames
    h5write(temp_path, nvargs.dataset, frames);
    %% Write metadata
    metadata_fields = string(fieldnames(metadata));
    for f = metadata_fields(:).'
	    h5writeatt(temp_path, nvargs.dataset, f, metadata.(f));
    end
    %% Now rename the file to the actual desired filename
    movefile(temp_path,final_path);
end
%%
end
