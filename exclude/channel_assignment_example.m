clear;
close all
clc

save_folder = '\\v-storage.rockefeller.edu\vazirilab_medium_data\jeff_demas\MAxiMuM_data\Paper_Figures\SFig2\';

load('cross_talk_data_set.mat')

v = reshape(mean(mean(v,1),2),1,[]);

colors = lines(7);

figure
plot((0+(1:32))./1.614, v,'-r.','Color',colors(1,:),'MarkerSize',10)
hold on
plot((11+(1:32))./1.614, v,'-r.','Color',colors(2,:),'MarkerSize',10)
plot((22+(1:32))./1.614, v,'-r.','Color',colors(3,:),'MarkerSize',10)
xlim([0 25])
ylim([-0 250])
set(gca,'FontSize',12,'LineWidth',1)
set(gca,'XColor',[0 0 0],'yColor',[0 0 0 ])
xlabel('Time (ns)')
ylabel('Fluorescence (a.u.)')
set(gcf,'Position',[200 200 600 300])
set(gcf,'Color',[1 1 1])

print([save_folder 'channel_definition_example'],'-painters','-depsc','-r600')