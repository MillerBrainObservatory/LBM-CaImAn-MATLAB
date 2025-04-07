clear
close all
clc
 
spath = '\\v-storage.rockefeller.edu\vazirilab_medium_data\jeff_demas\MAxiMuM_data\Paper_Figures\SFig7\'; 
 
load('neuron_coordinates_and_traces.mat','T_all')
 
T_all = movmean(T_all./(max(T_all,[],2)*ones(1,size(T_all,2))),5,2);

load('thresholds.mat')

[~,srt] = sort(Rsa,'descend');

T_all = T_all(srt,:);

Tt = uint8(255.*ind2rgb(uint8(T_all.*255),parula(256)));

bx = 255.*ones(size(Tt,1),200,3,'uint8');

Ttp = cat(2,bx,Tt,bx);

by = 255.*ones(200,size(Ttp,2),3,'uint8');

Ttp = cat(1,by,Ttp,by);

Ttp(201:2000:207230,200,2) = 0;
Ttp(201:2000:207230,200,3) = 0;

Ttp(200,201+round([0:281.333:2532]),2) = 0;
Ttp(200,201+round([0:281.333:2532]),3) = 0;

Ttp = flipud(Ttp);

test = Ttp(1:2900,:,:);
figure;
imagesc(test); set(gca,'YDir','normal')

imwrite(Ttp,[spath 'SFig7.tif'])
% imwrite(Ttp,[spath 'SFig7.png'])

imwrite(Ttp(1:2900,:,:),[spath 'test.tif'])
imwrite(Ttp(1:2900,:,:),[spath 'test.png'])
