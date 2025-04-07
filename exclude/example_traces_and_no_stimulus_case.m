clear
% close all
clc

pixel_resolution = 5;
load('neuron_coordinates_and_traces.mat')
T_all = single(T_all);

load('mean_brain_image.mat')

path = cd;
path = [path '\'];

save_path = '\\v-storage.rockefeller.edu\vazirilab_medium_data\jeff_demas\MAxiMuM_data\Paper_Figures\Fig5\';
FontSize = 12;
LineWidth = 1;

sss = 25;
aaa = 0.05;

load('thresholds.mat')

%% 

close all

x = (1:1:size(I,2)).*4.2;
y = (1:1:size(I,1)).*5;

NX = nx;
NY = ny;

NX = NX - max(x); NX = -NX;

alpha = 158./(2500^2);
NZ = nz - alpha.*((nx-1500).^2 + (ny-2500).^2);

figure(100);
set(gcf,'Position',[250 50 700 920])
imagesc(x,y,fliplr(I)); colormap(gray)
set(gca,'YDir','normal','xTick',[],'yTick',[],'LineWidth',LineWidth)
hold on
axis image

hhh = scatter(NX(uoi),NY(uoi),sss,'m','Filled');
hhh.MarkerFaceAlpha = aaa;
print([save_path 'no_correlation_map.png'],'-dpng','-r600')
print([save_path 'no_correlation_map'],'-depsc')
saveas(gcf,[save_path 'no_correlation_map.fig'])

%% Uncorrelated neurons

C = [0.9 0.4 0.8 0.3 0.7 0.2 0.6 0.1 0.5 0.0]';
C = [C, zeros(10,1), C];

Tmax = round(T*200/540);
Tstart = round(Tmax.*1.5);
Tu = T_all(uoi,Tstart:Tstart+Tmax-1);
Zu = max(movmean(Tu,3,2),[],2)./3./std((Tu - movmean(Tu,5,2)),[],2);

figure; h = histogram(NZ(uoi),0:50:500,'FaceColor','m');
set(gcf,'Position',[100 100 300 160])
xlabel('Z \mum)')
ylabel('Neurons')
h.FaceAlpha = 1;
ylim([0 3000])
xlim([0 500])
set(gca,'yTick',[0 1000 2000 3000],'xTick',[0 125 250 375 500])
box(gca,'on')
set(gca,'XColor',[0 0 0],'YColor',[0 0 0 ],'FontSize',12,'LineWidth',LineWidth)
print([save_path 'uncorrelated_z_distribution.png'],'-dpng','-r600')
print([save_path 'uncorrelated_z_distribution'],'-depsc','-painters')
saveas(gcf,[save_path 'uncorrelated_z_distribution.fig'])


[Zu,indsz] = sort(Zu,'descend');

Tu = Tu(indsz,:);

num = 10;

mxs = max(Tu(2:2:22,:),[],2);
[mxs,inds] = sort(mxs,'descend');

for ijk = 1:num
    figure(11); plot(t(1:Tmax), (ijk)-1 + movmean(Tu(inds(ijk),:),5,2),'Color',C(ijk,:),'LineWidth',LineWidth); hold on
end

ylim([-0.5 13])
xlim([0 200])
xlabel('Time (s)')
ylabel('\DeltaF/F_0')
set(gca,'FontSize',FontSize,'LineWidth',LineWidth)
set(gcf,'Position',[1075 67  293  202])
print([save_path 'uncorrelated_traces.png'],'-dpng','-r600')
print([save_path 'uncorrelated_traces'],'-depsc')
saveas(gcf,[save_path 'uncorrelated_traces.fig'])

%% Somatosensory neurons

Tmax = round(T*200/540);Tstart = dsearchn(t',202.5);

C = [0.9 0.4 0.8 0.3 0.7 0.2 0.6 0.1 0.5 0.0]';
C = [zeros(10,1), zeros(10,1), C];

Ts = T_all(soi,Tstart:Tstart+Tmax-1);
Rss = Rs(soi);
[Rss,indss] = sort(Rss,'descend');
Ts = Ts(indss,:);

num = 10;

for ijk = 1:num
    figure(12); plot(t(Tstart:Tstart+Tmax-1) - t(Tstart), (ijk)-1 + movmean(Ts(ijk,:),5,2),'Color',C(ijk,:),'LineWidth',LineWidth); hold on
end

ylim([-0.5 12])
xlim([0 200])
xlabel('Time (s)')
ylabel('\DeltaF/F_0')
set(gca,'FontSize',FontSize,'LineWidth',LineWidth)
hold on

SS = ones(11,1)*Ss(Tstart:Tstart+Tmax-1);
SS(SS<0.1) = 0;
SS(SS>0) = 1;

SS = repmat(SS,[1 1 3]);
SS(:,:,1:2) = 0;

h=imagesc(t(Tstart:Tstart+Tmax-1) - t(Tstart),linspace(10.8,11.2,11),SS);
h.AlphaData = SS(:,:,3);

set(gcf,'Position',[1075 267  293  202])
print([save_path 'som_traces.png'],'-dpng','-r600')
print([save_path 'som_traces'],'-depsc')
saveas(gcf,[save_path 'som_traces.fig'])

%% Visual neurons

Tmax = round(T*200/540);
Tstart = dsearchn(t',212.5);

C = [0.9 0.4 0.8 0.3 0.7 0.2 0.6 0.1 0.5 0.0]';
C = [zeros(10,1), C, zeros(10,1)];

Tv = T_all(voi,Tstart:Tstart+Tmax-1);
Rvv = Rv(voi);
[Rvv,indsv] = sort(Rvv,'descend');
Tv = Tv(indsv,:);

num = 10;

for ijk = 1:num
    figure(13); plot(t(Tstart:Tstart+Tmax-1) - t(Tstart), (ijk)-1 + movmean(Tv(ijk,:),5,2),'Color',C(ijk,:),'LineWidth',LineWidth); hold on
end

ylim([-0.5 12])
xlim([0 200])
xlabel('Time (s)')
ylabel('\DeltaF/F_0')
set(gca,'FontSize',FontSize','LineWidth',LineWidth)
hold on

VV = ones(11,1)*Sv(Tstart:Tstart+Tmax-1);
VV(VV<0.1) = 0;
VV(VV>0) = 1;

VV = repmat(VV,[1 1 3]);
VV(:,:,[1 3]) = 0;

h=imagesc(t(Tstart:Tstart+Tmax-1) - t(Tstart),linspace(10.8,11.2,11),VV/2);
h.AlphaData = VV(:,:,2);

set(gcf,'Position',[1075 467 293  202])
print([save_path 'vis_traces.png'],'-dpng','-r600')
print([save_path 'vis_traces'],'-depsc')
saveas(gcf,[save_path 'vis_traces.fig'])

%% Motion neurons

Tmax = round(T*200/540);
Tstart = 1;%dsearchn(t',212.5);

C = [0.9 0.4 0.8 0.3 0.7 0.2 0.6 0.1 0.5 0.0]';
C = [C, zeros(10,1), zeros(10,1)];

Tm = T_all(moi,Tstart:Tstart+Tmax-1);
Rmm = Rm(moi);
[Rmm,indsm] = sort(Rmm,'descend');
Tm = Tm(indsm,:);

num = 10;

for ijk = 1:num
    figure(14); plot(t(Tstart:Tstart+Tmax-1) - t(Tstart), (ijk)-1 + movmean(Tm(ijk,:),5,2),'Color',C(ijk,:),'LineWidth',LineWidth); hold on
end

ylim([-0.5 13])
xlim([0 200])
xlabel('Time (s)')
ylabel('\DeltaF/F_0')
set(gca,'FontSize',FontSize,'LineWidth',LineWidth)
hold on

MM = ones(11,1)*Sm(Tstart:Tstart+Tmax-1);
MM(MM<0.1) = 0;
MM(MM>0) = 1;

MM = repmat(MM,[1 1 3]);
MM(:,:,2:3) = 0;

h=imagesc(t(Tstart:Tstart+Tmax-1) - t(Tstart),linspace(12.0,12.5,11),MM);
h.AlphaData = MM(:,:,1);

set(gcf,'Position',[1075 667  293  202])
print([save_path 'motion_traces.png'],'-dpng','-r600')
print([save_path 'motion_traces'],'-depsc')
saveas(gcf,[save_path 'motion_traces.fig'])

%%
% 
% uoi = logical(abs(Rs) < sigma/2 & abs(Rm) < sigma/2 & abs(Rv) < sigma/2);
% 
% Tu = T_all(uoi,:);
% 
% Ru = corr(Tu',Tu');
% 
% Z = linkage(Ru,'ward','euclidean');
% 
% max_clust = 5;
% 
% figure
% dendrogram(Z,max_clust)
% 
% Tcl = cluster(Z,'maxclust',max_clust);
% 
% Rumean = mean(Ru,2);
% 
% [Rumean,srt] = sort(Rumean+Tcl,'descend');
% 
% figure;
% imagesc(Ru(srt,srt))
% axis image
% colormap(jet)
% caxis([-0.2 0.4])
% set(gca,'YDir','normal')
% 
% C = jet(max_clust);
% 
% figure(100);
% set(gcf,'Position',[250 50 700 920])
% imagesc(x,y,fliplr(I)); colormap(gray)
% set(gca,'YDir','normal','xTick',[],'yTick',[])
% hold on
% 
% NXu = NX(uoi);
% NYu = NY(uoi);
% 
% for ijk = 1:max_clust
%     scatter(NXu(Tcl == ijk),NYu(Tcl == ijk),5,C(ijk,:),'Filled');
% end