function = display_dataset_names(h5_fullfile)
% display_dataset_names Display available datasets in an HDF5 file.
%
% This function displays the names, sizes, and datatypes of datasets in the
% root group of the specified HDF5 file.
%
% Parameters
% ----------
% h5_fullfile : char
%     Full path to the HDF5 file.
%
% Notes
% -----
% This function is useful for identifying available datasets in an HDF5 file
% when the specified dataset name is not found.
%
% Example
% -------
% display_dataset_names('path/to/file.h5')
%
% See also H5INFO, H5READ
root_info = h5info(h5_fullfile, '/');
fprintf('Available datasets at root "/":\n');
for i = 1:length(root_info.Datasets)
    ds = root_info.Datasets(i);
    fprintf('Name: %s, Size: [%s], Datatype: %s\n', ...
        ds.Name, num2str(ds.Dataspace.Size), ds.Datatype.Class);
end