clear
close all
clc

load('poi_18.mat')

volumeRate = 4.69;
frameRate = 30;
speedup = 4;

numframes = 120/speedup*frameRate;

t = (1:size(poi,3)).*120./size(poi,3);
tp = (1:numframes).*120./numframes;
Tp = numel(tp);

[d1,d2,T] = size(poi);

poi = double(reshape(poi,d1*d2,T));

poip = zeros(size(poi,1),Tp);

numPix = size(poi,1);

for j = 1:numPix
    poip(j,:) = interp1(t,poi(j,:),tp);
end

poip = reshape(poip,d1,d2,Tp);
poip(:,:,1) = poip(:,:,2);

x = (1:size(poip,2)).*3./size(poip,2);
y = (1:size(poip,1)).*5./size(poip,1);
avgs = 1;
cax = [100 2000];
scaleBar = 0.5;
crf = 17;
buffer = 2;

xc0 = 0.9;
yc0 = 1.66;
xcp = 1.5;
ycp = 2.5;

max_zoom = 1.2/0.6;

zoom_time = round(60*Tp/T);
still_time = round(Tp/T*(564 - 2*zoom_time)/3);

xcz = ones(Tp,1).*xc0;
xcz(still_time+zoom_time+1:(2*still_time+zoom_time)) = xcp;
xcz(still_time+1:(still_time+zoom_time)) = xc0 + (xcp-xc0)./zoom_time.*(1:zoom_time);
xcz((2*still_time+zoom_time)+1:2*(still_time+zoom_time)) = xcp + (xc0-xcp)./zoom_time.*(1:zoom_time);

ycz = ones(Tp,1).*yc0;
ycz(still_time+zoom_time+1:(2*still_time+zoom_time)) = ycp;
ycz(still_time+1:(still_time+zoom_time)) = yc0 + (ycp-yc0)./zoom_time.*(1:zoom_time);
ycz((2*still_time+zoom_time)+1:2*(still_time+zoom_time)) = ycp + (yc0-ycp)./zoom_time.*(1:zoom_time);

zoom = ones(size(xcz));
zoom(still_time+zoom_time+1:(2*still_time+zoom_time)) = max_zoom;
zoom(still_time+1:(still_time+zoom_time)) = 1 + (max_zoom-1)./zoom_time.*(1:zoom_time);
zoom((2*still_time+zoom_time)+1:2*(still_time+zoom_time)) = max_zoom + (1-max_zoom)./zoom_time.*(1:zoom_time);

inx = dsearchn(x',0.9);
iny = dsearchn(y',1.66);
rect = [iny-200, iny+200, inx-143, inx+143];
decenter = [ycz xcz];
zoom = [zoom zoom];

filename = '\\v-storage.rockefeller.edu\vazirilab_medium_data\jeff_demas\MAxiMuM_data\Paper_Videos\S8\movie_2min_plane_18_upsampled.avi';
addpath(genpath('\\v-storage\vazirilab_medium_data\jeff_demas\PROCESSING_SCRIPTS\Post_Processing_Routines\'))
makeMovie(poip, filename, x, y, frameRate, avgs, cax, scaleBar, rect, zoom, decenter, buffer, crf)