stem = 'mh89_hemisphere_FOV_50_550um_depth_250mW_dual_stimuli_30min_00001_plane_';

mn = zeros(1,30);

for ijk = 1:30

    load([stem num2str(ijk) '.mat'],'Y')
    mn(ijk) = mean(Y(:));

end

counts = mean(mn);

volts = 2/2^16*counts;

amps = volts./50;

power = amps/17.6e4;

energy = power.*5e-9;

photon_energy = 6.626e-34*3e8/515e-9;

photons = energy./photon_energy