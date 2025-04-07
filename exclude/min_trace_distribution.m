load('neuron_coordinates_and_traces.mat','T_all')
%%
n = 5;

Noise = std(T_all - movmean(T_all,5,2),[],2);

Min = min(mean(T_all,2),[],2);


figure
hist(abs(Min./Noise),0:0.01:10)