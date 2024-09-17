function write_frames_to_avi(data, filename, frame_rate,x,y)
% Write a 3D array to an AVI video file.
%
% This function takes a 3D numeric array `data` and writes it to an AVI video
% file specified by `filename`. The video is created with the specified frame
% rate and spatial dimensions `x` and `y`.
%
% Parameters
% ----------
% data : numeric array
%     A 3D array containing the data to be written to the video file.
% filename : char
%     The name of the output AVI video file.
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
% the frames to an uncompressed AVI video file. It also sets up the figure
% properties for visualization and adjusts the color axis limits.
%
% Examples
% --------
% Write a 3D array to an AVI file with default settings:
%
%     write_frames_to_avi(my_data, 'output.avi');
%
% Write a 3D array to an AVI file with a specified frame rate:
%
%     write_frames_to_avi(my_data, 'output.avi', 10);
%
% Write a 3D array to an AVI file with specified spatial dimensions:
%
%     write_frames_to_avi(my_data, 'output.avi', 10, 1:256, 1:256);

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
buffer=3;

[N,bns] = histcounts(data(:),'normalization','cdf');
ind1 = dsearchn(N',0.1);
ind2 = dsearchn(N',0.995);
cax = [bns(ind1) bns(ind2)];

data = movmean(data,avgs,3);
numFrames = size(data,3);

writer_obj = VideoWriter(filename,'Uncompressed AVI');
writer_obj.FrameRate = frame_rate;
open(writer_obj)

h = figure;
set(h,'Position',[50 50 max(x)/max(y)*900+100 900])
imagesc(x,y,data(:,:,1))
axis image
axis off
colormap(gray)
clim(cax)

hold on

set(gca,'YDir','normal','XDir','reverse')
frame = getframe;
siz = size(frame.cdata);

sizY = siz(1)-2*buffer; if sizY/2 ~= round(sizY/2); sizY = sizY-1; end
sizX = siz(2)-2*buffer; if sizX/2 ~= round(sizX/2); sizX = sizX-1; end

clf(h)

for k = 1:numFrames
    imagesc(x, y, data(:,:,k))
    axis image
    axis off
    colormap(gray)
    clim(cax)
    hold on
    set(gca, 'YDir', 'normal', 'XDir', 'reverse')
    
    frame = getframe;
    
    % add dynamic size check to allow downsampled data input
    frame_size = size(frame.cdata);
    sizY = min(frame_size(1) - 2 * buffer, size(data, 1));
    sizX = min(frame_size(2) - 2 * buffer, size(data, 2));
    
    if sizY < 1 || sizX < 1
        error('Frame size too small or buffer is too large.');
    end
    
    I = frame.cdata(buffer+1:buffer+sizY, buffer+1:buffer+sizX, :);
    writeVideo(writer_obj, I);
    
    pause(0.001);
    clf(h)
end


close(writer_obj)
close(h)

% TODO: Add check for ffmpeg installation / add binaries to the code
% ffmpegtranscode(filename, [filename(1:end-3) 'mp4'], 'AudioCodec', 'none', 'VideoCodec', 'x264', 'x264Tune', 'film', 'x264Preset', 'veryslow', 'x264Crf', 17);
