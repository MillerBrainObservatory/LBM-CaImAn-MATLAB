clear
close all
clc

load('neuron_coordinates_and_traces.mat')

save_path = '\\v-storage.rockefeller.edu\vazirilab_medium_data\jeff_demas\MAxiMuM_data\Paper_Figures\Fig4\';
FontSize = 12;
LineWidth = 1;
FontName = 'Arial';

%% 

num_des = 3000;
% t_des = 1704;

tind_s = dsearchn(t',90);
tind_e = dsearchn(t',450);
ts = t(tind_s:tind_e);
t_des = numel(ts);

nind_s = K-num_des+1;
nind_e = K;

%%

[R,inds] = max([Rv' Rs'],[],2);
[Rsrt,indsrt] = sort(R,'ascend');

T_norm = movmean(T_all(indsrt,:),5,2);
T_norm = T_norm./(max(T_norm,[],2)*ones(1,T));

figure;
imagesc(t,1:K,T_norm)
caxis([0 1])
xlabel('Time (s)')
ylabel('Neuron number')
xlim([0 540])
set(gca,'FontSize',FontSize,'LineWidth',LineWidth,'XColor',[0 0 0],'YColor',[0 0 0],'ZColor',[0 0 0])
set(gca,'xTick',0:60:540)
set(gca,'YDir','normal')
set(gca,'yTick',(40:40:200).*1000,'yTickLabel',{'40,000','80,000','120,000','160,000','200,000'})

hold on
plot([t(tind_s) t(tind_e)],[nind_s nind_s],'r-','LineWidth',LineWidth)
plot([t(tind_s) t(tind_e)],[nind_e nind_e],'r-','LineWidth',LineWidth)
plot([t(tind_s) t(tind_s)],[nind_s nind_e],'r-','LineWidth',LineWidth)
plot([t(tind_e) t(tind_e)],[nind_s nind_e],'r-','LineWidth',LineWidth)

set(gcf,'Position',[680   139   610   630])
print([save_path 'all_traces_hemisphere.png'],'-dpng','-r600')
print([save_path 'all_traces_hemisphere'],'-depsc','-painters')
% saveas(gcf,[save_path 'all_traces_hemisphere.fig'])

%%

TOI1 = T_norm(nind_s:nind_e,tind_s:tind_e);
TOI1(TOI1<0) = 0;
TOI1(TOI1>0.7) = 0.7;
TOI1 = TOI1./0.7;

map = parula(256);
TOI1c = ind2rgb(uint8(TOI1.*255),map);

figure
imagesc(TOI1c)


imwrite(TOI1c,[save_path 'full_resolution_neuron_heatmap.png'])

%%

num_desired2 = 50;
offset = .5;

nind_s2 = K-num_desired2+1;
nind_e2 = K;

Tsrt = T_all(indsrt,:);
TOI2 = movmean(Tsrt(nind_s2:nind_e2,tind_s:tind_e),3,2);
TOI2o = TOI2 + offset.*(0:num_desired2-1)'*ones(1,numel(ts));
% figure
% plot(ts,TOI2 + offset.*(0:num_desired2-1)'*ones(1,numel(ts)))
% ylim([-0.5 26.5])
% grid(gca,'on')
% xlabel('Time (s)')
% ylabel('\DeltaF/F_0')
% xlim([225 325])

C = [0.9 0.4 0.8 0.3 0.7 0.2 0.6 0.1 0.5 0.0]';
C = [zeros(10,1), C, zeros(10,1)];

figure(102)
set(gcf,'Position',[100 50 550 380])
for ijk = 1:size(C,1)
    figure(102)
    hold on
    plot(ts,TOI2o(ijk:10:end,:),'Color',C(ijk,:),'LineWidth',LineWidth)
end
ylim([-0.5 30])
xlabel('Time (s)')
ylabel('\DeltaF/F_0')
xlim([195 295])
set(gca,'yTick',[0:5:30],'LineWidth',LineWidth','FontSize',FontSize)
set(gca,'xTick',[195:20:295])
set(gca,'XColor',[0 0 0],'YColor',[0 0 0],'ZColor',[0 0 0])
hold on

SS = ones(100,1)*Ss;
SS(SS>0.2) = 1;
SS(SS<1) = 0;
SS = repmat(SS,[1 1 3]);
SS(:,:,2:3) = 0;

SV = ones(100,1)*Sv;
SV(SV>0.2) = 1;
SV(SV<1) = 0;
SV = repmat(SV,[1 1 3]);
SV(:,:,1:2) = 0;

h=imagesc(t,linspace(27.2,27.8,100),SS);
h.AlphaData = SS(:,:,1);

h=imagesc(t,linspace(28.2,28.8,100),SV);
h.AlphaData = SV(:,:,3);
box(gca,'on')

set(gcf,'Position',[ 680    28   610   336])
print([save_path 'highly_tuned_neuron_traces.png'],'-dpng','-r600')
print([save_path 'highly_tuned_neuron_traces'],'-depsc','-painters')
saveas(gcf,[save_path 'highly_tuned_neuron_traces.fig'])