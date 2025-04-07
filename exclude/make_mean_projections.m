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

%%

x = 1:nx;
x = x.*600./(nx+12);

y = 1:ny;

N = 21;

poi = vol(:,:,N,:);
poi = reshape(poi,ny,nx,nt);

zz = 412;
num = 15;

mn = 500;
mx = 5500;

I = mean(poi(:,:,zz-num:zz+num),3);

figure; 
imagesc(x,y,fliplr(I))
axis image
colormap(gray)
caxis([mn mx+mn])
set(gca,'ydir','Normal')
saveas(gcf,['mean_projection_plane_' num2str(N) '.fig'])

It = I;
It = It-mn;
It(It<0) = 0;
It(It>mx) = mx;
It = It./mx;

Ic = repmat(It,[1 1 3]);
Ic(20:30,20:70,1) = 1;
Ic(20:30,20:70,2:3) = 0;

x1 = 169;
x2 = 261;
y1 = 275;
y2 = 375;

w = 5;

Ic(y1-w:y2+w,x1-w:x1-1,3) = 1;
Ic(y1-w:y2+w,x1-w:x1-1,1:2) = 0;

Ic(y1-w:y2+w,x2+1:x2+w,3) = 1;
Ic(y1-w:y2+w,x2+1:x2+w,1:2) = 0;

Ic(y1-w:y1-1,x1-w:x2+w,3) = 1;
Ic(y1-w:y1-1,x1-w:x2+w,1:2) = 0;

Ic(y2+1:y2+w,x1-w:x2+w,3) = 1;
Ic(y2+1:y2+w,x1-w:x2+w,1:2) = 0;

figure
imshow(Ic)

Icz = Ic(y1:y2,x1:x2,:);

Icz(93:95,79:87,1) = 1;
Icz(93:95,79:87,2:3) = 0;

Icz = Icz - 0.15;
Icz(Icz<0) = 0;
Icz = Icz./max(Icz(:));

figure
imagesc(x,y,Icz); axis image; colormap(gray)
saveas(gcf,['mean_projection_zoom_in_plane_' num2str(N) '.fig'])

imwrite(uint8(Ic*255),['mean_projection_plane_' num2str(N) '.tiff'])
imwrite(uint8(Icz*255),['mean_projection_zoom_in_plane_' num2str(N) '.tiff'])


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
    plot(t,OT(ijk:10:end,:),'Color',C(ijk,:))
end

xlabel('Time (s)')
ylabel('\DeltaF/F_0')
xlim([0 max(t)])
ylim([-0.5 26])
box(gca,'on')
grid(gca,'on')
print('traces.png','-dpng','-r600')
saveas(gcf,'traces.fig')

%%
OOT = movmean(T_keep(inds([9 17 13 15 16]),:),1,2)+1.5*(0:4)'*ones(1,T);

figure;
plot(t-90,OOT,'Color',[0 0.5 0],'LineWidth',1.5)
xlim([0 90])
% ylim([-0.5 5.5])
set(gca,'Color',[197 224 180]/255)
set(gcf, 'InvertHardcopy', 'off')

print('sample_traces.png','-dpng','-r600')

figure;
plot(t-90,OOT,'r-','LineWidth',1.5)
xlim([0 90])
set(gcf, 'InvertHardcopy', 'off')
print('sample_traces_red.png','-dpng','-r600')

figure;
plot(t-90,OOT,'b-','LineWidth',1.5)
xlim([0 90])
set(gcf, 'InvertHardcopy', 'off')
print('sample_traces_blue.png','-dpng','-r600')

figure;
plot(t-90,OOT(2,:),'r-','LineWidth',1.5)
hold on
plot(t-91,OOT(2,:)+0.7,'Color',[1 0.5 0],'LineWidth',1.5)
xlim([0 90])
set(gca,'Color',[180 199 231]/255)
set(gcf,'InvertHardcopy','off')
ylim([1 5])
print('corr_trace_example.png','-dpng','-r600')

%%

N = 26;

poi = vol(:,:,N,:);
poi = reshape(poi,ny,nx,nt);

zz = 63;
num = 20;

mn = 1000;
mx = 12000;

I = mean(poi(:,:,zz-num:zz+num),3);

I = fixScanPhase(I,0,1);

figure; 
imagesc(I)
axis image
colormap(gray)
caxis([mn mx+mn])
set(gca,'ydir','Normal')
saveas(gcf,['mean_projection_plane_' num2str(N) '.fig'])

It = I;
It = It-mn;
It(It<0) = 0;
It(It>mx) = mx;
It = It./mx;

Ic = repmat(It,[1 1 3]);
Ic(20:30,20:70,1) = 1;
Ic(20:30,20:70,2:3) = 0;

x1 = 306;
x2 = 398;
y1 = 15;
y2 = 115;

w = 5;

Ic(y1-w:y2+w,x1-w:x1-1,2) = 0.5;
Ic(y1-w:y2+w,x1-w:x1-1,[1 3]) = 0;

Ic(y1-w:y2+w,x2+1:x2+w,2) = 0.5;
Ic(y1-w:y2+w,x2+1:x2+w,[1 3]) = 0;

Ic(y1-w:y1-1,x1-w:x2+w,2) = 0.5;
Ic(y1-w:y1-1,x1-w:x2+w,[1 3]) = 0;

Ic(y2+1:y2+w,x1-w:x2+w,2) = 0.5;
Ic(y2+1:y2+w,x1-w:x2+w,[1 3]) = 0;

figure
imshow(Ic)

Icz = Ic(y1:y2,x1:x2,:);

Icz(93:95,79:87,1) = 1;
Icz(93:95,79:87,2:3) = 0;

Icz = Icz - 0.15;
Icz(Icz<0) = 0;
Icz = Icz./max(Icz(:));

figure
imagesc(x,y,Icz); axis image; colormap(gray)

imwrite(uint8(Ic*255),['mean_projection_plane_' num2str(N) '.tiff'])
imwrite(uint8(Icz*255),['mean_projection_zoom_in_plane_' num2str(N) '.tiff'])
saveas(gcf,['mean_projection_zoom_in_plane_' num2str(N) '.fig'])
