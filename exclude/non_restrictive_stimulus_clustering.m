clear
close all
clc

correct_z = true;

save_path = '\\v-storage.rockefeller.edu\vazirilab_medium_data\jeff_demas\MAxiMuM_data\Paper_Figures\Fig5\';
FontSize = 12;
LineWidth = 1;
falpha = 0.05;
fsize = 25;

%% Load data

load('neuron_coordinates_and_traces.mat')
load('thresholds.mat')

%% Image data

load('mean_brain_image.mat') % average brain intensity
x = (1:1:size(I,2)).*4.2; % x and y pixel arrays
y = (1:1:size(I,1)).*5;

nx = nx - max(x); nx = -nx;

if correct_z
    alpha = 158./2500^2;
    corrz = alpha.*((nx-1500).^2 + (ny-2500).^2);
    nz = nz-corrz;
end

%% Hierarchical clustering

n_stims = [sum(soi) sum(voi) sum(moi)]; % number of neurons in each stimulus
stim_inds = [100*ones(1,sum(soi)) 200*ones(1,sum(voi)) 300*ones(1,sum(moi))]; % vector of 100,200,300 for each stimulus

Tkk = [T_all(soi,:); T_all(voi,:); T_all(moi,:)]; % only positively correlated neurons
Rkk = corr(Tkk',Tkk'); % positively-stimulus-correlated neuron matrix

nxkk = [nx(soi); nx(voi); nx(moi)];
nykk = [ny(soi); ny(voi); ny(moi)];
nzkk = [nz(soi); nz(voi); nz(moi)];

% Z = linkage(Rkk,'ward','euclidean');
load(['linkage_' num2str(thr_num_sig) '_sigma.mat'])

%% Display

close all

hc = [0.5 0.5 1];
hsc = [1 0.5 0.5];

figure
histogram(Rrsa,-1.01:0.02:1.01,'FaceColor',hsc,'Normalization','probability');
hold on
histogram(Rsa,-1.01:0.02:1.01,'FaceColor',hc,'Normalization','probability');
xlim([-0.2 0.4])
xlabel('Correlation')
ylabel('Probability')
set(gcf,'Position',[360   489   300   180])
% ylim([0 3e4])
% set(gca,'yTick',[0 1 2 3].*1e4,'yTickLabels',{'0' '10,000','20,000','30,000'})
% legend('Shuffled','Whisker')
box(gca,'on')
set(gca,'XColor',[0 0 0],'YColor',[0 0 0 ],'FontSize',12,'LineWidth',LineWidth)
print([save_path 'whisker_correlation_histogram.png'],'-dpng','-r600')
print([save_path 'whisker_correlation_histogram'],'-depsc','-painters')
saveas(gcf,[save_path 'whisker_correlation_histogram.fig'])

figure
histogram(Rrva,-1.01:0.02:1.01,'FaceColor',hsc,'Normalization','probability');
hold on
histogram(Rva,-1.01:0.02:1.01,'FaceColor',hc,'Normalization','probability');
xlim([-0.2 0.4])
xlabel('Correlation')
ylabel('Probability')
set(gcf,'Position',[360   489   300   180])
% ylim([0 3e4])
% set(gca,'yTick',[0 1 2 3].*1e4,'yTickLabels',{'0' '10,000','20,000','30,000'})
% legend('Shuffled','Visual')
box(gca,'on')
set(gca,'XColor',[0 0 0],'YColor',[0 0 0 ],'FontSize',12,'LineWidth',LineWidth)
print([save_path 'visual_correlation_histogram.png'],'-dpng','-r600')
print([save_path 'visual_correlation_histogram'],'-depsc','-painters')
saveas(gcf,[save_path 'visual_correlation_histogram.fig'])

figure
histogram(Rrm,-1.01:0.02:1.01,'FaceColor',hsc,'Normalization','probability');
hold on
histogram(Rm,-1.01:0.02:1.01,'FaceColor',hc,'Normalization','probability');
xlim([-0.2 0.4])
xlabel('Correlation')
ylabel('Probability')
set(gcf,'Position',[360   489   300   180])
% ylim([0 3e4])
% set(gca,'yTick',[0 1 2 3].*1e4,'yTickLabels',{'0' '10,000','20,000','30,000'})
% legend('Shuffled','Motion')
box(gca,'on')
set(gca,'XColor',[0 0 0],'YColor',[0 0 0],'FontSize',12,'LineWidth',LineWidth)
print([save_path 'motion_correlation_histogram.png'],'-dpng','-r600')
print([save_path 'motion_correlation_histogram'],'-depsc','-painters')
saveas(gcf,[save_path 'motion_correlation_histogram.fig'])

max_clust = 4; % number of clusters

% Dendrogram
figure
dendrogram(Z,max_clust)

Tcl = cluster(Z,'maxclust',max_clust); % clustering

sortVec = stim_inds' + 10.*Tcl + mean(Rkk,2); % sorting vector -- 1st by stim (hundreds place), 2nd by cluster (tens place), 3rd by correlation (ones place)

[~,srt] = sort(sortVec,'ascend'); % sorting indices

nw = 2500;
TCL = zeros(numel(Tcl),nw,3);
Tcls = Tcl(srt);
for abc = 1:numel(Tcl)
    switch Tcls(abc)
        case 1
           TCL(abc,:,3) = ones(1,nw);
        case 2
            TCL(abc,:,2) = 0.5.*ones(1,nw);
        case 3
            TCL(abc,:,1) = ones(1,nw);
            TCL(abc,:,2) = 0.85.*ones(1,nw);
        case 4
            TCL(abc,:,1) = ones(1,nw);
    end
    
end

% Cluster map
h = figure;
imagesc(Rkk(srt,srt)) 
colormap(parula)
hold on
imagesc(-nw:-1,1:numel(Tcl),TCL)
imagesc(1:numel(Tcl),-nw:-1,permute(TCL,[2 1 3]))
axis image
set(gca,'yDir','normal')
caxis([-0.1 0.4])
hold on
plot([n_stims(1) n_stims(1)], [-nw size(Rkk,1)],'k-','LineWidth',1.5)
plot([n_stims(2)+n_stims(1) n_stims(2)+n_stims(1)], [-nw size(Rkk,1)],'k-','LineWidth',1.5)
plot([-nw size(Rkk,1)], [n_stims(1) n_stims(1)],'k-','LineWidth',1.5)
plot([-nw size(Rkk,1)], [n_stims(2)+n_stims(1) n_stims(2)+n_stims(1)],'k-','LineWidth',1.5)
plot([0 0], [-nw size(Rkk,1)],'k-','LineWidth',1.5)
plot([-nw size(Rkk,1)],[0 0],'k-','LineWidth',1.5)
hhh = colorbar;
set(gca,'xTick',(0:2:12).*1e4,'xTickLabel',{'0','20,000','40,000','60,000','80,000','100,000','120,000'})
set(gca,'yTick',(0:2:12).*1e4,'yTickLabel',{'0','20,000','40,000','60,000','80,000','100,000','120,000'})
set(h,'Position',[1 41 900 683])
set(hhh,'Location','manual','Units','normalized','Position',[0.8411    0.6735    0.0191    0.2518])
xlabel('Neuron number')
ylabel('Neuron number')
box(gca,'on')
set(gca,'XColor',[0 0 0],'YColor',[0 0 0 ],'FontSize',12,'LineWidth',LineWidth)
print([save_path 'correlation_matrix.png'],'-dpng','-r600')
print([save_path 'correlation_matrix'],'-depsc','-painters')

clust_colors = [0 0 1; 0 0.5 0; 1 0.85 0; 1 0 0];
corder = [1 2 3 4];

% clust_colors = jet(max_clust);
% corder = 1:max_clust;

for aa = 1:3
    
    si = logical(aa*100 == stim_inds);
    
    nxc = nxkk(si);
    nyc = nykk(si);
    nzc = nzkk(si);
    cc = Tcl(si);
    
    figure(100+aa)
    set(gcf,'Position',[250+(aa-1)*200 50 700 920])
    imagesc(x,y,fliplr(I));
    axis image
    set(gca,'yDir','normal','xTick',[],'yTick',[])
    xlim([min(x) max(x)])
    ylim([min(y) max(y)])
    hold on
    colormap(gray)

    for bb = 1:max_clust
        
        cid = corder(bb);
        
        icoi = logical(cc == cid);
        
        figure(100+aa)
        hh = scatter(nxc(icoi),nyc(icoi),fsize,clust_colors(bb,:),'Filled');
        hh.MarkerFaceAlpha = falpha;
        box(gca,'on')
        set(gca,'XColor',[0 0 0],'YColor',[0 0 0 ],'FontSize',12,'LineWidth',LineWidth)
    
%         figure(10+aa)
%         bar(bb,sum(icoi),'FaceColor',clust_colors(bb,:))
%         xlabel('Cluster number')
%         ylabel('Number of neurons')
%         hold on
%         box(gca,'on')
%         set(gca,'XColor',[0 0 0],'YColor',[0 0 0 ],'FontSize',12)
    
%         figure(1000+aa)
%         histogram(nzc(icoi),0:50:500,'FaceColor',clust_colors(bb,:))
%         xlabel('Z (\mum)')
%         ylabel('Number of neurons')
%         hold on
%         box(gca,'on')
%         set(gca,'XColor',[0 0 0],'YColor',[0 0 0 ],'FontSize',12)
    end
    
end

figure(101)
print([save_path 'whisker_cluster_map.png'],'-dpng','-r600')
print([save_path 'whisker_cluster_map'],'-depsc','-painters')
saveas(gcf,[save_path 'whisker_cluster_map.fig'])

figure(102)
print([save_path 'visual_cluster_map.png'],'-dpng','-r600')
print([save_path 'visual_cluster_map'],'-depsc','-painters')
saveas(gcf,[save_path 'visual_cluster_map.fig'])

figure(103)
print([save_path 'motion_cluster_map.png'],'-dpng','-r600')
print([save_path 'motion_cluster_map'],'-depsc','-painters')
saveas(gcf,[save_path 'motion_cluster_map.fig'])

%%

for zz = 1:max_clust
    figure
    set(gcf,'Position',[100 100 300 160])
    h = histogram(nzkk(Tcl == zz),-0:50:500,'FaceColor',clust_colors(zz,:));
    h.FaceAlpha = 1;
    xlabel('Z (\mum)')
    ylabel('Neurons')
    ylim([0 7500])
    xlim([0 500])
    set(gca,'yTick',[0 2500 5000 7500],'xTick',[0 125 250 375 500])
    box(gca,'on')
    set(gca,'XColor',[0 0 0],'YColor',[0 0 0 ],'FontSize',12,'LineWidth',LineWidth)
    print([save_path 'cluster_' num2str(zz) '_z_distribution.png'],'-dpng','-r600')
    print([save_path 'cluster_' num2str(zz) '_z_distribution'],'-depsc','-painters')
    saveas(gcf,[save_path 'cluster_' num2str(zz) '_z_distribution.fig'])
end

