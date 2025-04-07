clear
close all
clc

pixel_resolution = 5;
load('neuron_coordinates_and_traces.mat')
T_all = single(T_all);

load('mean_brain_image.mat')

save_path = '\\v-storage.rockefeller.edu\vazirilab_medium_data\jeff_demas\MAxiMuM_data\Paper_Figures\Fig5\';
FontSize = 12;
LineWidth = 1;

%% Threshold determination
% sigma = 0.0387;

% [Ns,edges] = histcounts(Rsr,-1:0.01:1);
% [Nv,~] = histcounts(Rvr,-1:0.01:1);
% [Nb,~] = histcounts(Rbr,-1:0.01:1);
% [Nm,~] = histcounts(Rmr,-1:0.01:1);
% 
% edges = edges(1:end-1)+diff(edges)/2;
% fts = fit(edges',Ns','gauss1');
% thr_up_s = fts.b1 + 3*fts.c1;
% thr_dn_s = fts.b1 + fts.c1;
% 
% ftv = fit(edges',Nv','gauss1');
% thr_up_v = ftv.b1 + 3*ftv.c1;
% thr_dn_v = ftv.b1 + ftv.c1;
% 
% ftb = fit(edges',Nb','gauss1');
% thr_up_b = ftb.b1 + 3*ftb.c1;
% thr_dn_b = ftb.b1 + ftb.c1;
% 
% ftm = fit(edges',Nm','gauss1');
% thr_up_m = ftm.b1 + 3*ftm.c1;
% thr_dn_m = ftm.b1 + ftm.c1;
% 
% thr_u = min([thr_dn_s thr_dn_m thr_dn_v thr_dn_b])/2;

%% Define subpopulations

Sbs = Ss-Sb;
Sbv = Sv-Sb;

Rbs = corr(Sbs',T_all');
Rbv = corr(Sbv',T_all');

noi = logical(Rbs < sigma & Rbv < sigma & Rb > 3*sigma & Rm < sigma);

% soi = logical(Rs > 3*sigma & Rv < sigma & Rm < sigma);
% voi = logical(Rv > 3*sigma & Rs < sigma & Rm < sigma);
% moi = logical(Rm > 3*sigma & Rv < sigma & Rs < sigma);

soi = logical(Rs > 6*sigma); 
voi = logical(Rv > 6*sigma);
moi = logical(Rm > 6*sigma);

uoi = logical(Rm < sigma/2 & Rv < sigma/2 & Rs < sigma/2);

x = (1:1:size(I,2)).*4.2;
y = (1:1:size(I,1)).*5;

nx = nx - max(x); nx = -nx;

% clearvars -except motion_lag save_path LineWidth FontSize nx ny nz soi voi noi moi x y T_all pixel_resolution rthr T I sigma uoi

%% Clustering of somatosensory-responsive neurons

inds = [find(soi) find(voi) find(noi) find(moi)];
stiminds = [ones(1,numel(find(soi))), 2*ones(1,numel(find(voi))), 3*ones(1,numel(find(noi))), 4*ones(1,numel(find(moi)))];
nstims = [numel(find(soi)) numel(find(voi)) numel(find(noi)) numel(find(moi))];
numstims = 4;

num_clust = numel(inds);%5e3;

Tkk = [T_all(soi,:) ; T_all(voi,:); T_all(noi,:); T_all(moi,:)];
Rkk = corr(Tkk',Tkk');
Rkkmean = mean(Rkk,2);

NXX = nx(inds(1:num_clust));
NYY = ny(inds(1:num_clust));
NZZ = nz(inds(1:num_clust));

Z = linkage(Rkk,'ward','euclidean');

% evalclusters(Rkk,'linkage','gap','KList',1:25,'Distance','Euclidean');
% OptimalK = ev_closters.OptimalK;

%% Display

ss = 25;
aa = .35;

close all 
max_clust = 5;

figure
dendrogram(Z,max_clust)

Tcl = cluster(Z,'maxclust',max_clust);

indxs = zeros(num_clust,1);
stind = 1;

if max_clust == 4
    C = [1 0.5 0; 0.5 0 0; 0 1 1; 1 0 1];
elseif max_clust == 6
    C = [0 0.5 0; 0 0 1; 1 1 0; 1 0.5 0; 1 0 0; 0.5 0 0];
else
    C = jet(max_clust);
end
    
RR = Rkkmean + 10*stiminds' + Tcl;

[~,v] = sort(RR,'ascend');

figure
% subplot(1,2,1)
imagesc(Rkk(v,v));
axis image
colormap(jet)
caxis([-0.2 0.6])
set(gca,'YDir','normal')
set(gca,'xTick',[0:5:20].*1e3,'xTickLabel',{'0','5,000','10,000','15,000','20,000'})
set(gca,'yTick',[0:5:20].*1e3,'yTickLabel',{'0','5,000','10,000','15,000','20,000'})

hold on

for ii = 1:numstims-1
    if ii == 1
        plot([0 numel(stiminds)],nstims(1)*[1 1],'k-','LineWidth',LineWidth)
        plot(sum(nstims(1:1))*[1 1],[0 numel(stiminds)],'k-','LineWidth',LineWidth)
    else
        plot([0 numel(stiminds)],sum(nstims(1:ii))*[1 1],'k-','LineWidth',LineWidth)
        plot(sum(nstims(1:ii))*[1 1],[0 numel(stiminds)],'k -','LineWidth',LineWidth)
    end
end

axis image
set(gcf,'Position',[50 50 900 713])
set(gca,'FontSize',FontSize,'LineWidth',LineWidth)
xlabel('Neuron number')
ylabel('Neuron number')
print([save_path 'clustered_correlations.png'],'-dpng','-r600')
print([save_path 'clustered_correlations'],'-depsc','-painters')
saveas(gcf,[save_path 'clustered_correlations.fig'])

for cc =  1:numstims
    
    if cc == 1
        NXXn = NXX(1:nstims(cc));
        NYYn = NYY(1:nstims(cc));
    else
        NXXn = NXX(nstims(cc-1):sum(nstims(1:cc)));
        NYYn = NYY(nstims(cc-1):sum(nstims(1:cc)));
    end
    
    figure(100+cc);
    set(gcf,'Position',[250+(cc-1)*200 50 700 920])
    imagesc(x,y,fliplr(I)); colormap(gray)
    set(gca,'YDir','normal','xTick',[],'yTick',[])
    hold on
    
    for dd = 1:max_clust
        figure(100+cc);
        clust_inds = logical((Tcl == dd) & (stiminds' == cc));
        hhh=scatter(NXX(clust_inds),NYY(clust_inds),ss,C(dd,:),'Filled');
        hhh.MarkerFaceAlpha = aa;
        axis image
        
        figure(10+cc);
        hold on
        histogram(NZZ(clust_inds),0:50:500,'FaceColor',C(dd,:))
        xlabel('Z (\mum)')
        ylabel('Neurons')
        
    end

end

figure(101); 
plot(100:600,100.*ones(1,501),'r-','LineWidth',LineWidth)
print([save_path 'som_cluster_map.png'],'-dpng','-r600')
print([save_path 'som_cluster_map'],'-depsc','-painters')
saveas(gcf,[save_path 'som_cluster_map.fig'])

figure(102); 
plot(100:600,100.*ones(1,501),'r-','LineWidth',LineWidth)
print([save_path 'vis_cluster_map.png'],'-dpng','-r600')
print([save_path 'vis_cluster_map'],'-depsc','-painters')
saveas(gcf,[save_path 'vis_cluster_map.fig'])

figure(103); 
plot(100:600,100.*ones(1,501),'r-','LineWidth',LineWidth)
print([save_path 'both_cluster_map.png'],'-dpng','-r600')
print([save_path 'both_cluster_map'],'-depsc','-painters')
saveas(gcf,[save_path 'both_cluster_map.fig'])

figure(104);
plot(100:600,100.*ones(1,501),'r-','LineWidth',LineWidth)
print([save_path 'motion_cluster_map.png'],'-dpng','-r600')
print([save_path 'motion_cluster_map'],'-depsc','-painters')
print(gcf,[save_path 'motion_cluster_map.fig'])

som_inds = RR(RR>10 & RR<20)-10;
som_num_per_cluster = zeros(1,max_clust);

vis_inds = RR(RR>20 & RR<30)-20;
vis_num_per_cluster = zeros(1,max_clust);

both_inds = RR(RR>30 & RR<40)-30;
both_num_per_cluster = zeros(1,max_clust);

motion_inds = RR(RR>40 & RR<50)-40;
motion_num_per_cluster = zeros(1,max_clust);

for ee = 1:max_clust
    som_num_per_cluster(ee) = sum(logical(som_inds(som_inds>ee & som_inds<(ee+1))));
    vis_num_per_cluster(ee) = sum(logical(vis_inds(vis_inds>ee & vis_inds<(ee+1))));
    both_num_per_cluster(ee) = sum(logical(both_inds(both_inds>ee & both_inds<(ee+1))));
    motion_num_per_cluster(ee) = sum(logical(motion_inds(motion_inds>ee & motion_inds<(ee+1))));

end

% mxv = max([som_num_per_cluster vis_num_per_cluster both_num_per_cluster motion_num_per_cluster]);
% mxv = ceil(1.00*mxv/1000);
% mxv = mxv*1000;
mxv = 5000;

corder = [2 1 3:6];%[3 4 1 2 5 6];

for ff = 1:max_clust

    figure(1001)
    set(gcf,'Position',[234 231 260 150])
    bar(corder(ff),som_num_per_cluster(ff),'FaceColor',C(ff,:),'LineWidth',LineWidth)
    xlabel('Cluster')
    ylabel('Neurons')
    set(gca,'FontSize',FontSize,'LineWidth',LineWidth)
    set(gca,'xTick',[1:max_clust])
    xlim([0.5 max_clust+0.5])
    ylim([0 mxv])
%     title('Somatosensory stimulus')
    hold on

    figure(1002)
    set(gcf,'Position',[433 231 260 150])
    bar(corder(ff),vis_num_per_cluster(ff),'FaceColor',C(ff,:),'LineWidth',LineWidth)
    xlabel('Cluster')
    ylabel('Neurons')
    set(gca,'FontSize',FontSize,'LineWidth',LineWidth)
    set(gca,'xTick',[1:max_clust])
    xlim([0.5 max_clust+0.5])
    ylim([0 mxv])
%     title('Visual stimulus')
    hold on

    figure(1003)
    set(gcf,'Position',[632 231 260 150])
    bar(corder(ff),both_num_per_cluster(ff),'FaceColor',C(ff,:),'LineWidth',LineWidth)
    xlabel('Cluster')
    ylabel('Neurons')
    set(gca,'FontSize',FontSize,'LineWidth',LineWidth)
    set(gca,'xTick',[1:max_clust])
    xlim([0.5 max_clust+0.5])
    ylim([0 mxv])
%     title('Both som. and vis. stimulus')
    hold on

    figure(1004)
    set(gcf,'Position',[831 231 260 150])
    bar(corder(ff),motion_num_per_cluster(ff),'FaceColor',C(ff,:),'LineWidth',LineWidth)
    xlabel('Cluster')
    ylabel('Neurons')
    set(gca,'FontSize',FontSize,'LineWidth',LineWidth)
    set(gca,'xTick',[1:max_clust])
    xlim([0.5 max_clust+0.5])
%     title('Mouse movement')
    hold on

    ylim([0 mxv])
end

figure(1001); 
set(gca,'yTick',[0 2500 5000 7500])
print([save_path 'som_cluster_bar.png'],'-dpng','-r600')
print([save_path 'som_cluster_bar'],'-depsc','-painters')
saveas(gcf,[save_path 'som_cluster_bar.fig'])

figure(1002); 
set(gca,'yTick',[0 2500 5000 7500])
print([save_path 'vis_cluster_bar.png'],'-dpng','-r600')
print([save_path 'vis_cluster_bar'],'-depsc','-painters')
saveas(gcf,[save_path 'vis_cluster_bar.fig'])

figure(1003); 
set(gca,'yTick',[0 2500 5000 7500])
print([save_path 'both_cluster_bar.png'],'-dpng','-r600')
print([save_path 'both_cluster_bar'],'-depsc','-painters')
saveas(gcf,[save_path 'both_cluster_bar.fig'])

figure(1004); 
set(gca,'yTick',[0 2500 5000 7500])
print([save_path 'motion_cluster_bar.png'],'-dpng','-r600')
print([save_path 'motion_cluster_bar'],'-depsc','-painters')
saveas(gcf,[save_path 'motion_cluster_bar.fig'])


%% Example of only whisker + visual tuned neurons

d = load('neuron_coordinates_and_traces.mat','Rb','t');
Rb = d.Rb;
t = d.t;

Tnoi = T_all(noi,:);
Rnoi = Rb(noi);
[Rnoi,noisrt] = sort(Rnoi,'descend');

Nn = 25;

figure
plot(t,movmean(Tnoi(1:Nn,:),5,2) + (1:Nn)'*ones(1,T))

%% Distribution of correlations of each cluster with different motions

load('tracking_data2.mat')

tau = 0.55/log(2);
tt = t-t(dsearchn(t',2));
kernel = exp(tt./0.2);
kernel(tt>=0) = exp(-tt(tt>=0)./tau);

sa = conv(sa,kernel,'full');
sa = sa(1:numel(t));

swl = conv(swl,kernel,'full');
swl = swl(1:numel(t));

swr = conv(swr,kernel,'full');
swr = swr(1:numel(t));

sm = conv(sm,kernel,'full');
sm = sm(1:numel(t));

sa = circshift(sa,motion_lag,2);
swl = circshift(swl,motion_lag,2);
swr = circshift(swr,motion_lag,2);
sm = circshift(sm,motion_lag,2);


Tmotion = Tkk(end-nstims(4)+1:end,:);
RRm = corr(sm',Tmotion');

figure;
histogram(RRm)

Tmotion = Tkk(end-nstims(4)+1:end,:);
Cmotion = Tcl(end-nstims(4)+1:end);

Rmotion = corr(Tmotion',circshift(sm,motion_lag,2)');

for abc = 3:6
    
    Cinds = logical(Cmotion==abc);
    
    Rsa = corr(sa',Tmotion(Cinds,:)');
    Rswl = corr(swl',Tmotion(Cinds,:)');
    Rswr = corr(swr',Tmotion(Cinds,:)');
    
    figure
    h1 = histogram(Rsa,100);
    BinEdges = h1.BinEdges;
    hold on
    h2 = histogram(Rswl,'BinEdges',BinEdges);
    h3 = histogram(Rswr,'BinEdges',BinEdges);
    legend('Ankle','Left wrist','Right Wrist')
    title(['Cluster ' num2str(abc) ])
    
    BinEdges = BinEdges(1:end-1) + diff(BinEdges)/2;
    
    C1 = h1.Values;
    C2 = h2.Values;
    C3 = h3.Values;

    ft1 = fit(BinEdges',C1','gauss1');
    ft2 = fit(BinEdges',C2','gauss1');
    ft3 = fit(BinEdges',C3','gauss1');

    plot(BinEdges,ft1(BinEdges),'k-');
    plot(BinEdges,ft2(BinEdges),'k-');
    plot(BinEdges,ft3(BinEdges),'k-');
    
    figure
%     bar(1:3,[mean(Rsa) mean(Rswl) mean(Rswr)],'FaceColor',C(abc,:))
    bar(1:3,[ft1.b1 ft2.b1 ft3.b1],'FaceColor',C(abc,:))
    hold on
    errorbar(1:3,[ft1.b1 ft2.b1 ft3.b1],[ft1.c1 ft2.c1 ft3.c1],'o','MarkerSize',10,'Color','k')
    set(gca,'xTick',[1 2 3])
    set(gca,'xTickLabel',{'Ankle','Left wrist','Right wrist'})
    title(['Cluster ' num2str(abc)])
    
end