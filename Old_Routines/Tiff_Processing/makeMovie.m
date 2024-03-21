% Make movie from image stack

function [] = makeMovie(data,filename,frame_rate,startframe,endframe)

% % Open new avi file
% writerObj = VideoWriter(filename,'Uncompressed AVI');
% writerObj.FrameRate = frame_rate;
% open(writerObj);

try 
% Adjust brightness based on histogram
[counts, grayLevels] = hist(reshape(data(:,:,2),1,[]),50);
cdf = cumsum(counts);
cdf = cdf / numel(data(:,:,1));
index99 = find(cdf >= 0.995, 1, 'first');
maxval = grayLevels(index99);
if isempty(maxval)
    maxval = max(reshape(data(:,:,2),1,[]));
end
index01 = find(cdf <= 0.995, 1, 'first');
minval = grayLevels(index01);
if isempty(minval)
    minval = min(reshape(data(:,:,2),1,[]));
end

% Set axes and figure properties.
myfig = figure;
[xx,yy] = size(data(:,:,startframe));
imagesc(data(:,:,startframe)');
caxis([minval maxval])
axis image
set(gca,'yTick',[],'xTick',[])
colormap(green)
set(gcf,'Position', [250 250 xx yy]);
set(gca,'YDir','normal')
frame = getframe;
% size(frame.cdata)
hold on
clf(myfig)

% Create movie frames
for k = startframe:endframe
    imagesc(data(:,:,k)');
%     axis([0 xx 0 yy])
    caxis([minval maxval])
%     axis off
%     axis xy
%     axis square
%     colormap(green)
%     set(gcf,'Position', [250 250 xx yy]);    
%     set(gca,'YDir','normal')
%     set(gca,'xTick','yTick',[]);
    axis off
    frame = getframe;
%     size(frame.cdata)
    writeVideo(writerObj,frame);
    clf(myfig)
end

% Close file
close(writerObj);
close all;

catch
    close(writerObj);
    close all;
end


end