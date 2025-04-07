close all
clear
clc

LineWidth = 1;
FontSize = 12;
FontName = 'Arial';
save_path = '\\v-storage.rockefeller.edu\vazirilab_medium_data\jeff_demas\MAxiMuM_data\Paper_Figures\Fig2\';

%% Plane 21

N = 21;
load(['plane_' num2str(N) '_data.mat'])

x = linspace(0,600-12,size(poi,2));
y = 1:size(poi,1);

zz = 412;
num = 15;

mn = 500;
mx = 5500;

I = mean(poi(:,:,zz-num:zz+num),3);

It = I;
It = It-mn;
It(It<0) = 0;
It(It>mx) = mx;
It = It./mx;

Ic = repmat(It,[1 1 3]);
% Ic(25,20:70,1) = 1;
% Ic(25,20:70,2:3) = 0;

x1 = 169;
x2 = 261;
y1 = 275;
y2 = 375;

Ic(y1:y2,x1-2:x1-1,3) = 1;
Ic(y1:y2,x1-2:x1-1,1:2) = 0;

Ic(y1:y2,x2+1:x2+2,3) = 1;
Ic(y1:y2,x2+1:x2+2,1:2) = 0;

Ic(y1-2:y1-1,x1:x2,3) = 1;
Ic(y1-2:y1-1,x1:x2,1:2) = 0;

Ic(y2+1:y2+2,x1:x2,3) = 1;
Ic(y2+1:y2+2,x1:x2,1:2) = 0;

figure
imagesc(x,y,Ic)
axis image
set(gca,'xTick',[],'yTick',[])
print([save_path 'mean_projection_plane_' num2str(N)],'-depsc','-painters')
print([save_path 'mean_projection_plane_' num2str(N)],'-dpng','-r600')
saveas(gcf,[save_path 'mean_projection_plane_' num2str(N) '.fig'])

Icz = Ic(y1:y2,x1:x2,:);

% Icz(94,79:87,1) = 1;
% Icz(94,79:87,2:3) = 0;

Icz = Icz - 0.15;
Icz(Icz<0) = 0;
Icz = Icz./max(Icz(:));

figure
imagesc(x,y,Icz); axis image; colormap(gray)
set(gca,'xTick',[],'yTick',[])
saveas(gcf,[save_path 'mean_projection_zoom_in_plane_' num2str(N) '.fig'])
print([save_path 'mean_projection_zoon_in_plane_' num2str(N)],'-dpng','-r600')
print([save_path 'mean_projection_zoom_in_plane_' num2str(N)],'-depsc','-painters')

% imwrite(uint8(Ic*255),['mean_projection_plane_' num2str(N) '.tiff'])
% imwrite(uint8(Icz*255),['mean_projection_zoom_in_plane_' num2str(N) '.tiff'])

%% Plane 26

N = 26;
load(['plane_' num2str(N) '_data.mat'])

x = linspace(0,600-12,size(poi,2));
y = 1:size(poi,1);

zz = 63;
num = 20;

mn = 1000;
mx = 12000;

I = mean(poi(:,:,zz-num:zz+num),3);
I = fixScanPhase(I,0,1);

It = I;
It = It-mn;
It(It<0) = 0;
It(It>mx) = mx;
It = It./mx;

Ic = repmat(It,[1 1 3]);
% Ic(25,20:70,1) = 1;
% Ic(25,20:70,2:3) = 0;

figure
imagesc(x,y,It)
axis image
colormap(gray)
caxis([0 0.65])
set(gca,'xTick',[],'yTick',[])
print([save_path 'example_plane_' num2str(N)],'-depsc','-painters')
print([save_path 'example_plane_' num2str(N)],'-dpng','-r600')
saveas(gcf,[save_path 'example_plane_' num2str(N) '.fig'])

x1 = 306;
x2 = 398;
y1 = 15;
y2 = 115;

Ic(y1:y2,x1-2:x1-1,3) = 1;
Ic(y1:y2,x1-2:x1-1,1:2) = 0;

Ic(y1:y2,x2+1:x2+2,3) = 1;
Ic(y1:y2,x2+1:x2+2,1:2) = 0;

Ic(y1-2:y1-1,x1:x2,3) = 1;
Ic(y1-2:y1-1,x1:x2,1:2) = 0;

Ic(y2+1:y2+2,x1:x2,3) = 1;
Ic(y2+1:y2+2,x1:x2,1:2) = 0;

figure
imagesc(x,y,Ic)
axis image
set(gca,'xTick',[],'yTick',[])
print([save_path 'mean_projection_plane_' num2str(N)],'-depsc','-painters')
print([save_path 'mean_projection_plane_' num2str(N)],'-dpng','-r600')
saveas(gcf,[save_path 'mean_projection_plane_' num2str(N) '.fig'])

Icz = Ic(y1:y2,x1:x2,:);

% Icz(94,79:87,1) = 1;
% Icz(94,79:87,2:3) = 0;

Icz = Icz - 0.15;
Icz(Icz<0) = 0;
Icz = Icz./max(Icz(:));

figure
imagesc(x,y,Icz); axis image; colormap(gray)
set(gca,'xTick',[],'yTick',[])
saveas(gcf,[save_path 'mean_projection_zoom_in_plane_' num2str(N) '.fig'])
print([save_path 'mean_projection_zoom_in_plane_' num2str(N)],'-depsc','-painters')
print([save_path 'mean_projection_zoom_in_plane_' num2str(N)],'-dpng','-r600')

% imwrite(uint8(Ic*255),['mean_projection_plane_' num2str(N) '.tiff'])
% imwrite(uint8(Icz*255),['mean_projection_zoom_in_plane_' num2str(N) '.tiff'])

%%

N = 21;

path2 = '\\v-storage.rockefeller.edu\vazirilab_medium_data\jeff_demas\MAxiMuM_data\20191121\MH70\MH70_0p6mm_FOV_50_550um_depth_som_stim_199mW_3min_M1_00001_00001\';
load([path2 'caiman_output_plane_' num2str(N) '.mat'])

addpath(genpath('\\v-storage.rockefeller.edu\vazirilab_medium_data\jeff_demas\PROCESSING_SCRIPTS\Segmentation_Routines\CaImAn-MATLAB-master\CaImAn-MATLAB-master\'));

decay_time = 0.5;
Nsamples = ceil(decay_time*9.61);
[fitness] = compute_event_exceptionality(T_keep,Nsamples,0);

[fitness,inds] = sort(fitness,'ascend');

numN = 50;
off = 0.5;
avgs = 5;

T = size(T_keep,2);
t = linspace(0,180,T);

C = [0.9 0.4 0.8 0.3 0.7 0.2 0.6 0.1 0.5 0.0]';
C = [zeros(10,1), C, zeros(10,1)];

OT = movmean(T_keep(inds(4:numN+3),:),avgs,2)+off.*(0:numN-1)'*ones(1,T);

figure(101)
set(gcf,'Position',[100 500 800 396])
for ijk = 1:size(C,1)
    figure(101)
    hold on
    plot(t,OT(ijk:10:end,:),'Color',C(ijk,:),'LineWidth',LineWidth')
end

xlabel('Time')
ylabel('DFF0')
xlim([0 max(t)])
ylim([-0.5 26])
box(gca,'on')
set(gca,'FontSize',FontSize,'LineWidth',LineWidth,'FontName',FontName,'XColor',[0 0 0],'YColor',[0 0 0])
% print([save_path 'traces'],'-depsc','-painters')
xlabel('Time (s)')
ylabel('\DeltaF/F_0')
print([save_path 'traces.png'],'-dpng','-r600')
% saveas(gcf,[save_path 'traces.fig'])
