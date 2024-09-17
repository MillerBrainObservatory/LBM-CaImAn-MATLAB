function write_frames_to_mp4(data, filename, frame_rate, x, y)
% Write a 3D array to an MP4 video file.
%
% This function takes a 3D numeric array `data` and writes it to an MP4 video
% file specified by `filename`. The video is created with the specified frame
% rate and spatial dimensions `x` and `y`.
%
% Parameters
% ----------
% data : numeric array
%     A 3D array containing the data to be written to the video file.
% filename : char
%     The name of the output MP4 video file.
% frame_rate : double, optional
%     The frame rate of the video. Default is 1.
% x : double array, optional
%     The x-coordinates for the spatial dimensions of the data. Default is
%     1:size(data,2).
% y : double array, optional
%     The y-coordinates for the spatial dimensions of the data. Default is
%     1:size(data,1).
%
% Notes
% -----
% The function normalizes the data, applies a moving mean filter, and writes
% the frames to an MP4 video file with minimal compression. The video will not
% be shown during processing.
%
% Examples
% --------
% Write a 3D array to an MP4 file with default settings:
%
%     write_frames_to_mp4(my_data, 'output.mp4');
%
% Write a 3D array to an MP4 file with a specified frame rate:
%
%     write_frames_to_mp4(my_data, 'output.mp4', 10);
%
% Write a 3D array to an MP4 file with specified spatial dimensions:
%
%     write_frames_to_mp4(my_data, 'output.mp4', 10, 1:256, 1:256);

arguments
    data {mustBeNumeric}
    filename (1,:) char
    frame_rate (1,1) double {mustBeNumeric, mustBePositive} = 1
    x (:,1) double {mustBeNumeric} = 1:size(data,2)
    y (:,1) double {mustBeNumeric} = 1:size(data,1)
end

if nargin < 5 || isempty(y)
    y = 1:size(data,1);
end
if nargin < 4 || isempty(x)
    x = 1:size(data,2);
end
if nargin < 3 || isempty(frame_rate)
    frame_rate = 10;
end
if nargin < 2
    error('Filename must be provided');
end
if nargin < 1
    error('Data must be provided');
end

avgs = 1;
buffer = 3;

[N,bns] = histcounts(data(:), 'normalization', 'cdf');
ind1 = dsearchn(N', 0.1);
ind2 = dsearchn(N', 0.995);
cax = [bns(ind1) bns(ind2)];

data = movmean(data, avgs, 3);
numFrames = size(data, 3);

% Replace VideoWriter with MP4 format
writer_obj = VideoWriter(filename, 'MPEG-4');
writer_obj.FrameRate = frame_rate;
open(writer_obj)

disp('Beginning processing to save as mp4');

for k = 1:numFrames
    % Process each frame
    I = data(:,:,k);
    
    % Normalize the frame
    imagesc(x, y, I, 'CDataMapping', 'scaled');
    axis image off;
    colormap(gray);
    caxis(cax);
    
    % Capture frame without displaying the figure
    frame = getframe(gca);
    
    % Write frame to video file
    writeVideo(writer_obj, frame);
end

% Finalize the video file
close(writer_obj);

% Log final output
disp(['Finished writing video to: ', filename]);

end
