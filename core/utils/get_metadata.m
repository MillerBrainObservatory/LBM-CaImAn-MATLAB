function [metadata_out] = get_metadata(filename)
%GET_METADATA Extract metadata quickly from a ScanImage TIFF file.
%
% Read and parse Tiff metadata stored in the .tiff header
% and ScanImage metadata stored in the 'Artist' tag which contains roi sizes/locations and scanning configuration
% details in a JSON format.
%
% Parameters
% ----------
% filename : char
%     The full path to the TIFF file from which metadata will be extracted.
%
% Returns
% -------
% metadata_out : struct
%     A struct containing metadata such as center and size of the scan field,
%     pixel resolution, image dimensions, number of frames, frame rate, and
%     additional roi data extracted from the TIFF file.
%
% Examples
% --------
% metadata = get_metadata("path/to/file.tif");
%
% Requires
% --------
% - Image Processing Toolbox
% - MOST toolbox for JSON decoding or an alternative JSON parser
%
% See also TIFF, MOST.JSON.LOADJSON
hTiff = Tiff(filename);
[fpath, fname, fext] = fileparts(filename);

% Metadata in JSON format stored by ScanImage in the 'Artist' tag
roistr = hTiff.getTag('Artist');
roistr(roistr == 0) = []; % Remove null termination from string
mdata = most.json.loadjson(roistr); % Decode JSON string to structure
mdata = mdata.RoiGroups.imagingRoiGroup.rois; % Pull out a single roi, assumes they will always be the same
num_rois = length(mdata); % only accurate way to determine the number of ROI's
mdata = mdata{:};
scanfields = mdata.scanfields;

% roi (scanfield) metadata, gives us pixel sizes
center_xy = scanfields.centerXY;
size_xy = scanfields.sizeXY;
num_pixel_xy = scanfields.pixelResolutionXY; % misleading name

% TIFF header data for additional metadata
[header, ~] = scanimage.util.private.getHeaderData(hTiff);
sample_format = hTiff.getTag('SampleFormat'); % raw data type, scanimage uses int16

switch sample_format
    case 1
        sample_format = 'uint16';
    case 2
        sample_format = 'int16';
otherwise
    error('Invalid image datatype')
end

% Extracting frame and plane information from the header
num_frames_total = header.SI.hStackManager.framesPerSlice; % the total number of frames for this imaging session
num_frames_file = header.SI.hScan2D.logFramesPerFile; % the number of frames in each .tiff files if chosen by the user
num_planes = length(header.SI.hChannels.channelSave); % an array of active channels: channels are where information from each light bead is stored
num_files = num_frames_total / num_frames_file;

% Lines / Pixel values stored in scanimage frame descriptions
lines_per_frame = header.SI.hRoiManager.linesPerFrame; % essentially gives our "raw roi width"
num_lines_between_scanfields = round(header.SI.hScan2D.flytoTimePerScanfield / header.SI.hRoiManager.linePeriod);

% Calculate using frame rate and field-of-view
line_period = header.SI.hRoiManager.linePeriod;
scan_frame_period = header.SI.hRoiManager.scanFramePeriod;
frame_rate = header.SI.hRoiManager.scanVolumeRate;
objective_resolution = header.SI.objectiveResolution;

fovx = round(objective_resolution * size_xy(1) * num_rois); % account for the x extent being a single roi
fovy = round(objective_resolution * size_xy(2));
fov_xy = [fovx fovy];

fov_roi = round(objective_resolution * size_xy); % account for the x extent being a single roi
pixel_resolution = mean(fov_roi ./ num_pixel_xy);

% Number of pixels in X and Y
roi_width_px = num_pixel_xy(1);
roi_height_px = num_pixel_xy(2);

metadata_out = struct( ...
    'center_xy', center_xy, ...
    'line_period', line_period, ...
    'scan_frame_period', scan_frame_period, ...
    'size_xy', size_xy, ...
    'num_pixel_xy', num_pixel_xy, ...
    'lines_per_frame', lines_per_frame, ...
    'num_lines_between_scanfields', num_lines_between_scanfields, ...
    'roi_width_px', roi_width_px, ...
    'roi_height_px', roi_height_px,  ...
    'num_planes', num_planes, ...
    'num_rois', num_rois, ...
    'num_frames_total', num_frames_total, ...
    'num_frames_file', num_frames_file, ...
    'num_files', num_files, ...
    'frame_rate', frame_rate, ...
    'objective_resolution', objective_resolution, ...
    'fov', fov_xy, ...
    'pixel_resolution', pixel_resolution, ...
    'sample_format', sample_format, ...
    'raw_filename', fname, ...
    'raw_filepath', fpath, ...
    'raw_fullfile', filename ...
    );

end
