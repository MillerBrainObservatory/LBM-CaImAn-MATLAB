clear
close all
clc

load('neuron_coordinates_and_traces.mat')
T_all = single(T_all);

save_path = '\\v-storage.rockefeller.edu\vazirilab_medium_data\jeff_demas\MAxiMuM_data\Paper_Figures\Fig4\';
FontSize = 12;
LineWidth = 1;

load('mean_brain_image.mat')

%%

thr = 1.5;

nx = nx - 3000; nx = -nx;
% NY - max(y); NY = -NY;

Tm = max(movmean(T_all,5,2),[],2);

num = round(K/1);
zaspect = 2.5;

dfmx = 3;

[Tm,inds] = sort(Tm,'descend');
NX = nx(inds);
NY = ny(inds);
nz = nz(inds);

Tm = Tm(1:num);
Tmm = Tm;

Tmm(Tmm>dfmx) = dfmx;

Tmm = Tmm-min(Tmm);
Tmm = Tmm./max(Tmm);
Tmm = round(Tmm.*255) + 1;

C = parula(256);

Cmm = C(Tmm,:);

NXon = NX(1:num);
NYon = NY(1:num);
NZon = nz(1:num);
Con = Cmm;

NXoff = NXon;
NYoff = NYon;
NZoff = NZon;
Coff = Con;

NXon = NXon(Tm>thr);
NYon = NYon(Tm>thr);
NZon = NZon(Tm>thr);
Con  = Con(Tm>thr);

NXoff = NXoff(Tm<=thr);
NYoff = NYoff(Tm<=thr);
NZoff = NZoff(Tm<=thr);
Coff  = Coff(Tm<=thr);


figure
set(gcf,'Position',[574   440   666   560])
scatter3(NXon./1000,NYon./1000,(-50-zaspect.*NZon)./1000,10,Con,'Filled','MarkerFaceAlpha',.75)
hold on
scatter3(NXoff./1000,NYoff./1000,(-50-zaspect.*NZoff)./1000,10,Coff,'Filled','MarkerFaceAlpha',.25)
axis equal
view(45,30)
set(gcf,'Color',[0 0 0])
set(gca,'Color',[0 0 0])
zlim([-1.25 0])
xlim([0 3])
ylim([0 5])
set(gcf,'InvertHardcopy','off')
set(gca,'zTick',[-1.25 -0.625 0],'zTickLabel',{'500','250','0'})
box(gca,'on')
set(gca,'XColor',[1 1 1],'YColor',[1 1 1],'ZColor',[1 1 1],'FontSize',FontSize,'LineWidth',LineWidth)
xlabel('X (mm)')
ylabel('Y (mm)')
zlabel('Z (mm)')
print([save_path 'volume_projection.png'],'-dpng','-r600')
print([save_path 'volume_projection'],'-depsc')
saveas(gcf,[save_path 'volume_projection.fig'])



%%

figure
set(gcf,'Position',[50   50   1120   840])
scatter3(NXon./1000,NYon./1000,(-50-zaspect.*NZon)./1000,8,Con,'Filled','MarkerFaceAlpha',.75)
hold on
scatter3(NXoff./1000,NYoff./1000,(-50-zaspect.*NZoff)./1000,8,Coff,'Filled','MarkerFaceAlpha',.25)
axis equal
view(45,30)
set(gcf,'Color',[0 0 0])
set(gca,'Color',[0 0 0],'LineWidth',LineWidth,'FontSize',FontSize)
xlim([0 3])
ylim([0 5])
set(gcf,'InvertHardcopy','off')
set(gca,'zTick',[-1.25 -0.625 0],'zTickLabel',{'500','250','0'})
box(gca,'on')
set(gca,'XColor',[0 0 0],'YColor',[0 0 0],'ZColor',[0 0 0])
print([save_path 'volume_projection_just_neurons'],'-dpng','-r600')

figure
set(gcf,'Position',[574   440   560   420])
scatter3(NXon(1)./1000,NYon(1)/1000,(-50-zaspect.*NZon(1))./1000,10,Con(1),'Filled','MarkerFaceAlpha',.75)
axis equal
view(45,30)
set(gcf,'Color',[0 0 0])
set(gca,'Color',[0 0 0],'LineWidth',LineWidth,'FontSize',FontSize)
xlim([0 3])
ylim([0 5])
zlim([-1.25 0])
set(gcf,'InvertHardcopy','off')
set(gca,'zTick',[-1.25 -0.625 0],'zTickLabel',{'500','250','0'})
set(gca,'XColor',[1 1 1],'YColor',[1 1 1],'ZColor',[1 1 1])
xlabel('X')
ylabel('Y')
zlabel('Z')
grid(gca,'off')
print([save_path 'volume_projection_just_axes'],'-depsc','-painters')
