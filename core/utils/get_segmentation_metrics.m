function [] = get_segmentation_metrics(savePath, T_all, Nsamples)
% Compute and save segmentation metrics based on the ration of t Z-Score of the moving mean
% to the standard deviation of the difference between time-series data and
% the moving mean.
%
% Parameters
% ----------
% savePath : char
%     Path where the resulting figures will be saved.
% T_all : numeric array
%     Time series data for all neurons.
% Nsamples : numeric
%     Number of samples for the moving mean calculation.
%
% This function calculates the Z-score for
% each neuron and plots histograms of the Z-scores and maximum
% \DeltaF/F_0 (%) values. The resulting figures are saved to the specified
% save path.
%
% Notes
% -----
% The Z-score is calculated as the ratio of the maximum moving mean to the
% standard deviation of the difference between the time series data and its
% moving mean.
%
% Examples
% --------
% savePath = 'results/';
% T_all = randn(100, 1000); % Example time series data
% Nsamples = 10;
% get_segmentation_metrics(savePath, T_all, Nsamples);
%

NN = std(T_all - movmean(T_all, Nsamples, 2), [], 2);
MM = max(movmean(T_all, Nsamples, 2), [], 2);
Z = MM./NN;

figure; histogram(Z, 0:0.2:20);
xlabel('Z-score');
ylabel('Neurons');
saveas(gcf, [savePath 'all_neuron_Zscore.fig']);

figure;
histogram(100.*max(T_all, [], 2));
xlabel('Max \DeltaF/F_0 (%)');
ylabel('Neurons');
saveas(gcf, fullfile(savePath, 'all_neuron_maxDF.fig'));
end

