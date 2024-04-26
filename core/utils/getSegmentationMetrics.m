function [] = getSegmentationMetrics(savePath, T_all,Nsamples)
NN = std(T_all - movmean(T_all,Nsamples,2),[],2);
MM = max(movmean(T_all,Nsamples,2),[],2);
Z = MM./NN;

figure; histogram(Z,0:0.2:20);
xlabel('Z-score');
ylabel('Neurons');
saveas(gcf,[path 'all_neuron_Zscore.fig']);

figure
histogram(100.*max(T_all,[],2));
xlabel('Max \DeltaF/F_0 (%)');
ylabel('Neurons');
saveas(gcf,fullfile(savePath, 'all_neuron_maxDF.fig'));
end