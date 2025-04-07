%% Process recording
file = 'MH70_0p6mm_FOV_50_550um_depth_som_stim_199mW_3min_M1_00001_00001';
numROI = 4;
vol = ProcessROITiff2([file '.tif'],1:numROI,1);

order = fliplr([1 5:10 2 11:17 3 18:23 4 24:30]);

vol= vol(:,:,order,:);

nx = size(vol,2);
ny = size(vol,1);
nz = size(vol,3);
nt = size(vol,4);

%% Make a movie

N = 24;

poi = vol(:,:,N,:);
poi = reshape(poi,ny,nx,nt);

numAvgs = 5;
frameRate = 25;
volumeRate = 9.61;
startframe = 1;
ds = 2;
endframe = round(120*volumeRate);

% mx = max(poi(:));
mx = 12000;
% mn = min(poi(:));
mn = 1000;

poi = movmean(poi,numAvgs,3);

pmx = max(poi,[],3);

filename = ['movie_2min_plane_' num2str(N) '.mp4'];

writerObj = VideoWriter(filename,'MPEG-4');
writerObj.FrameRate = 25;
writerObj.Quality = 100;
open(writerObj);

% Set axes and figure properties.
myfig = figure;
[xx,yy] = size(poi(:,:,startframe));
imagesc(poi(:,:,startframe)');
caxis([mn mx])
axis image
set(gca,'yTick',[],'xTick',[])
colormap(gray)
set(gcf,'Position', [250 250 xx yy]);
set(gca,'YDir','normal')
frame = getframe;
% size(frame.cdata)
hold on
clf(myfig)

% Create movie frames
for k = startframe:ds:endframe
    imagesc(poi(:,:,k)');
    caxis([mn mx])
    axis off
    frame = getframe;
    writeVideo(writerObj,frame);
    clf(myfig)
end

% Close file
close(writerObj);
close all;

figure
imagesc(pmx)
axis image
caxis([mn mx])
colormap(gray)




