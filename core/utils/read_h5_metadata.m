function metadata = read_h5_metadata(h5_fullfile, loc)
% Reads metadata from an HDF5 file.
%
% Reads the metadata attributes from a specified location within an HDF5 file
% and returns them as a structured array.
%
% Parameters
% ----------
% h5_fullfile : char
%     Full path to the HDF5 file from which to read metadata.
% loc : char, optional
%     Location within the HDF5 file from which to read attributes. Defaults to '/'.
%
% Returns
% -------
% metadata : struct
%     A structured array containing the metadata attributes and their values
%     read from the HDF5 file.
%
% Examples
% --------
% Read metadata from the root location of an HDF5 file:
%     metadata = read_h5_metadata('example.h5');
%
% Read metadata from a specific group within an HDF5 file:
%     metadata = read_h5_metadata('example.h5', '/group1');
%
% Notes
% -----
% The function uses `h5info` to retrieve information about the specified location
% within the HDF5 file and `h5readatt` to read attribute values. The attribute names
% are converted to valid MATLAB field names using `matlab.lang.makeValidName`.

if ~exist('h5_fullfile', 'var'); h5_fullfile = uigetfile('title', 'Select a processed h5 dataset:'); end
if ~exist('loc', 'var'); loc = '/'; end
try
    h5_data = h5info(h5_fullfile, loc);
catch
    error("File %s does not exist with group %s. ", h5_fullfile, loc);
end
metadata = struct();
% find valid dataset if empty
if isempty(h5_data.Attributes)
    if loc ~= "/"
        fprintf("WARNING! Attempt made to read an unknown dataset: %s.\nAttempting with the root dataset '/'...\n", loc);
        h5_data = h5info(h5_fullfile, "/");
        if isempty(h5_data.Attributes)
            error("Given group %s does not exist in file: %s", loc, h5_fullfile);
        else
            fprintf("Woo! Metadata found in the root '/' group of the dataset.\n");
        end
    else
        % h5_data = h5info(h5_fullfile, "/");
        fprintf("No valid metadata in the root group or in group %s for file:\n %s\n", loc, h5_fullfile);
        return
    end
end
for k = 1:numel(h5_data.Attributes)
    attr_name = h5_data.Attributes(k).Name;
    attr_value = h5readatt(h5_fullfile, ['/' h5_data.Name], attr_name);
    metadata.(matlab.lang.makeValidName(attr_name)) = attr_value;
end

if isempty(metadata)
    error("No valid metadata:\nFile: %s\nLocation: %s\n", h5_fullfile, loc)
end
