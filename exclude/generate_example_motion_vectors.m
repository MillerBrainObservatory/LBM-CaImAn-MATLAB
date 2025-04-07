load('tracking_data2.mat')

load('neuron_coordinates_and_traces.mat','T_all')

t0 = dsearchn(t',mean(t));
tt = t - t(t0);

tau = 0.55/log(2);
kernel = exp(tt./0.2);
kernel(tt>=0) = exp(-tt(tt>=0)./tau);

Sm = conv(sm,kernel,'same');

R = corr(T_all',Sm');
[mx,ind] = max(R);
trace = T_all(ind,:);
%%
figure
plot(t,sm+2,'-k')
hold on
plot(t,1+Sm./1.135,'-r')
hold on
plot(t,trace./3.263,'-b')
xlim([100 200])
ylim([0 3])
xlabel('Time (s)')
ylabel('Signal (a.u.)')
legend('Paw speed','Stimulus vector','Example trace (R = 0.49)','Location','NorthWest')
set(gca,'FontSize',12,'XColor',[0 0 0],'YColor',[0 0 0],'LineWidth',1)
set(gcf,'Position',[250 250 650 420])
spath = '\\v-storage.rockefeller.edu\vazirilab_medium_data\jeff_demas\MAxiMuM_data\Paper_Figures\Sfig5\';
print([spath 'motion_vectors.eps'],'-depsc','-painters','-r600')