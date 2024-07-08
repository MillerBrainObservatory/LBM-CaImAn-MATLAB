function display_dataset_names(h5_fullfile, loc)
% Display available datasets in an HDF5 file.
%
% This function displays the names, sizes, and datatypes of datasets in the
% provided group location in the dataset.
%
% Parameters
% ----------
% h5_fullfile : char
%     Full path to the HDF5 file.
% loc : char
%     Dataset group name. Default is '/'.
%
% Returns
% -------
% None
%

if ~exist('loc', 'var'); loc='/'; end
root_info = h5info(h5_fullfile, loc);
fprintf('Available datasets in %s (group: %s):\n', h5_fullfile, loc);
for i = 1:length(root_info.Datasets)
    ds = root_info.Datasets(i);
    fprintf('Name: %s, Size: [%s], Datatype: %s\n', ...
        ds.Name, num2str(ds.Dataspace.Size), ds.Datatype.Class);
end
