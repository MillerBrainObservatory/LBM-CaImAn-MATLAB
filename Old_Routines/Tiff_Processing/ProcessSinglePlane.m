addpath(genpath('\\v-storage.rockefeller.edu\vazirilab_medium_data\jeff_demas\PROCESSING_SCRIPTS\Tiff_Processing\'))

clear
close all
clc

poi = 27;

order = [1 5:10 2 11:17 3 18:23 4 24:30];
order = fliplr(order);

plane_ind = dsearchn(order',poi);

[file,path] = uigetfile('*.tif','','\\v-storage.rockefeller.edu\vazirilab_medium_data\jeff_demas\MAxiMuM_data\');
file = file(1:end-10);

for ccc = 1:3
    vol = ProcessROITiff([path file '_0000' num2str(ccc) '.tif'],1:4,1); % load from tif
    
    if ccc > 1
        p = cat(3,p,reshape(vol(:,:,plane_ind,:),size(vol,1),size(vol,2),[]));
    else
        p = reshape(vol(:,:,plane_ind,:),size(vol,1),size(vol,2),[]);
    end
    
end
