clear all
close all
clc

cd('\\v-storage.rockefeller.edu\vazirilab_medium_data\jeff_demas\MAxiMuM_data\20191122\mh89_hemisphere_FOV_50_550um_depth_250mW_dual_stimuli_30min_00001\')

POI = 18;

load(['data\caiman_output_plane_' num2str(POI) '.mat'])

save_path = '\\v-storage.rockefeller.edu\vazirilab_medium_data\jeff_demas\MAxiMuM_data\Paper_Figures\Fig4\';
FontSize = 12;
LineWidth = 1;

I = fliplr(Ym);

%%

x = (1:size(I,2)).*4.2;
y = (1:size(I,1)).*5;

upbound = 400;

Ic = repmat(I,[1 1 3]);
Ic(Ic>upbound) = upbound;
Ic = Ic./upbound;

% Ic(25,20:79,1) = 1;
% Ic(25,20:79,2:3) = 0;

xs = 455;
xe = 654;

ys = 245;
ye = 413;

buf = 2;

Ics = Ic(ys:ye,xs:xe,:);

Ic(ys-2:ys-1,xs:xe,1:2) = 0;
Ic(ys-2:ys-1,xs:xe,3) = 1;

Ic(ye+1:ye+2,xs:xe,1:2) = 0;
Ic(ye+1:ye+2,xs:xe,3) = 1;

Ic(ys:ye,xs-2:xs-1,1:2) = 0;
Ic(ys:ye,xs-2:xs-1,3) = 1;

Ic(ys:ye,xe+1:xe+2,1:2) = 0;
Ic(ys:ye,xe+1:xe+2,3) = 1;

figure;
imagesc(x,y,Ic);
set(gca,'YDir','normal','yTick',[],'xTick',[])
axis image
colormap(gray)
caxis ([0 500])
set(gca,'LineWidth',LineWidth)
print([save_path 'mean_projection_hemisphere'],'-depsc','-painters')
print([save_path 'mean_projection_hemisphere'],'-dpng','-r600')
saveas(gcf,[save_path 'mean_projection_hemisphere.fig'])

sx = x(xs:xe);
sy = y(ys:ye);

% Ics(12,10:34,1) = 1;
% Ics(12,10:34,2:3) = 0;


figure;
imagesc(sx,sy,Ics)
set(gca,'YDir','normal','yTick',[],'xTick',[])
axis image
colormap(gray)
set(gca,'LineWidth',LineWidth)
saveas(gcf,[save_path 'mean_projection_zoom_in_hemisphere.fig'])
print([save_path 'mean_projection_zoom_in_hemisphere'],'-depsc','-painters')
print([save_path 'mean_projection_zoom_in_hemisphere'],'-dpng','-r600')
imwrite((flipud(Ic)),[save_path 'mean_projection_hemisphere.tif'])
imwrite((flipud(Ics)),[save_path 'mean_projection_zoom_in_hemisphere.tif'])

