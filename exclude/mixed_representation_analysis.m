clear
close all
clc

sigthr = 0.05;
Vartype = 'equal';
falpha = 0.2;

spath = '\\v-storage.rockefeller.edu\vazirilab_medium_data\jeff_demas\MAxiMuM_data\Paper_Figures\Fig6\';

%% Load all data

load('neuron_coordinates_and_traces.mat') % traces and coordinates
load('thresholds.mat') % thresholded populations
load('mean_brain_image.mat')
x = (1:1:size(I,2)).*4.2; % x and y pixel arrays
y = (1:1:size(I,1)).*5;

nx = nx - max(x); nx = -nx;

%% Thresholded subpopulations

nxs = nx(soi);
nys = ny(soi);
nzs = nz(soi);

nxv = nx(voi);
nyv = ny(voi);
nzv = nz(voi);

Ts = T_all(soi,:);
Tv = T_all(voi,:);

%% Whisker-tuned visual modulation analyis

stinds = find(Ssa>0.99); % indices of whisker trials alone
btinds = find(Sb>0.99); % indices of both trials 

num = 5;
tt = -num:3*num; tt = tt.*mean(diff(t));
strials = zeros(ks,4*num+1,numel(stinds));
btrials = zeros(ks,4*num+1,numel(btinds));

sti = zeros(ks,numel(stinds));
bti = zeros(ks,numel(btinds));

for aa = 1:numel(stinds)
    ioi = stinds(aa);
    strials(:,:,aa) = Ts(:,ioi-num:ioi+3*num);
    sti(:,aa) = mean(Ts(:,ioi-num:ioi+3*num),2);
end

for bb = 1:numel(btinds)
    ioi = btinds(bb);
    btrials(:,:,bb) = Ts(:,ioi-num:ioi+3*num);
    bti(:,bb) = mean(Ts(:,ioi-num:ioi+3*num),2);
    
end

[sigoi,p] = ttest2(sti,bti,'Dim',2,'Alpha',sigthr,'Vartype',Vartype);
upmod = logical((mean(bti,2) - mean(sti,2))>0);
dnmod = ~upmod;

[~,indn] = min(p+double(upmod));
[~,inup] = min(p+double(dnmod));

figure;
hold on
h = fill([tt fliplr(tt)],[mean(btrials(inup,:,:),3)+std(btrials(inup,:,:),[],3) fliplr(mean(btrials(inup,:,:),3)-std(btrials(inup,:,:),[],3))],'m','LineStyle','none');
h.FaceAlpha = falpha;
h = fill([tt fliplr(tt)],[mean(strials(inup,:,:),3)+std(strials(inup,:,:),[],3) fliplr(mean(strials(inup,:,:),3)-std(strials(inup,:,:),[],3))],'c','LineStyle','none');
h.FaceAlpha = falpha;
plot(tt,mean(btrials(inup,:,:),3),'m-')
plot(tt,mean(strials(inup,:,:),3),'c-','Color',[0 0.6 0.9])
% legend('Whisker + Visual','Whisker alone')
box(gca,'on')
xlabel('Time (s)')
ylabel('Trial-averaged \DeltaF/F_0')
xlim([min(tt) max(tt)])
set(gcf,'Position',[597   262   173   220])
xlim([-1 3])
set(gca,'XColor',[0 0 0],'YColor',[ 0 0 0],'FontSize',12,'LineWidth',1)
ylim([-0.2 1.7])
saveas(gcf,[spath 'whisker_plus_visual_example_mod_up.fig'])
print([spath 'whisker_plus_visual_example_mod_up'],'-dpng','-r600')
print([spath 'whisker_plus_visual_example_mod_up'],'-depsc','-painters')

figure;
hold on
h = fill([tt fliplr(tt)],[mean(btrials(indn,:,:),3)+std(btrials(indn,:,:),[],3) fliplr(mean(btrials(indn,:,:),3)-std(btrials(indn,:,:),[],3))],'m','LineStyle','none');
h.FaceAlpha = falpha;
h = fill([tt fliplr(tt)],[mean(strials(indn,:,:),3)+std(strials(indn,:,:),[],3) fliplr(mean(strials(indn,:,:),3)-std(strials(indn,:,:),[],3))],'c','LineStyle','none');
h.FaceAlpha = falpha;
plot(tt,mean(btrials(indn,:,:),3),'m-')
plot(tt,mean(strials(indn,:,:),3),'c-','Color',[0 0.6 0.9])
% legend('Whisker + Visual','Whisker alone')
box(gca,'on')
xlabel('Time (s)')
ylabel('Trial-averaged \DeltaF/F_0')
xlim([min(tt) max(tt)])
set(gcf,'Position',[458   262   173   220])
xlim([-1 3])
ylim([-0.2 1.7])
set(gca,'XColor',[0 0 0],'YColor',[ 0 0 0],'FontSize',12,'LineWidth',1)
saveas(gcf,[spath 'whisker_plus_visual_example_mod_down.fig'])
print([spath 'whisker_plus_visual_example_mod_down'],'-dpng','-r600')
print([spath 'whisker_plus_visual_example_mod_down'],'-depsc','-painters')

schange = (mean(bti,2)-mean(sti,2))./mean(sti,2);

figure
% h=histogram(100.*schange,-200:5:200,'FaceColor',[0.5 0.5 0.5]);
hold on
% h.FaceAlpha = 0.6;
h=histogram(100.*schange(sigoi&upmod),-200:5:200,'FaceColor','m');
h.FaceAlpha = 0.6;
h=histogram(100.*schange(sigoi&dnmod),-200:5:200,'FaceColor',[0 1 1]);
h.FaceAlpha = 1;
xlabel('Change in activity (%)')
ylabel('Neurons')
xlim([-100 100])
box(gca,'on')
set(gcf,'Position',[458   122   327   296])
set(gca,'XColor',[0 0 0],'YColor',[0 0 0],'FontSize',12,'LineWidth',1)
saveas(gcf,[spath 'whisker_plus_visual_histogram.fig'])
print([spath 'whisker_plus_visual_histogram'],'-dpng','-r600')
print([spath 'whisker_plus_visual_histogram'],'-depsc','-painters')

lim = 0.5;
range = 2.*lim;

schangec = schange(logical(sigoi));
schangec(schangec>lim) = lim;
schangec(schangec<-lim) = -lim;
scolors = zeros(sum(sigoi),3);
scolors(:,1) = (schangec + lim)./range;
scolors(:,2) = (-schangec + lim)./range;
scolors(:,3) = ones(numel(schangec),1);

figure
imagesc(x,y,fliplr(I))
colormap(gray)
hold on
axis image
set(gca,'yDir','normal','xTick',[],'yTick',[])
h = scatter(nxs(logical(sigoi)),nys(logical(sigoi)),10,scolors,'Filled');
h.MarkerFaceAlpha = 0.1;
set(gcf,'Position',[250 50 700 920])
saveas(gcf,[spath 'whisker_plus_visual_map.fig'])
print([spath 'whisker_plus_visual_map'],'-dpng','-r600')
print([spath 'whisker_plus_visual_map'],'-depsc','-painters')

%% Visual-tuned visual modulation analyis

vtinds = find(Sva>0.99); % indices of whisker trials alone
btinds = find(Sb>0.99); % indices of both trials 

num = 5;
tt = -num:3*num; tt = tt.*mean(diff(t));

vtrials = zeros(kv,4*num+1,numel(vtinds));
btrials = zeros(kv,4*num+1,numel(btinds));

vti = zeros(kv,numel(vtinds));
bti = zeros(kv,numel(btinds));

for aa = 1:numel(vtinds)
    ioi = vtinds(aa);
    vtrials(:,:,aa) = Tv(:,ioi-num:ioi+3*num);
    vti(:,aa) = mean(Tv(:,ioi-num:ioi+3*num),2);
end

for bb = 1:numel(btinds)
    ioi = btinds(bb);
    btrials(:,:,bb) = Tv(:,ioi-num:ioi+3*num);
    bti(:,bb) = mean(Tv(:,ioi-num:ioi+3*num),2);
end

[sigoi,p] = ttest2(vti,bti,'Dim',2,'Alpha',sigthr,'Vartype',Vartype);
upmod = logical((mean(bti,2) - mean(vti,2))>0);
dnmod = ~upmod;

[~,indn] = min(p+double(upmod));
[~,inup] = min(p+double(dnmod));

figure;
hold on
h = fill([tt fliplr(tt)],[mean(btrials(inup,:,:),3)+std(btrials(inup,:,:),[],3) fliplr(mean(btrials(inup,:,:),3)-std(btrials(inup,:,:),[],3))],'m','LineStyle','none');
h.FaceAlpha = falpha;
h = fill([tt fliplr(tt)],[mean(vtrials(inup,:,:),3)+std(vtrials(inup,:,:),[],3) fliplr(mean(vtrials(inup,:,:),3)-std(vtrials(inup,:,:),[],3))],'c','LineStyle','none');
h.FaceAlpha = falpha;
plot(tt,mean(btrials(inup,:,:),3),'m-')
plot(tt,mean(vtrials(inup,:,:),3),'c-','Color',[0 0.6 0.9])
% legend('Visual + Whisker','Visual alone')
box(gca,'on')
xlabel('Time (s)')
ylabel('Trial-averaged \DeltaF/F_0')
xlim([min(tt) max(tt)])
set(gcf,'Position',[597   262   173   220])
xlim([-1 3])
set(gca,'XColor',[0 0 0],'YColor',[ 0 0 0],'FontSize',12,'LineWidth',1)
ylim([-0.2 1.7])
saveas(gcf,[spath 'visual_plus_whisker_example_mod_up.fig'])
print([spath 'visual_plus_whisker_example_mod_up'],'-dpng','-r600')
print([spath 'visual_plus_whisker_example_mod_up'],'-depsc','-painters')


figure;
hold on
h = fill([tt fliplr(tt)],[mean(btrials(indn,:,:),3)+std(btrials(indn,:,:),[],3) fliplr(mean(btrials(indn,:,:),3)-std(btrials(indn,:,:),[],3))],'m','LineStyle','none');
h.FaceAlpha = falpha;
h = fill([tt fliplr(tt)],[mean(vtrials(indn,:,:),3)+std(vtrials(indn,:,:),[],3) fliplr(mean(vtrials(indn,:,:),3)-std(vtrials(indn,:,:),[],3))],'c','LineStyle','none');
h.FaceAlpha = falpha;
plot(tt,mean(btrials(indn,:,:),3),'m-')
plot(tt,mean(vtrials(indn,:,:),3),'c-','Color',[0 0.6 0.9])
% legend('Visual + Whisker','Visual alone')
box(gca,'on')
xlabel('Time (s)')
ylabel('Trial-averaged \DeltaF/F_0')
set(gcf,'Position',[597   262   173   220])
xlim([-1 3])
set(gca,'XColor',[0 0 0],'YColor',[ 0 0 0],'FontSize',12,'LineWidth',1)
ylim([-0.2 1.7])
saveas(gcf,[spath 'visual_plus_whisker_example_mod_down.fig'])
print([spath 'visual_plus_whisker_example_mod_down'],'-dpng','-r600')
print([spath 'visual_plus_whisker_example_mod_down'],'-depsc','-painters')

vchange = (mean(bti,2)-mean(vti,2))./mean(vti,2);

figure
% h=histogram(100.*vchange,-200:5:200,'FaceColor',[0.5 0.5 0.5]);
hold on
% h.FaceAlpha = 0.6;
h=histogram(100.*vchange(sigoi&upmod),-200:5:200,'FaceColor','m');
h.FaceAlpha = 0.6;
h=histogram(100.*vchange(sigoi&dnmod),-200:5:200,'FaceColor',[0 1 1]);
h.FaceAlpha = 1;
xlabel('Change in activity (%)')
ylabel('Neurons')
xlim([-100 100])
box(gca,'on')
set(gcf,'Position',[458   122   327   296])
set(gca,'XColor',[0 0 0],'YColor',[0 0 0],'FontSize',12,'LineWidth',1)
saveas(gcf,[spath 'visual_plus_whisker_histogram.fig'])
print([spath 'visual_plus_whisker_histogram'],'-dpng','-r600')
print([spath 'visual_plus_whisker_histogram'],'-depsc','-painters')


lim = 0.5;
range = 2.*lim;

vchangec = vchange(logical(sigoi));
vchangec(vchangec>lim) = lim;
vchangec(vchangec<-lim) = -lim;
vcolors = zeros(sum(sigoi),3);
vcolors(:,1) = (vchangec + lim)./range;
vcolors(:,2) = (-vchangec + lim)./range;
vcolors(:,3) = ones(numel(vchangec),1);

figure
imagesc(x,y,fliplr(I))
colormap(gray)
hold on
axis image
set(gca,'yDir','normal','xTick',[],'yTick',[])
h = scatter(nxv(logical(sigoi)),nyv(logical(sigoi)),10,vcolors,'Filled');
h.MarkerFaceAlpha = 0.1;
set(gcf,'Position',[250 50 700 920])
saveas(gcf,[spath 'visual_plus_whisker_map.fig'])
print([spath 'visual_plus_whisker_map'],'-dpng','-r600')
print([spath 'visual_plus_whisker_map'],'-depsc','-painters')

%% Whisker-tuned motion modulation analyis

mthr = mean(Sm)+std(Sm);
Smb = zeros(size(Sm));
Smb(Sm>mthr) = 1;

Ssb = zeros(size(Ssa));
Ssb(Ssa>0.05) = 1;

stinds = find(Ssa>0.99);
stmq = zeros(size(stinds));

QV = Smb .* Ssb;

% figure
% plot(t,Ssb,t,Smb.*0.5+0.25)

for dd = 1:numel(stinds);
    if sum(QV(stinds(dd)-num:stinds(dd)+3*num))>0
        stmq(dd) = 1;
    end
end

stmo = stinds(stmq>0);
stnmo = stinds(stmq<1);

strialsmo = zeros(ks,4*num+1,numel(stmo));
strialsnmo = zeros(ks,4*num+1,numel(stnmo));

stmi = zeros(ks,numel(stmo));
stnmi = zeros(ks,numel(stnmo));

for aa = 1:numel(stnmo)
    ioi = stnmo(aa);
    strialsnmo(:,:,aa) = Ts(:,ioi-num:ioi+3*num);
    stnmi(:,aa) = mean(Ts(:,ioi-num:ioi+3*num),2);
end

for bb = 1:numel(stmo)
    ioi = stmo(bb);
    strialsmo(:,:,bb) = Ts(:,ioi-num:ioi+3*num);
    stmi(:,bb) = mean(Ts(:,ioi-num:ioi+3*num),2);
end

[sigoi,p] = ttest2(stmi,stnmi,'Dim',2,'Alpha',sigthr,'Vartype',Vartype);
upmod = logical((mean(stmi,2) - mean(stnmi,2))>0);
dnmod = ~upmod;

[~,indn] = min(p+double(upmod));
[~,inup] = min(p+double(dnmod));

figure;
hold on
h = fill([tt fliplr(tt)],[mean(strialsmo(inup,:,:),3)+std(strialsmo(inup,:,:),[],3) fliplr(mean(strialsmo(inup,:,:),3)-std(strialsmo(inup,:,:),[],3))],'m','LineStyle','none');
h.FaceAlpha = falpha;
h = fill([tt fliplr(tt)],[mean(strialsnmo(inup,:,:),3)+std(strialsnmo(inup,:,:),[],3) fliplr(mean(strialsnmo(inup,:,:),3)-std(strialsnmo(inup,:,:),[],3))],'c','LineStyle','none');
h.FaceAlpha = falpha;
plot(tt,mean(strialsmo(inup,:,:),3),'m-')
plot(tt,mean(strialsnmo(inup,:,:),3),'c-','Color',[0 0.6 0.9])
% legend('Whisker + Motion','Whisker alone')
box(gca,'on')
xlabel('Time (s)')
ylabel('Trial-averaged \DeltaF/F_0')
xlim([min(tt) max(tt)])
set(gcf,'Position',[597   262   173   220])
xlim([-1 3])
set(gca,'XColor',[0 0 0],'YColor',[ 0 0 0],'FontSize',12,'LineWidth',1)
ylim([-0.2 1.7])
saveas(gcf,[spath 'whisker_plus_motion_example_mod_up.fig'])
print([spath 'whisker_plus_motion_example_mod_up'],'-dpng','-r600')
print([spath 'whisker_plus_motion_example_mod_up'],'-depsc','-painters')

pp = p.*dnmod;
pp(pp==0) = 100;
[pp,dninds] = sort(pp,'ascend');

smchange = (mean(stmi,2)-mean(stnmi,2))./mean(stnmi,2);
smchangep = smchange(dninds(1:131));

[mx,in] = max(abs(smchangep));

indn = dninds(in);

figure;
hold on
h = fill([tt fliplr(tt)],[mean(strialsmo(indn,:,:),3)+std(strialsmo(indn,:,:),[],3) fliplr(mean(strialsmo(indn,:,:),3)-std(strialsmo(indn,:,:),[],3))],'m','LineStyle','none');
h.FaceAlpha = falpha;
h = fill([tt fliplr(tt)],[mean(strialsnmo(indn,:,:),3)+std(strialsnmo(indn,:,:),[],3) fliplr(mean(strialsnmo(indn,:,:),3)-std(strialsnmo(indn,:,:),[],3))],'c','LineStyle','none');
h.FaceAlpha = falpha;
plot(tt,mean(strialsmo(indn,:,:),3),'m-')
plot(tt,mean(strialsnmo(indn,:,:),3),'b-','Color',[0 0.6 0.9])
% legend('Whisker + Motion','Whisker alone')
box(gca,'on')
xlabel('Time (s)')
ylabel('Trial-averaged \DeltaF/F_0')
xlim([min(tt) max(tt)])
set(gcf,'Position',[597   262   173   220])
xlim([-1 3])
set(gca,'XColor',[0 0 0],'YColor',[ 0 0 0],'FontSize',12,'LineWidth',1)
ylim([-0.2 1.7])
saveas(gcf,[spath 'whisker_plus_motion_example_mod_down.fig'])
print([spath 'whisker_plus_motion_example_mod_down'],'-dpng','-r600')
print([spath 'whisker_plus_motion_example_mod_down'],'-depsc','-painters')



figure
% h=histogram(100.*smchange,-200:5:200,'FaceColor',[0.5 0.5 0.5]);
hold on
% h.FaceAlpha = 0.6;
h=histogram(100.*smchange(sigoi&upmod),-200:5:200,'FaceColor','m');
h.FaceAlpha = 0.6;
h=histogram(100.*smchange(sigoi&dnmod),-200:5:200,'FaceColor',[0 1 1]);
h.FaceAlpha = 1;
xlabel('Change in activity (%)')
ylabel('Neurons')
xlim([-100 100])
box(gca,'on')
set(gcf,'Position',[458   122   327   296])
set(gca,'XColor',[0 0 0],'YColor',[0 0 0],'FontSize',12,'LineWidth',1)
saveas(gcf,[spath 'whisker_plus_motion_histogram.fig'])
print([spath 'whisker_plus_motion_histogram'],'-dpng','-r600')
print([spath 'whisker_plus_motion_histogram'],'-depsc','-painters')

lim = 0.5;
range = 2.*lim;

smchangec = smchange(logical(sigoi));
smchangec(smchangec>lim) = lim;
smchangec(smchangec<-lim) = -lim;
smcolors = zeros(sum(sigoi),3);
smcolors(:,1) = (smchangec + lim)./range;
smcolors(:,2) = (-smchangec + lim)./range;
smcolors(:,3) = ones(numel(smchangec),1);

figure
imagesc(x,y,fliplr(I))
colormap(gray)
hold on
axis image
set(gca,'yDir','normal','xTick',[],'yTick',[])
h = scatter(nxs(logical(sigoi)),nys(logical(sigoi)),10,smcolors,'Filled');
h.MarkerFaceAlpha = 0.1;
set(gcf,'Position',[250 50 700 920])
saveas(gcf,[spath 'whisker_plus_motion_map.fig'])
print([spath 'whisker_plus_motion_map'],'-dpng','-r600')
print([spath 'whisker_plus_motion_map'],'-depsc','-painters')

%% Visual-tuned motion modulation analyis

mthr = mean(Sm)+std(Sm);
Smb = zeros(size(Sm));
Smb(Sm>mthr) = 1;

Svb = zeros(size(Sva));
Svb(Sva>0.05) = 1;

vtinds = find(Sva>0.99);
vtmq = zeros(size(vtinds));

QV = Smb .* Svb;

% figure
% plot(t,Ssb,t,Smb.*0.5+0.25)

for dd = 1:numel(vtinds);
    if sum(QV(vtinds(dd)-num:vtinds(dd)+3*num))>0
        vtmq(dd) = 1;
    end
end

vtmo = vtinds(vtmq>0);
vtnmo = vtinds(vtmq<1);

vtrialsmo = zeros(kv,4*num+1,numel(vtmo));
vtrialsnmo = zeros(kv,4*num+1,numel(vtnmo));

vtmi = zeros(kv,numel(vtmo));
vtnmi = zeros(kv,numel(vtnmo));

for aa = 1:numel(vtnmo)
    ioi = vtnmo(aa);
    vtrialsnmo(:,:,aa) = Tv(:,ioi-num:ioi+3*num);
    vtnmi(:,aa) = mean(Tv(:,ioi-num:ioi+3*num),2);
end

for bb = 1:numel(vtmo)
    ioi = vtmo(bb);
    vtrialsmo(:,:,bb) = Tv(:,ioi-num:ioi+3*num);
    vtmi(:,bb) = mean(Tv(:,ioi-num:ioi+3*num),2);
end

[sigoi,p] = ttest2(vtmi,vtnmi,'Dim',2,'Alpha',sigthr,'Vartype',Vartype);
upmod = logical((mean(vtmi,2) - mean(vtnmi,2))>0);
dnmod = ~upmod;

[~,indn] = min(p+double(upmod));
[~,inup] = min(p+double(dnmod));

figure;
hold on
h = fill([tt fliplr(tt)],[mean(vtrialsmo(inup,:,:),3)+std(vtrialsmo(inup,:,:),[],3) fliplr(mean(vtrialsmo(inup,:,:),3)-std(vtrialsmo(inup,:,:),[],3))],'m','LineStyle','none');
h.FaceAlpha = falpha;
h = fill([tt fliplr(tt)],[mean(vtrialsnmo(inup,:,:),3)+std(vtrialsnmo(inup,:,:),[],3) fliplr(mean(vtrialsnmo(inup,:,:),3)-std(vtrialsnmo(inup,:,:),[],3))],'c','LineStyle','none');
h.FaceAlpha = falpha;
plot(tt,mean(vtrialsmo(inup,:,:),3),'m-')
plot(tt,mean(vtrialsnmo(inup,:,:),3),'c-','Color',[0 0.6 0.9])
% legend('Visual + Motion','Visual alone')
box(gca,'on')
xlabel('Time (s)')
ylabel('Trial-averaged \DeltaF/F_0')
xlim([min(tt) max(tt)])
set(gcf,'Position',[597   262   173   220])
xlim([-1 3])
set(gca,'XColor',[0 0 0],'YColor',[ 0 0 0],'FontSize',12,'LineWidth',1)
ylim([-0.2 1.7])
saveas(gcf,[spath 'visual_plus_motion_example_mod_up.fig'])
print([spath 'visual_plus_motion_example_mod_up'],'-dpng','-r600')
print([spath 'visual_plus_motion_example_mod_up'],'-depsc','-painters')

pp = p.*dnmod;
pp(pp==0) = 100;
[pp,dninds] = sort(pp,'ascend');

smchange = (mean(stmi,2)-mean(stnmi,2))./mean(stnmi,2);
smchangep = smchange(dninds(1:131));

[mx,in] = max(abs(smchangep));

indn = dninds(in);

figure;
hold on
h = fill([tt fliplr(tt)],[mean(vtrialsmo(indn,:,:),3)+std(vtrialsmo(indn,:,:),[],3) fliplr(mean(vtrialsmo(indn,:,:),3)-std(vtrialsmo(indn,:,:),[],3))],'m','LineStyle','none');
h.FaceAlpha = falpha;
h = fill([tt fliplr(tt)],[mean(vtrialsnmo(indn,:,:),3)+std(vtrialsnmo(indn,:,:),[],3) fliplr(mean(vtrialsnmo(indn,:,:),3)-std(vtrialsnmo(indn,:,:),[],3))],'c','LineStyle','none');
h.FaceAlpha = falpha;
plot(tt,mean(vtrialsmo(indn,:,:),3),'m-')
plot(tt,mean(vtrialsnmo(indn,:,:),3),'c-','Color',[0 0.6 0.9])
% legend('Visual + Motion','Visual alone')
box(gca,'on')
xlabel('Time (s)')
ylabel('Trial-averaged \DeltaF/F_0')
xlim([min(tt) max(tt)])
set(gcf,'Position',[597   262   173   220])
xlim([-1 3])
set(gca,'XColor',[0 0 0],'YColor',[ 0 0 0],'FontSize',12,'LineWidth',1)
ylim([-0.2 1.7])
saveas(gcf,[spath 'visual_plus_motion_example_mod_down.fig'])
print([spath 'visual_plus_motion_example_mod_down'],'-dpng','-r600')
print([spath 'visual_plus_motion_example_mod_down'],'-depsc','-painters')

vmchange = (mean(vtmi,2)-mean(vtnmi,2))./mean(vtnmi,2);

figure
% h=histogram(100.*vmchange,-200:5:200,'FaceColor',[0.5 0.5 0.5]);
hold on
% h.FaceAlpha = 0.6;
h=histogram(100.*vmchange(sigoi&upmod),-200:5:200,'FaceColor','m');
h.FaceAlpha = 0.6;
h=histogram(100.*vmchange(sigoi&dnmod),-200:5:200,'FaceColor',[0 1 1]);
h.FaceAlpha = 1;
xlabel('Change in activity (%)')
ylabel('Neurons')
xlim([-100 100])
box(gca,'on')
set(gcf,'Position',[458   122   327   296])
set(gca,'XColor',[0 0 0],'YColor',[0 0 0],'FontSize',12,'LineWidth',1)
saveas(gcf,[spath 'visual_plus_motion_histogram.fig'])
print([spath 'visual_plus_motion_histogram'],'-dpng','-r600')
print([spath 'visual_plus_motion_histogram'],'-depsc','-painters')

lim = 0.5;
range = 2.*lim;

vmchangec = vmchange(logical(sigoi));
vmchangec(vmchangec>lim) = lim;
vmchangec(vmchangec<-lim) = -lim;
vmcolors = zeros(sum(sigoi),3);
vmcolors(:,1) = (vmchangec + lim)./range;
vmcolors(:,2) = (-vmchangec + lim)./range;
vmcolors(:,3) = ones(numel(vmchangec),1);

figure
imagesc(x,y,fliplr(I))
colormap(gray)
hold on
axis image
set(gca,'yDir','normal','xTick',[],'yTick',[])
h = scatter(nxv(logical(sigoi)),nyv(logical(sigoi)),10,vmcolors,'Filled');
h.MarkerFaceAlpha = 0.1;
set(gcf,'Position',[250 50 700 920])
saveas(gcf,[spath 'visual_plus_motion_map.fig'])
print([spath 'visual_plus_motion_map'],'-dpng','-r600')
print([spath 'visual_plus_motion_map'],'-depsc','-painters')