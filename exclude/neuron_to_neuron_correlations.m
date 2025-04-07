clear
close all
clc

load('neuron_coordinates_and_traces.mat')

clearvars -except T_all

T_all = single(T_all);

tic
R = corr(T_all',T_all');
toc

frac = 0.2;
Nr = round(size(T_all,1)*frac);

Rm = mean(R,2);

Rmax = max(R,[],2);

[Rm,inds] = sort(Rm,'descend');

Rr = R(inds(1:Nr),inds(1:Nr));

[Rmax,inds2] = sort(Rmax,'descend');

Rx = R(inds2(1:Nr),inds2(1:Nr));

disp('Saving mean correlations...')

save('neuron_correlations.mat','Rm','Rmax','-v7.3')

toc

disp(['Saving correlation matrix for top ' num2str(Nr) ' neurons...'])

save(['correlation_matrix_top_' num2str(Nr) '_neurons_mean.mat'],'Rr','-v7.3')
save(['correlation_matrix_top_' num2str(Nr) '_neurons_max.mat'],'Rx','-v7.3')

toc