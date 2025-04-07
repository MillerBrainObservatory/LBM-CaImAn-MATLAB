clear
close all
clc

pixel_resolution = 5;
load('neuron_coordinates_and_traces.mat')
T_all = single(T_all);

load('mean_brain_image.mat')

load('thresholds.mat')

save_path = '\\v-storage.rockefeller.edu\vazirilab_medium_data\jeff_demas\MAxiMuM_data\Paper_Figures\Fig6\';
% save_path = '/vmd/jeff_demas/MAxiMuM_data/Paper_Figures/Fig6/';

FontSize = 12;
LineWidth = 1;

ns = 3;

%% Define subpopulations

x = (1:1:size(I,2)).*4.2;
y = (1:1:size(I,1)).*5;

nx = nx - max(x); nx = -nx;

colors = lines(7);

NX = nx; NY = ny;

%% Somatosensory stimulus
Ts = T_all(soi,:); 
corr_som = corr(Ts',Ts');

Ts_shuffled = zeros(size(Ts));

for abc = 1:size(Ts,1)
    Tcurrent = Ts(abc,:);
    Tcurrent = circshift(Tcurrent,randi(T,1),2);
    Ts_shuffled(abc,:) = Tcurrent;
end

corr_som_shuffled = corr(Ts_shuffled',Ts_shuffled');

pd = fitdist(corr_som_shuffled(:),'normal');
som_thresh = pd.mu+ns.*pd.sigma;

nxs = NX(soi);
nxs = single(nxs*ones(1,numel(nxs)));

nys = NY(soi);
nys = single(nys*ones(1,numel(nys)));

nzs = nz(soi);
nzs = single(nzs*ones(1,numel(nzs)));

DS = sqrt((nxs-nxs').^2 + (nys-nys').^2 + (nzs-nzs').^2);

DS(DS==0) = NaN;
% DS(corr_som>som_thresh) = NaN;
DS(corr_som<som_thresh) = NaN;

[Ns,edges] = histcounts(DS./1000,-0.0625:0.125:5.0625,'Normalization','cdf');
edges = edges(1:end-1)+diff(edges)/2;

clear DS corr_som corr_som_shuffled

%% Visual stimulus
Tv = T_all(voi,:); 
corr_vis = corr(Tv',Tv');

Tv_shuffled = zeros(size(Tv));

for abc = 1:size(Tv,1)
    Tcurrent = Tv(abc,:);
    Tcurrent = circshift(Tcurrent,randi(T,1),2);
    Tv_shuffled(abc,:) = Tcurrent;
end

corr_vis_shuffled = corr(Tv_shuffled',Tv_shuffled');

pd = fitdist(corr_vis_shuffled(:),'normal');
vis_thresh = pd.mu+ns.*pd.sigma;

nxv = NX(voi);
nxv = single(nxv*ones(1,numel(nxv)));

nyv = NY(voi);
nyv = single(nyv*ones(1,numel(nyv)));

nzv = nz(voi);
nzv = single(nzv*ones(1,numel(nzv)));

DV = sqrt((nxv-nxv').^2 + (nyv-nyv').^2 + (nzv-nzv').^2);

DV(DV==0) = NaN;
% DV(corr_vis>vis_thresh) = NaN;
DV(corr_vis<vis_thresh) = NaN;

[Nv,edges] = histcounts(DV./1000,-0.0625:0.125:5.0625,'Normalization','cdf');

clear DV corr_visual corr_visual_shuffled

%% Motion stimulus
Tm = T_all(moi,:); 
corr_motion = corr(Tm',Tm');

Tm_shuffled = zeros(size(Tm));

for abc = 1:size(Tm,1)
    Tcurrent = Tm(abc,:);
    Tcurrent = circshift(Tcurrent,randi(T,1),2);
    Tm_shuffled(abc,:) = Tcurrent;
end

corr_motion_shuffled = corr(Tm_shuffled',Tm_shuffled');

pd = fitdist(corr_motion_shuffled(:),'normal');
motion_thresh = pd.mu+ns.*pd.sigma;

nxm = NX(moi);
nxm = single(nxm*ones(1,numel(nxm)));

nym = NY(moi);
nym = single(nym*ones(1,numel(nym)));

nzm = nz(moi);
nzm = single(nzm*ones(1,numel(nzm)));

DM = sqrt((nxm-nxm').^2 + (nym-nym').^2 + (nzm-nzm').^2);

DM(DM==0) = NaN;
% DM(corr_motion>motion_thresh) = NaN;
DM(corr_motion<motion_thresh) = NaN;

[Nm,edges] = histcounts(DM./1000,-0.0625:0.125:5.0625,'Normalization','cdf');

clear DM corr_motion corr_motion_shuffled

%% No stimulus
Tu = T_all(uoi,:); 
corr_uncorr = corr(Tu',Tu');

Tu_shuffled = zeros(size(Tu));

for abc = 1:size(Tu,1)
    Tcurrent = Tu(abc,:);
    Tcurrent = circshift(Tcurrent,randi(T,1),2);
    Tu_shuffled(abc,:) = Tcurrent;
end

corr_uncorr_shuffled = corr(Tu_shuffled',Tu_shuffled');

pd = fitdist(corr_uncorr_shuffled(:),'normal');
mu = pd.mu;
sigma = pd.sigma;

uncorr_thresh = mu+ns.*sigma;

nxu = NX(uoi);
nxu = single(nxu*ones(1,numel(nxu)));

nyu = NY(uoi);
nyu = single(nyu*ones(1,numel(nyu)));

nzu = nz(uoi);
nzu = single(nzu*ones(1,numel(nzu)));

DU = sqrt((nxu-nxu').^2 + (nyu-nyu').^2 + (nzu-nzu').^2);

DU(DU==0) = NaN;
% DU(corr_uncorr>uncorr_thresh) = NaN;
DU(corr_uncorr<uncorr_thresh) = NaN;

[Nu,edges] = histcounts(DU./1000,-0.0625:0.125:5.0625,'Normalization','cdf');
edges = edges(1:end-1)+diff(edges)/2;

clear DU corr_uncorr corr_uncorr_shuffled

%%

colors = [0 0 1; 0 0.5 0; 1 0 0; 1 0 1];

figure
set(gcf,'Position',[100 100 595 516]);
plot(edges,Ns,'r-','Color',colors(1,:))
hold on
plot(edges,Nv,'r-','Color',colors(2,:))
plot(edges,Nm,'r-','Color',colors(3,:))
plot(edges,Nu,'r-','Color',colors(4,:))
legend('Whisker-tuned','Visual-tuned','Behavior-tuned','Uncorrelated','Location','SouthEast')
xlabel('Neuron-to-neuron distance (mm)')
ylabel('Cumulative probability')
set(gca,'FontSize',12,'LineWidth',1,'XColor',[0 0 0],'YColor',[0 0 0])
% print([save_path 'cum_probability_distance.png'],'-dpng','-r600')
% print([save_path 'cum_probability_distance'],'-depsc','-painters')
% saveas(gcf,[save_path 'cum_probability_distance.fig'])
% 

