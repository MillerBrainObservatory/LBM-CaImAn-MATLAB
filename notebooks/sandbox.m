%%
parent_path = fullfile('E:\bi_hemi\mh89_2mm_FOV_50_550um_depth_250mW_som_stimuli_9min_00001_00001.tif');

mdata = get_metadata(parent_path);
mdata.uniform_sampling
%%
segmentation_path = fullfile(parent_path, 'segmentation_roi2');
segmentation_file = fullfile(segmentation_path, 'segmented_plane_14.h5');

% Specify your HDF5 file name 
filename = segmentation_file;
% Get info about the HDF5 file 
info = h5info(filename); 
% Preallocate a cell array to hold your data 
data = struct(); 
% Loop through each group 
for i = 1:length(info.Datasets) 
    group_name = info.Datasets(i).Name; 
    group_value = info.Datasets(i).Datatype;
    data.(group_name) = h5read(filename, sprintf("/%s",group_name)); % Create a struct for the group 
end
