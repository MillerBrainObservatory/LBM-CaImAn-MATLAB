clear
close all
clc


load('neuron_coordinates_and_traces.mat')

%%

keep1 = logical(Rv>6*sigma);

Tv = T_all(keep1,:);

nxv = nx(keep1);
nyv = ny(keep1);
nzv = nz(keep1);

figure
hist(nzv,0:20:600)

keep2 = logical(Rs>6*sigma);

Ts = T_all(keep2,:);

nxs = nx(keep2);
nys = ny(keep2);
nzs = nz(keep2);

figure
hist(nzs,0:20:600)
