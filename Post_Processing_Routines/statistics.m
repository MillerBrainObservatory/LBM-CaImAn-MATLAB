% Statistics

close all
spath = '\\v-storage.rockefeller.edu\vazirilab_medium_data\jeff_demas\MAxiMuM_data\Paper_Figures\SFig3\';


neurons = [207030 186684 225756 159191 245351 259884 206727 233435 459949 276565 338385 218950];

mnn = mean(neurons);
stn = std(neurons);
figure;
plot(neurons,'b.','MarkerSize',14);
hold on
h = fill([0:numel(neurons)+1, fliplr(0:numel(neurons)+1)],[(mnn-stn).*ones(1,numel(neurons)+2) fliplr((mnn+stn).*ones(1,numel(neurons)+2))],'b','LineStyle','none');
h.FaceAlpha = 0.2;
plot(0:numel(neurons)+1,mnn.*ones(1,numel(neurons)+2),'k-')
% plot(0:numel(neurons)+1,(mnn-stn).*ones(1,numel(neurons)+2),'k-')
% plot(0:numel(neurons)+1,(mnn+stn).*ones(1,numel(neurons)+2),'k-')
ylim([0 5e5])
xlim([0 numel(neurons)+1])
xlabel('Data set')
ylabel('Neurons')
set(gca,'yTick',[0:1.25:5].*1e5,'yTickLabel',{'0','125,000','250,000','375,000','500,000'})
set(gca,'xTick',[2:2:12])
set(gca,'XColor',[0 0 0],'YColor',[0 0 0],'LineWidth',1,'FontSize',12)
set(gcf,'Position',[189   248   378   200])
saveas(gcf,[spath 'single_hemisphere_stats.fig'])
print(gcf,[spath 'single_hemisphere_stats.eps'],'-depsc','-painters')

neurons = [807748 1068455 1065289];

mnn = mean(neurons);
stn = std(neurons);
figure;
plot(neurons,'r.','MarkerSize',14);
hold on
h = fill([0:numel(neurons)+1, fliplr(0:numel(neurons)+1)],[(mnn-stn).*ones(1,numel(neurons)+2) fliplr((mnn+stn).*ones(1,numel(neurons)+2))],'r','LineStyle','none');
h.FaceAlpha = 0.2;
plot(0.5:numel(neurons)+.5,mnn.*ones(1,numel(neurons)+1),'k-')
% plot(0.5:numel(neurons)+.5,(mnn-stn).*ones(1,numel(neurons)+1),'k--')
% plot(0.5:numel(neurons)+.5,(mnn+stn).*ones(1,numel(neurons)+1),'k--')
ylim([6e5 1.2e6])
xlim([0.75 numel(neurons)+0.25])
xlabel('Data set')
ylabel('Neurons')
set(gca,'xTick',[1 2 3],'yTick',[0.6:0.2:1.2].*1e6,'yTickLabel',{'600,000','800,000','1,000,000','1,200,000'})
set(gca,'XColor',[0 0 0],'YColor',[0 0 0],'LineWidth',1,'FontSize',12)
set(gcf,'Position',[500   248   378   200])
saveas(gcf,[spath 'bi_hemisphere_stats.fig'])
print(gcf,[spath 'bi_hemisphere_stats.eps'],'-depsc','-painters')

%%
% wtn = [34 NaN NaN NaN 35 23 28 26 15 NaN 10];
% vtn = [24 NaN NaN NaN 18 17 20 23 20 NaN 15];
% 
% figure;
% plot(1:10,wtn,'r.','MarkerSize',14)
% hold on
% plot(1:10,ones(1,10).*nanmean(wtn),'k--')
% plot(1:10,ones(1,10).*(nanmean(wtn)-nanstd(wtn)),'k--')
% plot(1:10,ones(1,10).*(nanmean(wtn)+nanstd(wtn)),'k--')
% xlim([0 11])
% xlabel('data set #')
% ylabel('number of whisker-tuned neurons')
% ylim([0 50])
% 
% figure;
% plot(1:10,vtn,'r.','Color',[0 0.5 0],'MarkerSize',14)
% hold on
% plot(1:10,ones(1,10).*nanmean(vtn),'k--')
% plot(1:10,ones(1,10).*(nanmean(vtn)-nanstd(vtn)),'k--')
% plot(1:10,ones(1,10).*(nanmean(vtn)+nanstd(vtn)),'k--')
% xlim([0 11])
% xlabel('data set #')
% ylim([0 50])
% ylabel('number of visual-tuned neurons')