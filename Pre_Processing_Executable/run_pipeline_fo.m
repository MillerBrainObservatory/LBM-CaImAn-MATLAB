% P = '.'; % absolute or relative path to where the files are saved.
% S = dir(fullfile(P,'*'));
% S([S.isdir]) = [];
clear all 
clc

datapath = '/data2/fpo/lbm/0p6mm_0p6mm/';
fileRoot = 'MH70_0p6mm_FOV_50_550um_depth_som_stim_199mW_3min_M1_00001';

% datapath = fullfile("/data2/fpo/lbm/3mm_5mm/chunks/");
% fileRoot = "all_planes_slice_single.mat";

% run_motion_corr(datapath, fileRoot, '6');
preProcessMAxiMuM(datapath, fileRoot, '0', '2');
%convert_tiff_to_volume(datapath, fileRoot, '0', '0');
% path = fullfile("/v-data2/jeff_demas/Jeffs LBM paper data/Fig2/20191122/mh89_hemisphere_FOV_50_550um_depth_250mW_dual_stimuli_30min_00001/data/mh89_hemisphere_FOV_50_550um_depth_250mW_dual_stimuli_30min_00001_00001.tif");
% tif = Tiff(path);