function timeseries_to_movie(data, filename, frame_rate,x,y)
% TIMESERIES_TO_MOVIE Generate a movie from image data.
%
% This function processes a 3D array of image data to create a video file,
% applying optional cropping, and color scaling. The final video is
% saved in AVI format and can be transcoded to MP4.
%
% Inputs:
%   data - 3D matrix of image data.
%   filename - Name of the output video file. Use '' single quotes.
%   frame_rate - Frame rate of the output video.
%   x - Horizontal coordinates. Default is the size of data(:,2).
%   y - Vertical coordinates. Default is the size of data(:,1).
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
    imagesc(x,y,data(:,:,k))
    axis image
    axis off
    colormap(gray)
    clim(cax)
    hold on
    set(gca,'YDir','normal','XDir','reverse')
    frame = getframe;
    I = frame.cdata(buffer+1:sizY+buffer,buffer+1:sizX+buffer,:);
    writeVideo(writer_obj,I);
    pause(0.001);
    clf(h)
end

close(writer_obj)
close(h)

% TODO: Add check for ffmpeg installation / add binaries to the code
% ffmpegtranscode(filename, [filename(1:end-3) 'mp4'], 'AudioCodec', 'none', 'VideoCodec', 'x264', 'x264Tune', 'film', 'x264Preset', 'veryslow', 'x264Crf', 17);
