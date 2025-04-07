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
alpha = 158./2500^2;
nz = nz - alpha.*((nx-1500).^2 + (ny-2500).^2);
% nz = -nz;


Tm = max(movmean(T_all,5,2),[],2);

num = round(K/1);
zaspect = 10;

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
scatter(NYon./1000,(-50-zaspect.*NZon)./1000,10,Con,'Filled','MarkerFaceAlpha',.75)
hold on
scatter(NYoff./1000,(-50-zaspect.*NZoff)./1000,10,Coff,'Filled','MarkerFaceAlpha',.25)
% axis equal
% view(45,30)
set(gcf,'Color',[0 0 0])
set(gca,'Color',[0 0 0])
% ylim([-1.25 0])
xlim([0 5])
% ylim([0 5])
set(gcf,'InvertHardcopy','off')
% set(gca,'yTick',zaspect.*[-0.5 -0.25 0],'yTickLabel',{'500','250','0'})
box(gca,'on')
set(gca,'XColor',[1 1 1],'YColor',[1 1 1],'FontSize',FontSize,'LineWidth',LineWidth)
xlabel('Y (mm)')
ylabel('Z (mm)')

%%

Z = -50-nz;
Y = NY;

% X = NX;
% keep = logical(X>1500);
% 
% Z = Z(keep);
% Y = Y(keep);

figure
hist3([Y Z],'Ctrs',{-0:100:5000 -600:25:0},'CDataMode','Auto');
view(2)
%%

figure
N = hist3([Y Z],'Ctrs',{-0:40:5000 -600:20:0},'CDataMode','Auto');
ly = linspace(0,5000,size(N,1));
lz = linspace(-0,600,size(N,2));

imagesc(ly,lz,flipud(N'))
shading interp
axis equal
ylim([0 600])
xlim([0 5000])
colormap(gray)

set(gcf,'Position',[200 250 1000 300])
set(gca,'yTick',[],'xTick',[])

print('yz_proj.png','-dpng','-r600')

% hold on
% 
% fill([0 5000 5000 0],[0 0 100 100],'b-','Linestyle','none','FaceAlpha',0.1)
% fill([0 5000 5000 0],[100 100 330 330],'g-','LineStyle','None','FaceAlpha',0.1)
% fill([0 5000 5000 0],[330 330 450 450],'r-','LineStyle','None','FaceAlpha',0.1)
% fill([0 5000 5000 0],[450 450 600 600],'m-','LineStyle','None','FaceAlpha',0.1)

% xlabel('Y (mm)')
% ylabel('Z (\mum)')

% hold on
% plot([0 5000],[100 100],'b-','LineWidth',1)
% plot([0 5000],[330 330],'g-','LineWidth',1)
% plot([0 5000],[450 450],'r-','LineWidth',1)

% 
% plot([0 2500],[105 105],'Color',[0 0.5 0],'LineWidth',2)
% plot([0 2500],[330 330],'Color',[0 0.5 0],'LineWidth',2)
% plot([2500 2500],[105 330],'Color',[0 0.5 0],'LineWidth',2)
% plot([2510 5000],[105 105],'Color',[0 0.5 0],'LineWidth',2)
% plot([2510 5000],[450 450],'Color',[0 0.5 0],'LineWidth',2)
% plot([2510 2510],[105 450],'Color',[0 0.5 0],'LineWidth',2)
% 
% plot([0 2500],[335 335],'r-','LineWidth',2)
% plot([0 2500],[450 450],'r-','LineWidth',2)
% plot([2500 2500],[335 450],'r-','LineWidth',2)
% plot([2510 5000],[455 455],'r-','LineWidth',2)
% plot([2510 5000],[600 600],'r-','LineWidth',2)
% plot([2510 2510],[455 600],'r-','LineWidth',2)
% h.AlphaData = 0.25;