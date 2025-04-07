clear
close all
clc

addpath(genpath('C:\Users\jdemas\Documents\MATLAB\ScanImageTiffReader\share\matlab\'));

file = 'mh89_hemisphere_FOV_50_550um_depth_250mW_dual_stimuli_30min_00001_00001.tif';

vol = ProcessROITiff2(file,1:5,1);

Ns = [10 18 26];

for ijk = 1:numel(Ns)
    N = Ns(ijk);
    
    poi = reshape(vol(:,:,N,:),size(vol,1),size(vol,2),[]);
    
    poi = poi-min(poi(:));
    poi = uint16(poi);
    
    save(['data_plane_' num2str(N) '.mat'],'poi')
    
end