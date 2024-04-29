function [metadata_out] = get_metadata(filename)
%GET_METADATA Extract metadata quickly from a ScanImage TIFF file.
% 
% Read and parse Tiff metadata stored in the .tiff header
% and ScanImage metadata stored in the 'Artist' tag which contains ROI sizes/locations and scanning configuration
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
%     additional ROI data extracted from the TIFF file.
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
[fpath, fname, ext] = fileparts(filename);

% Metadata in JSON format stored by ScanImage in the 'Artist' tag
roiStr = hTiff.getTag('Artist'); 
roiStr(roiStr == 0) = []; % Remove null termination from string
mdata = most.json.loadjson(roiStr); % Decode JSON string to structure
mdata = mdata.RoiGroups.imagingRoiGroup.rois; % Pull out a single ROI, assumes ROIs will always be the same
num_rois = length(mdata); % only accurate way to determine the number of ROI's
mdata = mdata{:};
scanfields = mdata.scanfields;

% ROI (scanfield) metadata, gives us pixel sizes 
center_xy = scanfields.centerXY;
size_xy = scanfields.sizeXY;
num_pixel_xy = scanfields.pixelResolutionXY; % misleading name

% TIFF header data for additional metadata
[header, ~] = scanimage.util.private.getHeaderData(hTiff);
image_length = hTiff.getTag('ImageLength'); % Image height in pixels
image_width = hTiff.getTag('ImageWidth'); % Image width in pixels
sample_format = hTiff.getTag('SampleFormat'); % raw data type, scanimage uses uint16

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
lines_per_frame = header.SI.hRoiManager.linesPerFrame; % essentially gives our "raw ROI width"
pixels_per_line = header.SI.hRoiManager.pixelsPerLine; % unknown exactly what this represents
num_lines_between_scanfields = round(header.SI.hScan2D.flytoTimePerScanfield / header.SI.hRoiManager.linePeriod);

% Calculate using frame rate and field-of-view
frame_rate = header.SI.hRoiManager.scanVolumeRate;
objective_resolution = header.SI.objectiveResolution;
fov = round(objective_resolution .* size_xy);
pixel_resolution = mean(fov ./ num_pixel_xy);

% Strip sizes
extra_width_px = (lines_per_frame-pixels_per_line);
extra_width_per_side_px = extra_width_px / 2;
strip_width_slice = (extra_width_per_side_px:num_pixel_xy(1)-extra_width_per_side_px);
strip_width = numel(strip_width_slice);

raw_roi_width = num_pixel_xy(1);
raw_roi_height = num_pixel_xy(2);

trim_roi_width_start = 6;
trim_roi_width_end = raw_roi_width - 6;

new_roi_width_range = trim_roi_width_start:trim_roi_width_end;
new_roi_width = size(new_roi_width_range, 2);

trim_roi_height_start = round(raw_roi_height*0.03);

full_image_height = raw_roi_height - (trim_roi_height_start-1);
full_image_width = new_roi_width*num_rois;

metadata_out = struct( ...
    ... % raw image sizes
    'center_xy', center_xy, ...
    'size_xy', size_xy, ...
    'num_pixel_xy', num_pixel_xy, ...
    'lines_per_frame', lines_per_frame, ...
    'pixels_per_line', pixels_per_line, ...
    'num_lines_between_scanfields', num_lines_between_scanfields, ...
    'image_length', image_length, ...
    'image_width', image_width,  ...
    'full_image_height', full_image_height, ...
    'full_image_width', full_image_width, ...
    ... % volume sizes
    'num_planes', num_planes, ...
    'num_rois', num_rois, ...
    'num_frames_total', num_frames_total, ...
    'num_frames_file', num_frames_file, ...
    'num_files', num_files, ...
    ... % 
    'frame_rate', frame_rate, ...
    'objective_resolution', objective_resolution, ...
    'fov', fov, ...
    'strip_width_slice', strip_width_slice, ...
    'strip_width', strip_width, ...
    'pixel_resolution', pixel_resolution, ...
    'sample_format', sample_format, ...
    'extra_width_px', extra_width_px, ...
    'extra_width_per_side_px', extra_width_per_side_px, ...
    'base_filename', fname, ...
    'base_filepath', fpath, ...
    'base_fileext', ext ...
    );

end