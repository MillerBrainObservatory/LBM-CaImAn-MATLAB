close all
clear all
clc

spath = 'D:\Jeffs LBM paper data\Fig4d-g\20191122';
open(fullfile(spath, 'pollen_calibration_power_linear.fig'));

lns = get(gca,'Children');

delete(lns(2:3))
%%
set(lns(1),'Color','k')

lns = get(gca,'Children');

l2 = lns(2);
l3 = lns(3);

legend(lns([2 3 1]),'Cavity 1','Cavity 2','Fit (ls = 221um)','Location','NorthWest','FontSize',12)

ylim([0 80])

x2 = l2.XData-16;
y2 = l2.YData;

x3 = l3.XData-16;
y3 = l3.YData;

cal = 450./4.676./sum(y2+y3);

figure
plot(x2,y2.*cal,'rsquare','Color',[1 0 0],'MarkerSize',6)
hold on
plot(x3,y3.*cal,'r^','Color',[0.5 0 0],'MarkerSize',6)
ft = fit([x2 x3]',cal.*[y2 y3]','exp1');
plot(0:600,ft((0:600)'),'k-')
legend('Cavity A','Cavity B','Fit (r2 = 221mm)','Location','NorthWest','FontSize',12)
xlabel('Z (mm)')
xlim([0 500])
% ylim([0 80])
grid(gca,'off')
ylabel('Power (a.u.)')
set(gca,'XColor',[0 0 0],'YColor',[0 0 0],'LineWidth',1,'FontSize',12)
set(gcf,'Position',[189   600   378   200])
print([spath 'pollen_calibration_power_linear.png'],'-painters','-dpng','-r600')
print([spath 'pollen_calibration_power_linear.eps'],'-painters','-depsc','-r600')
saveas(gcf,[spath 'pollen_calibration_power_linear.fig'])

norm = 1e9.*450e-3./4.7e6./sum([y2 y3]);

figure;
plot(x2,y2.*norm.*exp(-x2./200),'rsquare','Color',[1 0 0],'MarkerSize',6)
hold on
plot(x3,y3.*norm.*exp(-x3./200),'r^','Color',[0.5 0 0],'MarkerSize',6)
legend('Cavity A','Cavity B','Location','SouthWest','FontSize',12)
xlabel('Z (mm)')
xlim([0 500])
ylim([0 1])
grid(gca,'off')
ylabel('Pulse energy(nJ)')
set(gca,'XColor',[0 0 0],'YColor',[0 0 0],'LineWidth',1,'FontSize',12)
set(gcf,'Position',[189   548   378   200])
print([spath 'pollen_calibration_pulse_energy_in_sample.png'],'-painters','-dpng','-r600')
print([spath 'pollen_calibration_pulse_energy_in_sample.eps'],'-painters','-depsc','-r600')
saveas(gcf,[spath 'pollen_calibration_pulse_energy_in_sample.fig'])

%%

open('pollen_calibration_z_vs_N.fig')

lns = get(gca,'Children');

lns(2).Marker = '^';
lns(2).Color = [0.5 0 0];
lns(3).Marker = 'square';
lns(3).Color = [1 0 0];
legend(lns([2 3 1]),'Cavity A','Cavity B','Fit (r2 = 0.98)','Location','NorthWest','FontSize',12) 

yy = [fliplr(lns(2).YData) fliplr(lns(3).YData)]+50;
coeff = polyfit((1:30)',yy',1);

figure
plot(1:15,fliplr(lns(2).YData)+50,'rsquare','MarkerSize',6)
hold on
plot(16:30,fliplr(lns(3).YData)+50,'r^','Color',[0.5 0 0],'MarkerSize',6)
plot(0:31,polyval(coeff,0:31),'k-');
xlabel('Beam number')
set(gcf,'Position',[188   451   378   200])
legend('Cavity A','Cavity B','Fit (r2 = 0.98)')
% grid(gca,'on')
ylabel('Z position (mm)')

% set(gca,'yTickLabel',{'50','150','250','350','450','550'})
set(gca,'XColor',[0 0 0],'YColor',[0 0 0],'LineWidth',1,'FontSize',12)

xlim([0 30])

print([spath 'pollen_calibration_z_vs_N.png'],'-painters','-dpng','-r600')
print([spath 'pollen_calibration_z_vs_N.eps'],'-painters','-depsc','-r600')
saveas(gcf,[spath 'pollen_calibration_z_vs_N.fig'])

%% 

open('pollen_calibration_x_y_offsets.fig')

h = findobj(gca,'Type','line');
x=get(h,'Xdata');
y=get(h,'Ydata');

x1 = x{1,1};
x2 = x{2,1};
y1 = y{1,1};
y2 = y{2,1};

ym = mean([y1 y2]);
xm = mean([x1 x2]);

figure;
plot(y1-ym,x1-xm,'rsquare','Color',[1 0 0],'MarkerSize',6)
hold on
plot(y2-ym,x2-xm,'r^','Color',[0.5 0 0],'MarkerSize',6)
legend('Cavity A','Cavity B','Location','NorthEast','FontSize',12)
axis image
% set(gcf,'Position',[])
grid(gca,'off')
ylim([-50 50])
xlim([-100 100])
set(gca,'XColor',[0 0 0],'YColor',[0 0 0],'LineWidth',1,'FontSize',12)
xlabel('X (mm)')
ylabel('Y (mm)')
set(gcf,'Position',[514   242   378   200])
print([spath 'calibration_xy_offsets.png'],'-painters','-dpng','-r600')
print([spath 'calibration_xy_offsets.eps'],'-painters','-depsc','-r600')
saveas(gcf,[spath 'calibration_xy_offsets.fig'])

%%

load('\\v-storage.rockefeller.edu\vazirilab_medium_data\jeff_demas\MAxiMuM_data\20200306\pulse_durations_MAxiMuM_30x.mat')
figure;
plot(1:15,tau(1:15),'rsquare','Color',[1 0 0],'MarkerSize',6)
hold on
plot(16:30,tau(16:30),'r^','Color',[0.5 0 0],'MarkerSize',6)
ylim([0 200])
xlim([0 30])
grid(gca,'off')
legend('Cavity A','Cavity B','Location','SouthEast','FontSize',12)
xlabel('Beam number')
set(gca,'XColor',[0 0 0],'YColor',[0 0 0],'LineWidth',1,'FontSize',12)
ylabel('Pulse duration (fs)')
set(gcf,'Position',[188   451   378   200])
print([spath 'pulse_durations.png'],'-painters','-dpng','-r600')
print([spath 'pulse_durations.eps'],'-painters','-depsc','-r600')
saveas(gcf,[spath 'pulse_durations.fig'])

%%

open('\\v-storage.rockefeller.edu\vazirilab_medium_data\jeff_demas\MAxiMuM_data\20200306\MH132\crosstalk_measurements.fig')
set(gcf,'Position',[188   451   378   250])
lns = get(gca,'Children');
lns(2).Marker = '^';
lns(2).MarkerSize = 6;
lns(2).Color = [0.5 0.5 1];
lns(2).LineWidth = 1;
set(gca,'XColor',[0 0 0],'YColor',[0 0 0],'LineWidth',1,'FontSize',12)
set(gca,'xTick',[1:15],'xTickLabel',{'16','','','','','','','23','','','','','','','30'})
xlim([0 16])
grid(gca,'off')
print([spath 'crosstalk.png'],'-painters','-dpng','-r600')
print([spath 'crosstalk.eps'],'-painters','-depsc','-r600')
saveas(gcf,[spath 'crosstalk.fig'])

%% PSF stuff

path = '\\v-storage.rockefeller.edu\vazirilab_medium_data\jeff_demas\MAxiMuM_data\20200227\Normal_Res_PSFs\';

open([path 'fwhm_xy_summary.fig'])
xlim([0 30])
print([spath 'psf_xy_summary.png'],'-painters','-dpng','-r600')
print([spath 'psf_xy_summary.eps'],'-painters','-depsc','-r600')

saveas(gcf,[spath 'psf_xy_summary.fig'])

open([path 'fwhm_z_summary.fig'])
xlim([0 30])
print([spath 'psf_z_summary.png'],'-painters','-dpng','-r600')
print([spath 'psf_z_summary.eps'],'-painters','-depsc','-r600')

saveas(gcf,[spath 'psf_z_summary.fig'])