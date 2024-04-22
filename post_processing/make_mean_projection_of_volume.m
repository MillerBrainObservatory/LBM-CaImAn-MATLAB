%% Select file, read in

clear
% close all
clc

% path = '\\v-storage.rockefeller.edu\vazirilab_medium_data\jeff_demas\MAxiMuM_data\20191122\mh89_2mm_FOV_50_550um_depth_250mW_som_stimuli_9min_00001\';

choice = menu('Select NAS:','v-data1','v-data2','v-data3');

addpath(genpath('\\v-storage\vazirilab_medium_data\jeff_demas\PROCESSING_SCRIPTS\CaImAn_Utilities\motion_correction\'));

switch choice
    case 1
        path = '\\v-storage.rockefeller.edu\vazirilab_medium_data\jeff_demas\MAxiMuM_data\';
    case 2
        path = '\\v-storage2.rockefeller.edu\v-data2\jeff_demas\MAxiMuM_data\';
    case 3
        disp('Drive is not configured for use yet.')
end

path = uigetdir(path);
path = [path '\'];

if size(strfind(path,'hemisphere'),1) > 0
    r_thr = 0.4;
    pixel_resolution = 5;
    min_snr = 1.4;
    frameRate = 4.69;
    FOVx = 3000;
    FOVy = 5000*0.97;
elseif size(strfind(path,'2mm'),1) > 0
    r_thr = 0.4;
    pixel_resolution = 2.75;
    min_snr = 1.4;
    frameRate = 6.45;
    FOVx = 2000;
    FOVy = 2000*0.97;
elseif size(strfind(path,'0p9mm'),1) > 0
    r_thr = 0.4;
    pixel_resolution = 3;
    min_snr = 1.5;
    frameRate = 36.89;
    FOVx = 900;
    FOVy = 900*0.97;
elseif size(strfind(path,'0p6mm'),1) > 0
    r_thr = 0.4;
    pixel_resolution = 1;
    min_snr = 1.5;
    frameRate = 9.61;
    FOVx = 600;
    FOVy = 600*0.97;
elseif size(strfind(path,'6mm'),1) > 0 && size(strfind(path,'0.6mm'),1) == 0
    r_thr = 0.4;
    pixel_resolution = 4.6;
    min_snr = 1.4;
    frameRate = 2.18;
    FOVx = 5400;
    FOVy = 6000*0.97;
end

c = load([path 'three_neuron_mean_offsets.mat'],'offsets');
offsets = round(c.offsets);

xo = cumsum(-offsets(:,2));
xo = xo-min(xo);

yo = cumsum(-offsets(:,1));
yo = yo-min(yo);

d = load([path 'caiman_output_plane_1.mat'],'Ym');

Ibrain = zeros(size(d.Ym,1)+max(yo)+10,size(d.Ym,2)+max(xo)+10,30);

for ijk = 1:30
    dd = load([path 'caiman_output_plane_' num2str(ijk) '.mat'],'Ym');
    Ym = dd.Ym;
    
    Ibrain(1+yo(ijk):yo(ijk)+size(Ym,1),1+xo(ijk):xo(ijk)+size(Ym,2),ijk) = Ym;
    
end

Ibrain = mean(Ibrain,3);

%%

dx = FOVx/size(Ym,2);
dy = pixel_resolution;

xbrain = (1:size(Ym,2))*dx;
ybrain = (1:size(Ym,1))*dy;

figure;
imagesc(xbrain,ybrain,Ibrain)
axis image
set(gca,'ydir','normal','xdir','reverse')
colormap(gray)

save([path 'mean_brain_image.mat'],'Ibrain','xbrain','ybrain')