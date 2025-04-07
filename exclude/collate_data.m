clear
close all
clc

min_snr = 2;
frameRate = 9.6;
decay_time = 0.265;
Nsamples = ceil(decay_time*frameRate);
min_fitness = log(normcdf(-min_snr))*Nsamples;

T_all = [];

for abc = 1:30
    load(['caiman_output_plane_' num2str(abc) '.mat'],'T_keep')
    [fitness] = compute_event_exceptionality(T_keep,Nsamples,0);
    inds = logical(fitness<min_fitness);
    T_keep = T_keep(inds,:);
    T_all = cat(1,T_all,T_keep);
    disp(abc)
end

T_keep = single(T_keep);

save('all_traces.mat','T_keep');