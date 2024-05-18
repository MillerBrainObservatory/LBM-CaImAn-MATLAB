function planeToMovie(data, filename, x, y, frameRate, avgs,  zoom, decenter, buffer, crf, transcode_flag, scale_flag)
%PLANETOMOVIE Generate a movie from image data.
%
% This function processes a 3D array of image data to create a video file,
% applying optional zooming, cropping, and color scaling. The final video is
% saved in AVI format and can be transcoded to MP4.
%
% Parameters:
% -----------
% data - 3D matrix of image data.
% filename - Name of the output video file.
% x - Horizontal coordinates.
% y - Vertical coordinates.
% frameRate - Frame rate of the output video.
% avgs - Number of frames to average.
% decenter - Decentering offsets.
% crf - Constant Rate Factor for video quality.
arguments
    data {mustBeNumeric}
    filename (1,:) char
    x (:,1) double {mustBeNumeric} = 1:size(data,2)
    y (:,1) double {mustBeNumeric} = 1:size(data,1)
    frameRate (1,1) double {mustBeNumeric, mustBePositive} = 1
    avgs (1,1) double {mustBeNumeric, mustBeNonnegative} = 1
    zoom (1,:) double {mustBeNumeric, mustBeNonnegative} = ones(1, size(data, 3))
    decenter (1,2) double {mustBeNumeric} = [0 0]
    buffer (1,1) double {mustBeNumeric, mustBeNonnegative} = 3
    crf (1,1) double {mustBeNumeric, mustBePositive} = 17
    transcode_flag (1,1) double {mustBeNumericOrLogical} = 0
    scale_flag (1,1) double {mustBeNumericOrLogical} = 0
end
%% Initialize default parameters if not provided
if nargin < 13 || isempty(crf)
    crf = 17;  % Default CRF value
end
if nargin < 12 || isempty(buffer)
    buffer = 3;  % Default buffer value
end
if nargin < 11 || isempty(decenter)
    decenter = [];  % No decentering
end
if nargin < 10 || isempty(zoom)
    zoom = ones(1, size(data, 3));  % Default to no zoom for all frames
end
if nargin < 9 || isempty(rect)
    rect = [];  % No rectangle specified
end
if nargin < 8 || isempty(scaleBar)
    scaleBar = [];  % No scale bar
end
if nargin < 7 || isempty(cax)
    cax = [];  % Color axis will be calculated inside
end
if nargin < 6 || isempty(avgs)
    avgs = 1;  % Default averaging over 1 frame
end
if nargin < 5 || isempty(frameRate)
    frameRate = 1;  % Default frame rate
end
if nargin < 4 || isempty(y)
    y = 1:size(data,1);  % Default y dimensions
end
if nargin < 3 || isempty(x)
    x = 1:size(data,2);  % Default x dimensions
end
if nargin < 2
    error('Filename must be provided');
end
if nargin < 1
    error('Data must be provided');
end

%% Parse inputs

do_zoom = 1;

if isempty(cax)
    [N,bns] = histcounts(data(:),'normalization','cdf');
    ind1 = dsearchn(N',0.1);
    ind2 = dsearchn(N',0.995);
    cax = [bns(ind1) bns(ind2)];
elseif cax(2) < 1
    [N,bns] = histcounts(data(:),'normalization','cdf');
    ind1 = dsearchn(N',cax(1));
    ind2 = dsearchn(N',cax(2));
    cax = [bns(ind1) bns(ind2)];
end

data = movmean(data,avgs,3);
numFrames = size(data,3);

writerObj = VideoWriter(filename,'Uncompressed AVI');
writerObj.FrameRate = frameRate;
open(writerObj)

h = figure;
set(h,'Position',[50 50 max(x)/max(y)*900+100 900])
imagesc(x,y,data(:,:,1))
axis image
axis off
colormap(gray)
clim(cax)

hold on

if ~isempty(scaleBar)
    plot([max(x)-1.5*scaleBar max(x)-0.5*scaleBar],0.5.*[scaleBar scaleBar],'r-','LineWidth',6)
end

set(gca,'YDir','normal','XDir','reverse')
frame = getframe;
siz = size(frame.cdata);

sizY = siz(1)-2*buffer; if sizY/2 ~= round(sizY/2); sizY = sizY-1; end
sizX = siz(2)-2*buffer; if sizX/2 ~= round(sizX/2); sizX = sizX-1; end

clf(h)
kfreeze = 0;
zoom = ones(1,numFrames);

for k = 1:numFrames
    if do_zoom == 0 || zoom(k) == 1
        imagesc(x,y,data(:,:,k))
        axis image
        axis off
        colormap(gray)
        caxis(cax)
        hold on
        if ~isempty(scaleBar)
            plot([max(x)-1.5*scaleBar max(x)-0.5*scaleBar],0.5.*[scaleBar scaleBar],'r-','LineWidth',6)
        end
        set(gca,'YDir','normal','XDir','reverse')
        
        frame = getframe;
        I = frame.cdata(buffer+1:sizY+buffer,buffer+1:sizX+buffer,:);
        writeVideo(writerObj,I);
        clf(h)
        
    elseif do_zoom == 1 && zoom(k) > 1
        
        if kfreeze == 0 
            kfreeze = k;
        end
        
        imagesc(x,y,data(:,:,kfreeze))
        axis image
        axis off
        colormap(gray)
        caxis(cax)
        hold on
        if ~isempty(scaleBar)
            plot([max(x)-1.5*scaleBar max(x)-0.5*scaleBar],0.5.*[scaleBar scaleBar],'r-','LineWidth',6)
        end
        set(gca,'YDir','normal','XDir','reverse')
        
        dp = data(rect(1):rect(2),rect(3):rect(4),k);
        imagesc(zoom(k,2).*xp+decenter(k,2),zoom(k,1).*yp+decenter(k,1),dp)
        plot(zoom(k,2).*xp+decenter(k,2),zoom(k,1).*yp(1).*ones(size(xp))+decenter(k,1),'r-','LineWidth',2)
        plot(zoom(k,2).*xp+decenter(k,2),zoom(k,1).*yp(end).*ones(size(xp))+decenter(k,1),'r-','LineWidth',2)
        plot(zoom(k,2).*xp(1).*ones(size(yp))+decenter(k,2),zoom(k,1).*yp+decenter(k,1),'r-','LineWidth',2)
        plot(zoom(k,2).*xp(end).*ones(size(yp))+decenter(k,2),zoom(k,1).*yp+decenter(k,1),'r-','LineWidth',2)
        
        frame = getframe;
        I = frame.cdata(buffer+1:sizY+buffer,buffer+1:sizX+buffer,:);
        writeVideo(writerObj,I);
        clf(h)

    end
end

close(writerObj)
close(h)