function [frames, metadata] = readPlaneH5(folder, filename, nvargs)
%%
arguments
    folder      (1,1) string    {mustBeFolder}
    filename    (1,1) string    % File name
    nvargs.dataset (1,1) = "/Y"  % Dataset name
end
%% Set file path
filename = regexprep(filename, "(?i)(\.h5)?$", ".h5");
file_path = fullfile(folder, filename);  % Complete file path

%% Check if the file exists
assert(isfile(file_path), compose("File %s does not exist", file_path));

%% Read frames
info = h5info(file_path, nvargs.dataset);
frames = h5read(file_path, nvargs.dataset);

%% Read metadata
metadata = struct();
if isfield(info, 'Attributes')
    for attr = info.Attributes
        metadata.(attr.Name) = attr.Value;
    end
end
%%
end

