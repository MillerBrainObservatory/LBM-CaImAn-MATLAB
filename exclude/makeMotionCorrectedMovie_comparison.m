%% 

clear 
close all
clc

addpath(genpath('\\v-storage.rockefeller.edu\vazirilab_medium_data\jeff_demas\PROCESSING_SCRIPTS\Segmentation_Routines\motion_correction\'))

spath = '\\v-storage.rockefeller.edu\vazirilab_medium_data\jeff_demas\MAxiMuM_data\Paper_Videos\S8\';

N = 18; % 10; % 18 % 26

% load(['poi_' num2str(N) '.mat'])

d = load(['data_plane_' num2str(N) '.mat'],'poi');
data = single(d.poi);
% 
[ny,nx,nt] = size(data);
% 
% poi = movmean(data,5,3);

%% Motion Correction

% gcp;
    
% Rigid motion correction using NoRMCorre algorithm:    
options_rigid = NoRMCorreSetParms(...
    'd1',size(data,1),...
    'd2',size(data,2),...
    'bin_width',24,...       % Bin width for motion correction
    'max_shift',15,...        % Max shift in px
    'us_fac',20,...
    'init_batch',120,...     % Initial batch size
    'correct_bidir',false... % Correct bidirectional scanning
    );
[M1,shifts1,~,~] = normcorre_batch(data,options_rigid);


shifts_r = squeeze(cat(3,shifts1(:).shifts));
shifts_v = movvar(shifts_r,24,1);
% [~,minv_idx] = mink(shifts_v,120,1);
[srt,minv_idx] = sort(shifts_v,120); 
minv_idx = minv_idx(1:120);
best_idx = unique(reshape(minv_idx,1,[]));
template_good = mean(M1(:,:,best_idx),3);

% No rigid motion correction using the good tamplate from the rigid
% correction.
  options_nonrigid = NoRMCorreSetParms(...
    'd1',size(data,1),...
    'd2',size(data,2),...
    'bin_width',24,...
    'max_shift',15,...
    'us_fac',20,...
    'init_batch',120,...
    'correct_bidir',false...
    );

% Data from the motion correction that will be used for the CNMF
[M2,shifts2,~,~] = normcorre_batch(data,options_nonrigid,template_good);

%% Metrics of the motion correction

shifts_r = squeeze(cat(3,shifts1(:).shifts));
shifts_nr = cat(ndims(shifts2(1).shifts)+1,shifts2(:).shifts);
shifts_nr = reshape(shifts_nr,[],ndims(data)-1,nt);
shifts_x = squeeze(shifts_nr(:,1,:))';
shifts_y = squeeze(shifts_nr(:,2,:))';

[cY,~,~] = motion_metrics(data,10);
[cM1,~,~] = motion_metrics(M1,10);
[cM2,~,~] = motion_metrics(M2,10);

motionCorrectionFigure = figure;

ax1 = subplot(311); plot(1:nt,cY,1:nt,cM1,1:nt,cM2); legend('raw data','rigid','non-rigid'); title('correlation coefficients','fontsize',14,'fontweight','bold')
        set(gca,'Xtick',[])
ax2 = subplot(312); %plot(shifts_x); hold on; 
plot(shifts_r(:,1),'--k','linewidth',2); title('displacements along x','fontsize',14,'fontweight','bold')
        set(gca,'Xtick',[])
ax3 = subplot(313); %plot(shifts_y); hold on; 
plot(shifts_r(:,2),'--k','linewidth',2); title('displacements along y','fontsize',14,'fontweight','bold')
        xlabel('timestep','fontsize',14,'fontweight','bold')
linkaxes([ax1,ax2,ax3],'x')

% Figure: Motion correction Metrics
% saveas(motionCorrectionFigure,[filename '_motion_correction_metrics.fig']);
% close(motionCorrectionFigure)

numAvgs = 5;

poi = movmean(M2,numAvgs,3);
poi2 = single(M2);
clear M2

poi = single(poi);

save(['poi_' num2str(N) '.mat'],'poi')

%% Make movie

frameRate = 25;
volumeRate = 4.7;
startframe = 280;
ds = 1;
endframe = startframe+round(120*volumeRate)-1;

x = linspace(0,6,2*size(poi,2));
y = linspace(0,5,size(poi,1));

mx = 2000;%max(poi(:))/2*1.25;
mn = 100;%5.*min(poi(:));

cx0 = 1.500;
cy0 = 2.500;

cxp = 2.100;
cyp = 1.660;

zoom_time = 60;
still_time = (564 - 2*zoom_time)/3;

filename = [spath 'movie_2min_plane_' num2str(N) '_side_by_side.avi'];

writerObj = VideoWriter(filename,'Uncompressed AVI');
writerObj.FrameRate = 4.7*4;
% writerObj.Quality = 100;
open(writerObj);

%% 
close all

% Set axes and figure properties.
myfig = figure;
[xx,yy] = size([poi(:,:,startframe) poi2(:,:,startframe)]);
imagesc(x,y,[poi(:,:,startframe) poi2(:,:,startframe)]);
hold on; plot([0.15 0.4],[0.15 0.15],'-r','LineWidth',6)
caxis([mn mx])
axis image
set(gca,'yTick',[],'xTick',[])
colormap(gray)
xlim([0.01 max(x)])
ylim([0.01 max(y)])
set(gcf,'Position', [0 50 1400 920]);
set(gca,'YDir','normal','XDir','reverse')
frame = getframe;
% size(frame.cdata)
hold on

inx = dsearchn(x',0.9);
iny = dsearchn(y',1.66);
pois = poi(iny-200:iny+200,inx-143:inx+143,:);
pois2 = poi2(iny-200:iny+200,inx-143:inx+143,:);
xs0 = linspace(-0.6,0.6,size(pois,2));
ys0 = linspace(-1,1,size(pois,1));
xc0 = 0.9;
yc0 = 1.66;
xcp = 1.5;
ycp = 2.5;

max_zoom = 1.2/0.6;

xsz = xs0;% .* max_zoom;
ysz = ys0;% .* max_zoom;

xcz = xc0;
ycz = yc0;

imagesc(xsz+xcz,ysz+ycz,pois(:,:,1))
plot(xsz+xcz,ones(size(xsz)).*(ycz+min(ysz)),'r','LineWidth',1)
plot(xsz+xcz,ones(size(xsz)).*(ycz+max(ysz)),'r','LineWidth',1)
plot(ones(size(ysz)).*(xcz+min(xsz)),ysz+ycz,'r','LineWidth',1)
plot(ones(size(ysz)).*(xcz+max(xsz)),ysz+ycz,'r','LineWidth',1)

%%
clf(myfig)

xcz = ones(1,(endframe-startframe+1)).*xc0;
xcz(still_time+zoom_time+1:(2*still_time+zoom_time)) = xcp;
xcz(still_time+1:(still_time+zoom_time)) = xc0 + (xcp-xc0)./zoom_time.*(1:zoom_time);
xcz((2*still_time+zoom_time)+1:2*(still_time+zoom_time)) = xcp + (xc0-xcp)./zoom_time.*(1:zoom_time);

ycz = ones(1,(endframe-startframe+1)).*yc0;
ycz(still_time+zoom_time+1:(2*still_time+zoom_time)) = ycp;
ycz(still_time+1:(still_time+zoom_time)) = yc0 + (ycp-yc0)./zoom_time.*(1:zoom_time);
ycz((2*still_time+zoom_time)+1:2*(still_time+zoom_time)) = ycp + (yc0-ycp)./zoom_time.*(1:zoom_time);

zoom = ones(size(xcz));
zoom(still_time+zoom_time+1:(2*still_time+zoom_time)) = max_zoom;
zoom(still_time+1:(still_time+zoom_time)) = 1 + (max_zoom-1)./zoom_time.*(1:zoom_time);
zoom((2*still_time+zoom_time)+1:2*(still_time+zoom_time)) = max_zoom + (1-max_zoom)./zoom_time.*(1:zoom_time);

% Create movie frames
for k = startframe:ds:endframe
    kk = k - startframe+1;
    
    xsz = xs0.*zoom(kk);
    ysz = ys0.*zoom(kk);
    
    if kk <= still_time
        imagesc(x,y,[poi(:,:,k) poi2(:,:,k)]);
        hold on; plot([0.15 0.4],[0.15 0.15],'-r','LineWidth',6)
        set(gcf,'Position',[50 50 1400 920],'Color',[0 0 0])
        axis image
        caxis([mn mx])
        set(gca,'yDir','normal','xDir','reverse')
        xlim([0.01 max(x)])
        ylim([0.01 max(y)])
        axis off
        frame = getframe;
        szx = size(frame.cdata,2);
        disp(size(frame.cdata))
        I = frame.cdata(3:590,3:710,:);
        writeVideo(writerObj,I);
        clf(myfig)
        
    elseif kk > still_time && kk <= 2*(still_time+zoom_time)
        imagesc(x,y,[poi(:,:,still_time) poi2(:,:,still_time)]);
        hold on; plot([0.15 0.4],[0.15 0.15],'-r','LineWidth',6)
        set(gcf,'Position',[50 50 1400 920],'Color',[0 0 0])
        axis image
        caxis([mn mx])
        set(gca,'yDir','normal','xDir','reverse')
        xlim([0.01 max(x)])
        ylim([0.01 max(y)])
        axis off
        
        hold on
        
        imagesc(xsz+xcz(kk),ysz+ycz(kk),pois(:,:,k))
        plot(xsz+xcz(kk),ones(size(xsz)).*(ycz(kk)+min(ysz)),'r','LineWidth',2)
        plot(xsz+xcz(kk),ones(size(xsz)).*(ycz(kk)+max(ysz)),'r','LineWidth',2)
        plot(ones(size(ysz)).*(xcz(kk)+min(xsz)),ysz+ycz(kk),'r','LineWidth',2)
        plot(ones(size(ysz)).*(xcz(kk)+max(xsz)),ysz+ycz(kk),'r','LineWidth',2)
        
        imagesc(3+xsz+xcz(kk),ysz+ycz(kk),pois2(:,:,k))
        plot(3+xsz+xcz(kk),ones(size(xsz)).*(ycz(kk)+min(ysz)),'r','LineWidth',2)
        plot(3+xsz+xcz(kk),ones(size(xsz)).*(ycz(kk)+max(ysz)),'r','LineWidth',2)
        plot(3+ones(size(ysz)).*(xcz(kk)+min(xsz)),ysz+ycz(kk),'r','LineWidth',2)
        plot(3+ones(size(ysz)).*(xcz(kk)+max(xsz)),ysz+ycz(kk),'r','LineWidth',2)
        
        frame = getframe;
        szx = size(frame.cdata,2);
        disp(size(frame.cdata))
        I = frame.cdata(3:590,3:710,:);
        writeVideo(writerObj,I);
        clf(myfig)
        
    elseif kk > 2*(still_time+zoom_time)
        disp('final zone')
        imagesc(x,y,[poi(:,:,k) poi2(:,:,k)]);
        hold on; plot([0.15 0.4],[0.15 0.15],'-r','LineWidth',6)
        set(gcf,'Position',[50 50 1400 920],'Color',[0 0 0])
        axis image
        caxis([mn mx])
        set(gca,'yDir','normal','xDir','reverse')
        xlim([0.01 max(x)])
        ylim([0.01 max(y)])
        axis off
        frame = getframe;
        szx = size(frame.cdata,2);
        disp(size(frame.cdata))
        I = frame.cdata(3:590,3:710,:);
        writeVideo(writerObj,I);
        clf(myfig)
        
    end

end

% Close file
close(writerObj);
close all;

ffmpegtranscode(filename, [filename(1:end-3) 'mp4'], 'AudioCodec', 'aac', 'VideoCodec', 'x264', 'Mpeg4Quality',1);

