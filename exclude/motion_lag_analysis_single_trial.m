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

Tm = T_all(moi,:);

[~,imx] = max( L(moi).*(R(moi)));
[~,imn] = max(-L(moi).*(R(moi)));

Ls = L(moi);
mx = Ls(imx);
mn = Ls(imn);

Smthresh = Sm;
Smthresh(Smthresh<0.5) = 0;
Smthresh = movmean(Smthresh,3,2);
[pks,loc] = findpeaks(Smthresh);

time_in = loc(3);

[lgs,srt] = sort(Ls,'descend');

figure;
imagesc(tt-tt(time_in),1:size(Tm,1),movmean(Tm(srt,:),5,2))
caxis([0.0 1])
hold on
plot(-lgs./4.7,1:size(Tm,1),'k-')
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
saveas(gcf,[spath 'lag_example_single_trial.fig'])
print([spath 'lag_example_single_trial'],'-depsc','-painters')
print([spath 'lag_example_single_trial'],'-dpng','-r600')

