clear

addpath(genpath('\\v-storage\vazirilab_medium_data\jeff_demas\PROCESSING_SCRIPTS\Post_Processing_Routines\'))
photons_in_plane = zeros(1,30);
counts = zeros(1,30);

for abc = 1:30;

load(['mh89_hemisphere_FOV_50_550um_depth_250mW_dual_stimuli_30min_00001_plane_' num2str(abc) '.mat'])
load(['caiman_output_plane_' num2str(abc) '.mat'])

fitness = compute_event_exceptionality(T_keep,3,0);
min_fitness = log(normcdf(-1.4))*3;

keep = logical(fitness<min_fitness & rVals>0.4);

Tk = T_keep(keep,:);
Ak = A_keep(:,keep);
Km = size(Tk,1);

A = zeros(size(Cn));

for ijk = 1:Km
   Aoi = reshape(full(Ak(:,ijk)),size(Cn,1),size(Cn,2)); 
   A = A+Aoi;
end

A(A>0) = 1;

At = A(1:971,5:size(Y,2)+4);

Ar = reshape(At,[],1);

Yr = reshape(Y,[],size(Y,3));

% YrV = sort(Yr,2,'ascend');
YrV = median(Yr,2);

Ar(Ar==0) = NaN;
V = YrV.*Ar;

counts(abc) = nanmean(V);

volts = 2/2^11*counts(abc);

amps = volts./50;

power = amps/16e4;

energy = power.*5e-9;

photon_energy = 6.626e-34*3e8/515e-9;

photons_in_plane(abc) = energy./photon_energy;

end

photons = mean(photons_in_plane);