function [metadata_out] = get_metadata(filename)
%GET_METADATA   Extract metadata quickly from a ScanImage TIFF file from just
%               the filename
%   >> metadata = get_metadata("fullfile("../benchmarks/high_resolution/MH70_0p6mm_FOV_50_550um_depth_som_stim_199mW_3min_M1_00001_00001.tif"))
%      metadata =     
%            struct with fields:
%                        center_xy: [-1.4286 0]
%                          size_xy: [0.9524 3.8095]
%                     num_pixel_xy: [144 600]
%                     image_length: 2478
%                      image_width: 145
%                       num_frames: 1730
%                       num_planes: 30
%                  lines_per_frame: 144
%                  pixels_per_line: 128
%     num_lines_between_scanfields: 24
%                       frame_rate: 9.6081
%             objective_resolution: 157.5000
%                              fov: [150 600]
%                 pixel_resolution: 1.0208
%                       img_size_y: 583
%                       img_size_x: 528
%   

% Read TIFF file and extract ROI information from the 'Artist' tag
hTiff = Tiff(filename);
roiStr = hTiff.getTag('Artist'); % Metadata in JSON format stored by ScanImage in the 'Artist' tag
roiStr(roiStr == 0) = []; % Remove null termination from string
mdata = most.json.loadjson(roiStr); % Decode JSON string to structure
mdata = mdata.RoiGroups.imagingRoiGroup.rois;
num_rois = length(mdata); % Number of ROIs
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
sample_format = hTiff.getTag('SampleFormat');
switch sample_format
    case 1
        sample_format = 'uint16';
    case 2
        sample_format = 'int16';
otherwise
    error('Invalid image datatype')     
end

% Extracting frame and channel information from the header
num_frames = header.SI.hStackManager.framesPerSlice;
num_planes = length(header.SI.hChannels.channelSave);

% More metadata extraction
lines_per_frame = header.SI.hRoiManager.linesPerFrame;
pixels_per_line = header.SI.hRoiManager.pixelsPerLine;
num_lines_between_scanfields = round(header.SI.hScan2D.flytoTimePerScanfield / header.SI.hRoiManager.linePeriod);

% Usingrame rate and field-of-view
frame_rate = header.SI.hRoiManager.scanVolumeRate;
objective_resolution = header.SI.objectiveResolution;
fov = round(objective_resolution .* size_xy);
pixel_resolution = mean(fov ./ num_pixel_xy);

% Image sizes 
img_size_y = num_pixel_xy(2) - ((num_pixel_xy(2)*0.03)-1);
img_size_x = (129) * num_rois; 

% Strip sizes
extra_width_px = (lines_per_frame-pixels_per_line);
extra_width_per_side_px = extra_width_px / 2;
strip_width_slice = (extra_width_per_side_px:num_pixel_xy(1)-extra_width_per_side_px); 
strip_width = numel(strip_width_slice);

metadata_out = struct('center_xy', center_xy, 'size_xy', size_xy, 'num_pixel_xy', num_pixel_xy, ...
    'image_length', image_length, 'image_width', image_width, 'num_frames', num_frames, ...
    'num_planes', num_planes,'num_rois', num_rois, 'lines_per_frame', lines_per_frame, ...
    'pixels_per_line', pixels_per_line, 'num_lines_between_scanfields', num_lines_between_scanfields, ...
    'frame_rate', frame_rate, 'img_size_y', img_size_y, 'img_size_x', img_size_x, ...
    'objective_resolution', objective_resolution, 'fov', fov, ...
    'strip_width_slice', strip_width_slice,'strip_width', strip_width,  'pixel_resolution', pixel_resolution, 'sample_format', ...
    sample_format, 'extra_width_px', extra_width_px, 'extra_width_per_side_px', extra_width_per_side_px);

end