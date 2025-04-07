clear
close all
clc

%% Load data

load('neuron_coordinates_and_traces.mat') % traces and coordinates
load('thresholds.mat') % thresholded populations
load('mean_brain_image.mat')
x = (1:1:size(I,2)).*4.2; % x and y pixel arrays
y = (1:1:size(I,1)).*5;

nx = nx - max(x); nx = -nx;

spath = '\\v-storage.rockefeller.edu\vazirilab_medium_data\jeff_demas\MAxiMuM_data\Paper_Figures\Fig6\';
spathm = '\\v-storage.rockefeller.edu\vazirilab_medium_data\jeff_demas\MAxiMuM_data\Paper_Videos\S9\';

%% Re-do motion vector with zero lag

load('tracking_data2.mat','sm','t')
sm = circshift(sm,0,2); % this compensates for the camera being turned on ~0.8 s after measurement starts
tt = t-mean(t);
tau = 0.55/log(2);
kernel = exp(tt./0.2);
kernel(tt>=0) = exp(-tt(tt>=0)./tau);

Sm = conv(sm,kernel,'same');

%% Cross-correlation analysis

R = zeros(1,K);
RR = R;
L = zeros(1,K);
parfor ii = 1:K
   RR(ii) = corr(Sm',T_all(ii,:)'); 
   [r,lags] = xcorr(Sm',T_all(ii,:)',10);
   [~,in] = max(r);
   R(ii) = corr(Sm',circshift(T_all(ii,:),lags(in),2)');
   L(ii) = lags(in);
end

%%

moi = logical(R>thrm);

% [~,in] = max(R);
% figure;
% plot(t,Sm.*max(T_all(in,:)),t,T_all(in,:));

figure
h = histogram(-(L(moi)-round(median(L(moi))))./4.7,(-10.5:10.5)./4.7,'Normalization','probability');
xlabel('Lag (s)')
be = h.BinEdges;
be = be(1:end-1)+diff(be)./2;
N = h.Values;
ylabel('Probability')
set(gcf,'Position',[458   122   327   258])
% ylim([0 12000])
% set(gca,'yTick',[0:4000:12000],'yTickLabel',{'0','4,000','8,000','12,000'})
xlim([-2.2 2.2])
set(gca,'XColor',[0 0 0],'YColor',[ 0 0 0],'FontSize',12,'LineWidth',1)
saveas(gcf,[spath 'lag_distribution.fig'])
print([spath 'lag_distribution'],'-depsc','-painters')
print([spath 'lag_distribution'],'-dpng','-r600')


ecb = (1:1000)'*ones(1,200);
figure;
imagesc(ecb)
axis image
set(gca,'xTick',[],'yTick',[])
colormap('jet')
saveas(gcf,[spath 'example_colorbar.fig'])
print([spath 'example_colorbar'],'-depsc','-painters')
print([spath 'example_colorbar'],'-dpng','-r600')

% cs = jet(numel(N));
% 
% for ijk = 1:numel(N)
%     figure(101);
%     hold on
%     v = zeros(size(be));
%     v(ijk) = N(ijk);
%     b = bar(be,v);
%     b.LineWidth = 1;
%     b.BarWidth = 1;
%     b.FaceColor = cs(ijk,:);
% end
% xlabel('Onset time (s)')
% ylabel('Number of neurons')
% box(gca,'on')

% lag_cinds = L(moi)+11;
% lag_cinds(lag_cinds<1) = 1;
% lag_cinds(lag_cinds>16) = 16;

lag_cinds = -L(moi)-min(L(moi))+1;
lag_cinds2 = lag_cinds - 3;
lag_cinds2(lag_cinds2<1) = 1;
lag_cinds2(lag_cinds>11) = 11;

% lag_cinds(lag_cinds<1) = 1;
% lag_cinds(lag_cinds>12) = 12;

colors = jet(max(lag_cinds2));

figure
imagesc(x,y,fliplr(I))
hold on
colormap(gray)
axis image
set(gca,'xTick',[],'yTick',[],'yDir','normal')
h = scatter(nx(moi),ny(moi),10,colors(lag_cinds2,:),'Filled');
h.MarkerFaceAlpha = 0.05;
set(gcf,'Position',[250 50 700 920])
saveas(gcf,[spath 'visual_plus_motion_map.fig'])
print([spath 'visual_plus_motion_map'],'-dpng','-r600')
print([spath 'visual_plus_motion_map'],'-depsc','-painters')

%%

Tm = T_all(moi,:);

[~,imx] = max( L(moi).*(R(moi)));
[~,imn] = max(-L(moi).*(R(moi)));

Ls = L(moi);
mx = Ls(imx);
mn = Ls(imn);

[~,m] = max(R(moi));

% SM = Sm;
% SM(Sm<0.1) = 0;
% SM = ones(6,1)*SM;
% SM = repmat(SM,[1 1 3]);
% SM(:,:,2:3) = 0;
% 
% figure;
% h=imagesc(t,-1:5,SM);
% hold on
% h.AlphaData = 0.75.*SM(:,:,1);
% plot(t,Tm(imx,:),'k-')
% plot(t,circshift(Tm(imx,:),mx,2),'r-')
% set(gca,'yDir','normal')
% 
% SM = Sm;
% SM(Sm<0.1) = 0;
% SM = ones(6,1)*SM;
% SM = repmat(SM,[1 1 3]);
% SM(:,:,1:2) = 0;
% 
% figure;
% h=imagesc(t,-1:5,SM);
% hold on
% h.AlphaData = 0.75.*SM(:,:,3);
% plot(t,Tm(imn,:),'k-')
% plot(t,circshift(Tm(imn,:),mn,2),'b-')
% set(gca,'yDir','normal')
% 
% SM = Sm;
% SM(Sm<0.1) = 0;
% SM = ones(6,1)*SM;
% SM = repmat(SM,[1 1 3]);
% SM(:,:,[1 3]) = 0;

% figure;
% h=imagesc(t,-1:5,SM);
% hold on
% h.AlphaData = 0.75.*SM(:,:,2);
% plot(t,Tm(m,:),'k-')
% plot(t,circshift(Tm(m,:),Ls(m),2),'b-','Color',[0 0.5 0])
% set(gca,'yDir','normal')

%% motion vs. z

nxm = nx(moi);
nym = ny(moi);
nzm = nz(moi);

alpha = 158/2500^2;
nzm = nzm - alpha.*((nxm-1500).^2 + (nym-2500).^2);

lastL = -12;
topLs = -10:2:6;
figure; 
for abc = 1:numel(topLs)
    subplot(3,3,abc)
    topL = topLs(abc);
    indsz = logical(Ls<=topL & Ls>lastL);
    histogram(nzm(indsz),0:50:500);
    xlabel('Z \mum)')
    bin = lastL+1./2.*(topL+lastL);
    lastL = topL;
    title(['t = ' num2str(bin./4.7) ' s'])
end


%% heat maps

tval = t(688);

% RSP

indsRSP = logical(nxm<437 & nym<2515);

TRSP = Tm(indsRSP,:);
TRSP = TRSP./(max(TRSP,[],2)*ones(1,T));

figure;
imagesc(t,1:size(TRSP,1),movmean(TRSP,5,2))
xlim([tval-5 tval+5])
caxis([0 .75])

% SSp 

indsSSp = logical(nxm>600 & nxm<1870 & nym < 3600 & nym>2500);
TSSp = Tm(indsSSp,:);
TSSp = TSSp./(max(TSSp,[],2)*ones(1,T));

figure;
imagesc(t,1:size(TSSp,1),movmean(TSSp,5,2))
xlim([tval-5 tval+5])
caxis([0 .75])

%% trial-averaging

Smthresh = Sm;
Smthresh(Smthresh<0.5) = 0;
Smthresh = movmean(Smthresh,3,2);
[pks,loc] = findpeaks(Smthresh);
num  = floor(4*4.7);

Tt = zeros(size(Tm,1),2*num+1);

for bb = 1:numel(loc)
    Tt = Tt + Tm(:,loc(bb)-num:loc(bb)+num);
end

Tt = Tt./5;
Tt = Tt./(max(Tt,[],2)*ones(1,2*num+1));
Tt = movmean(Tt,5,2);

tt = (-num:num)./4.7;

TtRSP = Tt(indsRSP,:);
TtSSp = Tt(indsSSp,:);

% figure;
% imagesc(tt,1:size(TtRSP,1),TtRSP);
% caxis([0 1])

% figure;
% imagesc(tt,1:size(TtSSp,1),TtSSp);
% caxis([0 1])
%%
[lgs,srt] = sort(Ls,'descend');
figure;
imagesc(tt,1:size(Tt,1),Tt(srt,:))
caxis([0.0 1])
hold on
plot(-lgs./4.7,1:size(Tt,1),'k-')
set(gca,'yDir','normal')
xlim([-3 3])
% set(gca,'xTick',[-3 -1 1 3])
set(gca,'yTick',[0 2 4 6 8].*10000,'yTicklabel',{'0' '20,000' '40,000' '60,000' '80,000'})
hhh = colorbar;
hhh.Ticks = [0 1]; hhh.TickLabels = {'0' 'DF/F0'};
xlabel('Time (s)')
ylabel('Neuron number')
set(gcf,'Position',[458   122   327   258])
% ylim([0 12000])
% set(gca,'yTick',[0:4000:12000],'yTickLabel',{'0','4,000','8,000','12,000'})
xlim([-3 3])
set(gca,'XColor',[0 0 0],'YColor',[ 0 0 0],'FontSize',12,'LineWidth',1)
saveas(gcf,[spath 'lag_example.fig'])
print([spath 'lag_example'],'-depsc','-painters')
print([spath 'lag_example'],'-dpng','-r600')

%% motion movie

filename = [spathm 'motion_lag_movie.avi'];

writerObj = VideoWriter(filename,'Uncompressed AVI');
writerObj.FrameRate = 25;
open(writerObj);

nym = ny(moi);
nxm = nx(moi);

lag_window = 3;
lag_start = -1.1; 
lag_increment = 0.2;
lag_end = max(lag_cinds)-1;
lag_vector = lag_start:lag_increment:lag_end;

colors = jet(max(lag_cinds));

for ijk = 1:numel(lag_vector)
    current_lag = lag_vector(ijk);
    lag_inds = logical(lag_cinds>current_lag & lag_cinds < current_lag+lag_window);
    
    figgg = figure(101);
    set(gcf,'Position',[50 50 700 920])
    clf;
    imagesc(x,y,fliplr(I))
    hold on
    colormap(gray)
    axis image
    caxis([0 6])
    set(gca,'xTick',[],'yTick',[],'yDir','normal')
    h = scatter(nxm(lag_inds),nym(lag_inds),10,colors(lag_cinds(lag_inds),:),'Filled');
    h.MarkerFaceAlpha = 0.1;
    drawnow
    
    frame = getframe;
    writeVideo(writerObj,frame);
end

close(writerObj);
close(figgg);

ffmpegtranscode(filename, [filename(1:end-3) 'mp4'], 'AudioCodec', 'aac', 'VideoCodec', 'x264', 'Mpeg4Quality',1);
