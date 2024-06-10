%% This file should go in your matlab path
% >> userpath
% ans = 
%      'C:/<username>/Documents/MATLAB'

% Tell MATLAB to open where our code is located
cd <path to LBM_caiman_matlab>;
addpath(genpath(fullfile(cd, "core/")));
addpath(genpath(fullfile(cd, "packages/")));
