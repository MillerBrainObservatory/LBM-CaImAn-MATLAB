clear
close all
clc

load('neuron_coordinates_and_traces.mat');
load('thresholds.mat')

load('mean_brain_image.mat')
x = (1:1:size(I,2)).*4.2; % x and y pixel arrays
y = (1:1:size(I,1)).*5;

nxp = nx - max(x); nxp = -nxp;
nyp = ny;
alpha = 158/2500^2;
nzp = nz - alpha.*((nx-1500).^2 + (ny-2500).^2);

spath = '\\v-storage\vazirilab_medium_data\jeff_demas\MAxiMuM_data\Paper_Figures\NewFig3\';

%% whisker-tuned neurons

num = 2e2;

[~,srt] = sort(Rs,'descend');

Ts = T_all(srt(1:num),:);
nxs = nxp(srt(1:num));
nys = nyp(srt(1:num));
nzs = nzp(srt(1:num));

t = linspace(0,540,size(Ts,2));

Cs = zeros(num,size(Ts,2));
disp('De-convolving raw traces...')
for j = 1:num
    spkmin = 0.5*GetSn(Ts(j,:));
    [cc, spk, opts_oasis] = deconvolveCa(Ts(j,:),'ar2','optimize_b',true,'method','thresholded',...
        'optimize_pars',true,'maxIter',100,'smin',spkmin);    
    cb = opts_oasis.b;
    
    Cs(j,:) = full(cc(:)' + cb);
    
end

stinds = find(Ssa>0.99); % indices of whisker trials alone
numt = 5;
tt = -2*numt:3*numt; tt = tt.*mean(diff(t));

strials = zeros(num,numel(tt),numel(stinds));
strialsc = strials;
pkval = zeros(num,numel(stinds));

for j = 1:numel(stinds)
    strials(:,:,j) = Ts(:,stinds(j)-2*numt:stinds(j)+3*numt);
    strialsc(:,:,j) = Cs(:,stinds(j)-2*numt:stinds(j)+3*numt);
    pkval(:,j) = mean(Cs(:,stinds(j)-2:stinds(j)+2),2);
end

stdpk = std(pkval,[],1);

sbtinds = find(Sb>0.99); % indices of whisker + visual trials
sbtinds = sbtinds(1:end-1);

sbtrials = zeros(num,numel(tt),numel(sbtinds));
sbtrialsc = strials;
pkvalb = zeros(num,numel(sbtinds));

for j = 1:numel(sbtinds)
    sbtrials(:,:,j) = Ts(:,sbtinds(j)-2*numt:sbtinds(j)+3*numt);
    sbtrialsc(:,:,j) = Cs(:,sbtinds(j)-2*numt:sbtinds(j)+3*numt);
    pkvalb(:,j) = mean(Ts(:,sbtinds(j)-2:sbtinds(j)+2),2);
end



ind1 = dsearchn(tt',-5/4.7);
ind2 = dsearchn(tt',20/4.7);
vecs = reshape(sum(strials(:,ind1:ind2,:),2),num,[]);
vecsb = reshape(sum(sbtrials(:,ind1:ind2,:),2),num,[]);
[sigoi,p] = ttest2(vecs,vecsb,'Dim',2,'Alpha',0.05,'Vartype','equal');

NXs = nxs*ones(1,num);
NYs = nys*ones(1,num);
NZs = nzs*ones(1,num);

%%

D = sqrt((NXs-NXs').^2 + (NYs-NYs').^2 + (NZs-NZs').^2);
% D = triu(D,1);
% D(D==0) = 0;

R = (corr(pkvalb',pkvalb'));

Dz = NZs-NZs';

figure;
histogram(D)

Dthr = D;
Dthr(Dthr<1000) = 0;
Dthr(~sigoi,:) = 0;
Dthr(:,~sigoi) = 0;
Dthr(Dthr>0) = 1;

Rthr = R;
Rthr(Rthr<0.3) = 0;

figure;
imagesc(Dthr.*Rthr)
axis image

Rthr2 = abs(R);
Rthr2(abs(Rthr2)>0.1) = 0;

figure;
imagesc(Dthr.*Rthr2)

[~,srtx] = sort(nxs,'ascend');
[~,srty] = sort(nys,'ascend');
[~,srtz] = sort(nzs,'descend');

figure;
imagesc(Rthr2(srtz,srtx))

%%
candidates = [37 39 41 42 71 129 145 153]; % 93 94
% candidates = [27 40 47];
Kc = numel(candidates);
% candidates = candidates([1 3 5]);

% numtrials = 10;

% figure;
% set(gcf,'Position',[50 50 1200 650])
% for a = 1:Kc
%     subplot(Kc,numtrials+1,(a-1)*(numtrials+1)+1)
%     h = fill([tt fliplr(tt)],[mean(strials(candidates(a),:,:),3)+std(strials(candidates(a),:,:),[],3) fliplr(mean(strials(candidates(a),:,:),3)-std(strials(candidates(a),:,:),[],3))],'b-','LineStyle','none');
%     hold on
%     plot(tt,mean(strials(candidates(a),:,:),3),'k-')
%     h.FaceAlpha = 0.1;
%     xlim([-2 3])
%     ylim([-0.3 2.7])
%     
%     if a == 1
%         title('Trial-average')
%     end
%     
%     for b = 1:numtrials
%         subplot(Kc,numtrials+1,(a-1)*(numtrials+1)+b+1)
%         plot(tt,strials(candidates(a),:,indsrt(b)),'b.')
%         hold on
%         plot(tt,strialsc(candidates(a),:,indsrt(b)),'k-')
%         xlim([-2 3])
%         ylim([-0.3 2.7])
%         
%         if a == 1
%             title(['Trial ' num2str(indsrt(b))])
%         end
%     end
%     
%     annotation('textbox',[0.03, 0.875 - (a-1)*0.225, 0, 0],'string',['(' num2str(nxs(candidates(a))) ', ' num2str(nys(candidates(a))) ', ' num2str(nzs(candidates(a))) ')'])
% end
% 
% saveas(gcf,[spath 'whisker_trial_variation.fig'])
% 
% % whisker-tuned neurons, modulated by visual stimuli
% 
% [~,indsrtb] = sort(stdpkb,'descend');

std_across_neurons = std(pkvalb(candidates,:),[],1);
std_across_trials = sqrt(mean(abs(pkvalb(candidates,:) - mean(pkvalb(candidates,:),2)*ones(1,numel(sbtinds))).^2,1));
% [~,indsrtb] = sort(std_across_neurons,'ascend');
indsrtb = 5:33;

numtrials = 15;

buffer = 2.5;

figure;
% set(gcf,'Position',[50 50 1200 650])
set(gcf,'Position',[50 50 600 650])


for a = 1:Kc
    subplot(Kc,1,a)
    h = fill([tt fliplr(tt)],[mean(sbtrials(candidates(a),:,:),3)+std(sbtrials(candidates(a),:,:),[],3) fliplr(mean(sbtrials(candidates(a),:,:),3)-std(sbtrials(candidates(a),:,:),[],3))],'b-','LineStyle','none');
    hold on
    plot(tt,mean(sbtrials(candidates(a),:,:),3),'k-')
    h.FaceAlpha = 0.25;
%     xlim([-2 3])
    ylim([-0.3 2.5])
    axis off
    
%     if a == 1
%         title('Trial-average')
%     end
    
    for b = 1:numtrials
        subplot(Kc,1,a)
        plot(tt+(buffer+(max(tt)-min(tt)))*b,sbtrials(candidates(a),:,indsrtb(b)),'b.','MarkerSize',4)
        hold on
        plot(tt+(buffer+(max(tt)-min(tt)))*b,sbtrialsc(candidates(a),:,indsrtb(b)),'k-')
        xlim([-2 123])
        ylim([-0.3 2.5])
        axis off
        
%         if a == 1
%             title([num2str(indsrtb(b))])
%         end
    end
    
    if a == 1
        
        plot([121 121],[1.5 2.5],'r-')
    end
    
%     annotation('textbox',[0.03, 1-0.125*4/Kc - (a-1)*(0.225*4/Kc), 0, 0],'string',['(' num2str(nxs(candidates(a))) ', ' num2str(nys(candidates(a))) ', ' num2str(nzs(candidates(a))) ')'])
end

saveas(gcf,[spath 'whisker_mod_vis_trial_variation2.fig'])
print(gcf,[spath 'whisker_mod_vis_trial_variation2.eps'],'-depsc','-painters')


%% behavior-tuned neurons

num = 100;

d = load('tracking_data2.mat','sm','t');
sm = circshift(d.sm,0,2); % this compensates for the camera being turned on ~0.8 s after measurement starts
ttm = d.t-mean(d.t);
tau = 0.55/log(2);
kernel = exp(ttm./0.2);
kernel(ttm>=0) = exp(-ttm(ttm>=0)./tau);

Sm = conv(sm,kernel,'same');
Smthresh = Sm;

Smthresh(Smthresh<0.5) = 0;
Smthresh = movmean(Smthresh,3,2);
[pks,mtinds] = findpeaks(Smthresh);

[~,srt] = sort(Rm,'descend');

Tm = T_all(srt(1:num),:);
nxm = nxp(srt(1:num));
nym = nyp(srt(1:num));
nzm = nzp(srt(1:num));

t = linspace(0,540,size(Tm,2));
lag = zeros(1,num);
Cm = zeros(num,size(Tm,2));
disp('De-convolving raw traces...')
for j = 1:num
    spkmin = 0.5*GetSn(Tm(j,:));
    [cc, spk, opts_oasis] = deconvolveCa(Tm(j,:),'ar2','optimize_b',true,'method','thresholded',...
        'optimize_pars',true,'maxIter',100,'smin',spkmin);    
    cb = opts_oasis.b;
    
    Cm(j,:) = full(cc(:)' + cb);
    
    [rs,ls] = xcorr(Sm',Cm(j,:)',12);
    [r,in] = max(rs);
    lag(j) = ls(in);
    
end

numt = 5;
tt = -6*numt:9*numt; tt = tt.*mean(diff(t));

mtrials = zeros(num,numel(tt),numel(mtinds));
mtrialsc = mtrials;
pkval = zeros(num,numel(mtinds));

for j = 1:numel(mtinds)
    mtrials(:,:,j) = Tm(:,mtinds(j)-6*numt:mtinds(j)+9*numt);
    mtrialsc(:,:,j) = Cm(:,mtinds(j)-6*numt:mtinds(j)+9*numt);
    pkval(:,j) = mean(Cm(:,mtinds(j)-2:mtinds(j)+2),2);
end

NXm = nxm*ones(1,num);
NYm = nym*ones(1,num);
NZm = nzm*ones(1,num);

D = sqrt((NXm-NXm').^2 + (NYm-NYm').^2 + (NZm-NZm').^2);
D = triu(D,1);
D(D==0) = NaN;

Dz = NZm-NZm';

figure;
histogram(D)

Dthr = D;
Dthr(Dthr<1000) = 0;
% Dthr(~sigoi,:) = 0;
% Dthr(:,~sigoi) = 0;

figure;
imagesc(Dthr)




%%
candidates = [94 84 19 12 44]; %79
lag(candidates)
% candidates = [27 40 47];
Kc = numel(candidates);
% candidates = candidates([1 3 5]);

numtrials = 5;

indsrt = 1:5;

buffer = 5.798;

figure;
% set(gcf,'Position',[50 50 1200 650])
set(gcf,'Position',[50 50 600 650])

for a = 1:Kc
    subplot(Kc,1,a)
    h = fill([tt fliplr(tt)],[mean(mtrials(candidates(a),:,:),3)+std(mtrials(candidates(a),:,:),[],3) fliplr(mean(mtrials(candidates(a),:,:),3)-std(mtrials(candidates(a),:,:),[],3))],'r-','LineStyle','none');
    hold on
    plot(tt,mean(mtrials(candidates(a),:,:),3),'k-')
    h.FaceAlpha = 0.25;
%     xlim([-5 10])
    ylim([-0.3 5])
    
    for b = 1:numtrials
        subplot(Kc,1,a)
        plot(tt+b*21.7997,mtrials(candidates(a),:,indsrt(b)),'r.','MarkerSize',4)
        hold on
        plot(tt+b*21.7997,mtrialsc(candidates(a),:,indsrt(b)),'k-')
        xlim([-6.4 118.6])
        ylim([-0.3 5])
        axis off

        if a == 1
            plot([118.5 118.5],[2 3],'r-')
        end
    end
    
%     annotation('textbox',[0.03, 1-4/Kc*0.125 - (a-1)*0.225*4/Kc, 0, 0],'string',['(' num2str(nxm(candidates(a))) ', ' num2str(nym(candidates(a))) ', ' num2str(nzm(candidates(a))) ')'])
end

saveas(gcf,[spath 'motion_trial_variation2.fig'])
print(gcf,[spath 'motion_trial_variation2.eps'],'-depsc','-painters')