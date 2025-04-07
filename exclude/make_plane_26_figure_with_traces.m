clear 
close all
clc

%% Get Image

LineWidth = 1;
FontSize = 12;
FontName = 'Arial';
save_path = '\\v-storage.rockefeller.edu\vazirilab_medium_data\jeff_demas\MAxiMuM_data\Paper_Figures\Fig2\';

N = 26;
load(['plane_' num2str(N) '_data.mat'])

x = linspace(0,600-12,size(poi,2));
y = 1:size(poi,1);

zz = 63;
num = 20;

mn = 1000;
mx = 12000;

I = mean(poi(:,:,zz-num:zz+num),3);
I = fixScanPhase(I,0,1);

It = I;
It = It-mn;
It(It<0) = 0;
It(It>mx) = mx;
It = It./mx;

Ic = repmat(It,[1 1 3]);
% Ic(25,20:70,1) = 1;
% Ic(25,20:70,2:3) = 0;

x1 = 306;
x2 = 398;
y1 = 15;
y2 = 115;

Ic(y1:y2,x1-2:x1-1,3) = 1;
Ic(y1:y2,x1-2:x1-1,1:2) = 0;

Ic(y1:y2,x2+1:x2+2,3) = 1;
Ic(y1:y2,x2+1:x2+2,1:2) = 0;

Ic(y1-2:y1-1,x1:x2,3) = 1;
Ic(y1-2:y1-1,x1:x2,1:2) = 0;

Ic(y2+1:y2+2,x1:x2,3) = 1;
Ic(y2+1:y2+2,x1:x2,1:2) = 0;

Icz = Ic(y1:y2,x1:x2,:);

% Icz(94,79:87,1) = 1;
% Icz(94,79:87,2:3) = 0;

Ic = Ic - 0.15;
Ic(Ic<0) = 0;
Ic = Ic./max(Ic(:));


%% Get Traces

load('plane_26_rois.mat')


% Correlation maps
AKm = mean(AKp,3);
AKm(AKm>0) = 1;

h = figure;
set(h,'Position',[50 50 800 800])

imagesc(Ic)
colormap(gray)
axis image
set(gca,'yTick',[],'xTick',[])
hold on
AKC = zeros(size(AKm,1),size(AKm,2),3);
AKC(:,:,1) = AKm;

im = imagesc(AKC);
im.AlphaData = 0.3;
xlim([x1 x2]);
ylim([y1 y2])

%% construct ROI

constructROIflag = 0;

newROI = zeros(size(Cn));

cont = 1;

if constructROIflag
    while cont>0

        h = figure;
        set(h,'Position',[50 50 800 800])

        imagesc(Ic)
        colormap(gray)
        axis image
        set(gca,'yTick',[],'xTick',[])
        hold on
        AKC = zeros(size(AKm,1),size(AKm,2),3);
        AKC(:,:,1) = AKm;

        im = imagesc(AKC);
        im.AlphaData = 0.3;
        xlim([x1 x2]);
        ylim([y1 y2])
        
        hh = imagesc(newROIc);
        hh.AlphaData = 0.3;
        
        [ix,iy] = ginput(1);
        ix = round(ix);
        iy = round(iy);
        
        if newROI(iy,ix) > 0
            newROI(iy,ix) = 0;
        else
            newROI(iy,ix) = 1;
        end
                        
        newROIc = repmat(0.5.*newROI,[1 1 3]);
        newROIc(:,:,[1 3]) = 0;
        
       
        
        close(h)
        
        if ix>x2 
            cont = 0;
        end
    end
    
    save('newROI.mat','newROI');

end

%%
load('newROI.mat')

load('plane_26_data.mat');

newT = reshape(mean(mean(repmat(newROI,[1 1 size(poi,3)]).*double(poi))),1,[]);
F0 = 0.69;

newT = (newT-F0)./F0;

figure;
plot(newT)

AKpp = cat(3,AKp,newROI);
Tkpp = cat(1,Tkp,single(newT));

%% Rejection

%% Display
kp = [1:4 7 9:12 16];
Tkppp = Tkpp(kp,:);
AKppp = AKpp(:,:,kp);

Tkppp(end-2,:) = 1./(sum(sum(AKppp(:,:,end-2)))+sum(sum(AKppp(:,:,end)))).*(Tkppp(end-2,:).*sum(sum(AKppp(:,:,end-2))) + Tkppp(end,:).*sum(sum(AKppp(:,:,end))));

AKppp(:,:,end-2) = AKppp(:,:,end-2) + max(max(AKppp(:,:,end-2))).*AKppp(:,:,end);

K = size(Tkppp,1)-1;

C = [0.9 0.4 0.8 0.3 0.7 0.2 0.6 0.1 0.5 0.0]';
C = [zeros(10,1), C, zeros(10,1)];
colors = C;
% colors = jet(K+1);
% colors = colors(2:end,:);

figure(101)
imagesc(Ic)
colormap(gray)
axis image
set(gca,'yTick',[],'xTick',[],'yDir','normal')
hold on
xlim([x1 x2])
ylim([y1 y2])

for ii = 1:K
    rk = AKppp(:,:,ii);
    rk = rk./max(rk(:));
    rkc = zeros(size(rk,1),size(rk,2),3);
    rkc(:,:,1) = rk.*colors(ii,1);
    rkc(:,:,2) = rk.*colors(ii,2);
    rkc(:,:,3) = rk.*colors(ii,3);

    figure(101)
    thr = 0.1;
    A_temp = AKppp(:,:,ii);
    A_temp = medfilt2(A_temp,[3,3]);
    A_temp(A_temp<thr*max(A_temp(:))) = 0;
    BW = bwareafilt(A_temp>0,1);                
    BW2 = bwboundaries(BW);

    for jj = 1:length(BW2)
        BW2{jj} = fliplr(BW2{jj});
        jjj=plot(BW2{jj}(:,1),BW2{jj}(:,2),'Color',colors(ii,:), 'linewidth', 4);
        jjj.Color(4) = 0.5;
    end

    figure(102)
    plot(linspace(0,180,size(Tkpp,2)),movmean(Tkppp(ii,:),5,2)+ii.*ones(1,size(Tkpp,2)),'Color',colors(ii,:),'LineWidth',1);
    hold on
    
end

figure(102)
set(gcf,'Position',[100 500 800 396])
ylim([0.5 K+1])
xlabel('Time')
ylabel('DFF0')
xlim([0 180])
box(gca,'on')
set(gca,'FontSize',FontSize,'LineWidth',LineWidth,'FontName',FontName)
set(gca,'XColor',[0 0 0],'YColor',[0 0 0])
print([save_path 'traces'],'-depsc')
xlabel('Time (s)')
ylabel('\DeltaF/F_0')
print([save_path 'traces.png'],'-dpng','-r600')
saveas(gcf,[save_path 'traces.fig'])

figure(101)
saveas(gcf,[save_path 'mean_projection_zoom_in_plane_' num2str(N) '.fig'])
print([save_path 'mean_projection_zoom_in_plane_' num2str(N)],'-depsc','-painters')
print([save_path 'mean_projection_zoom_in_plane_' num2str(N)],'-dpng','-r600')