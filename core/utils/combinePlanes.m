% COMBINEPLANES Combines all frames for a single Z-Plane.
%
% This function combines the planes for each file in the specified HDF5 file
% and gathers the relevant metadata into a structured format. The combined 
% data and metadata are returned as outputs.
%
% Parameters
% ----------
% h5path : char
%     Path to the HDF5 file containing the extracted data.
% plane : int
%     The Z-Plane index to return.
%
% Returns
% -------
% Y : single array
%     Combined volumetric time-series data with dimensions [Y, X, Z, T].
% metadata : struct
%     Struct containing metadata retrieved from the HDF5 file.
%
% Notes
% -----
% - The HDF5 file should follow the format where each file group contains 
%   multiple plane datasets.
% - This function assumes that all necessary metadata attributes are 
%   present in the HDF5 file.
%
% See also H5INFO, H5READ, H5READATT, FULLFILE, ZEROS, SINGLE

function [Y, metadata] = combinePlanes(h5path, plane)
    % Load metadata
    h5data = h5info(h5path);
    groups = h5data.Groups;
    num_files = length(groups);
    
    metadata = struct();
    
    % Process each file group to gather metadata
    for file_idx = 1:num_files
        file_info = groups(file_idx);
        planes = file_info.Datasets;
        for j = 1:length(planes)
            loc_plane = sprintf("/plane_%d", j);
            full_path = sprintf("%s%s", file_info.Name, loc_plane);
            datasetInfo = h5info(h5path, full_path);
            for k = 1:length(datasetInfo.Attributes)
                attrName = datasetInfo.Attributes(k).Name;
                attrValue = h5readatt(h5path, full_path, attrName);
                metadata.(matlab.lang.makeValidName(attrName)) = attrValue;
            end
        end
    end
    num_planes = metadata.num_planes;
    num_frames_file = metadata.num_frames_file;
    num_frames_total = metadata.num_frames_total;

    % preinitialize the array
    Y = zeros([metadata.image_size(1), metadata.image_size(2), num_frames_total], 'single');

    % Combine the planes for each file
    for file_idx = 1:num_files
            file_group = sprintf("/file_%d/plane_%d", file_idx, plane);
            Y(:, :, (file_idx-1)*num_frames_file+1:file_idx*num_frames_file) = im2single(h5read(h5path, file_group));
    end
end
