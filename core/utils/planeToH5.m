function planeToH5(frames, folder, filename, metadata, nvargs)
% 
% Save 3D array of image frames to an HDF5 file in various organizational schemes.
% 
% Parameters
% ----------
% frames : uint16 array
%     3D time-series of image data for a single recording plane.
%     Each slice along the third dimension represents one image frame (timepoint).
% folder : string
%     Directory path where the HDF5 file will be saved. Must already exist.
% filename : string
%     Base name of the HDF5 file to create or append to. Automatically appends ".h5" if not included.
% metadata : struct
%     Structure containing metadata to be saved as attributes in the HDF5 file.
% nvargs : struct (optional)
%     Structure containing named variables:
%         dataset : string
%             Name of the dataset within the HDF5 file.
%         groupPath : string
%             HDF5 internal path (group) where the dataset is stored.
%         fileMode : string
%             Can be 'separate' (default), 'singleGroup', or 'multiGroup'.
%         chunksize : double array
%             Size of data chunks for HDF5 storage.
%         compression : double
%             Compression level for the data.
% 
% Notes
% -----
% The 'fileMode' determines how data is organized:
%     'separate' : Each plane in a separate file.
%     'singleGroup' : All planes in the same group but different datasets.
%     'multiGroup' : All planes in different groups within the same file.
%
arguments
    frames {mustBeA(frames, "uint16")}
    folder (1,1) string 
    filename (1,1) string % File name without extension
    metadata (1,1) struct % Metadata values
    nvargs.dataset (1,1) string = "/Y"
    nvargs.groupPath (1,1) string = "/"
    nvargs.fileMode (1,1) string = "separate"
    nvargs.chunksize (1,:) double = [size(frames, 1), size(frames, 2), 1]
    nvargs.compression (1,1) double = 0
end

%% Validate and possibly create folder
fullFolderPath = fullfile(folder);
[parentFolderPath, ~, ~] = fileparts(fullFolderPath);

if ~isfolder(parentFolderPath)
    error("The parent directory of the specified folder does not exist: %s", parentFolderPath);
end

if ~isfolder(fullFolderPath)
    mkdir(fullFolderPath);
end

%% File path setup
baseFilename = regexprep(filename, "(?i)(\.h5)?$", "");
fileExtension = ".h5";
finalPath = fullfile(folder, baseFilename + fileExtension);

% file organization modes
switch nvargs.fileMode
    case 'separate'
        % Separate file for each plane
        for plane = 1:size(frames,3)
            planeFilename = sprintf("%s_plane_%d%s", baseFilename, plane, fileExtension);
            finalPath = fullfile(folder, planeFilename);


            writeDataToH5(frames(:,:,plane), finalPath, datasetPath, nvargs, metadata);
        end
    case 'singleGroup'
        % Single file, different datasets for each plane
        datasetPath = nvargs.groupPath;
        for plane = 1:size(frames,3)
            fullDatasetPath = datasetPath + sprintf("/plane_%d", plane);
            writeDataToH5(frames(:,:,plane), finalPath, fullDatasetPath, nvargs, metadata);
        end
    case 'multiGroup'
        % Single file, same dataset name in different groups
        for plane = 1:size(frames,3)
            fullGroupPath = nvargs.groupPath + sprintf("/plane_%d", plane);
            fullDatasetPath = fullGroupPath + nvargs.dataset;
            writeDataToH5(frames(:,:,plane), finalPath, fullDatasetPath, nvargs, metadata);
        end
end


end