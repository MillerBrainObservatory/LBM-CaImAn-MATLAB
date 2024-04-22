snrLimit = 0.5:0.1:10;
numNeurons = zeros(size(snrLimit));

for m = 1:numel(snrLimit)
   snroi = snrLimit(m);
   ftnoi = log(normcdf(-snroi))*3;
   numNeurons(m) = sum(logical(ftn<ftnoi));
end

save('num_neurons_vs_snr.mat','snrLimit','numNeurons','ftn')

ind = dsearchn(snrLimit',1.4);

figure;
semilogy(snrLimit,numNeurons,'k-')
hold on
semilogy(snrLimit(ind),numNeurons(ind),'ro')
xlim([1 6])
set(gcf,'Position',[300 300 560 250])
set(gca,'xTick',[1:1:6])
set(gca,'yTick',[1e3 1e4 1e5 1e6])
set(gca,'yTickLabel',{'1,000','10,000','100,000','1,000,000'})
xlabel('SNR threshold')
ylabel('Number of neurons')
saveas(gcf,[save_path 'num_neurons_vs_SNR.fig'])
print(gcf,[save_path 'num_neurons_vs_SNR'],'-depsc','-painters')
print(gcf,[save_path 'num_neurons_vs_SNR'],'-dpng','-r600')