clear
close all
clc

path = fullfile("D:\Jeffs LBM paper data\Fig5\20200910\MH184_both_6mm_FOV_150_600um_depth_410mW_9min_no_stimuli\output\collated_caiman_output_minSNR_1p4.mat");
load(path,'T_all')

gamma = 0.75;
T = size(T_all,2);
t = 1:T;
t = t./T.*540;

s = zeros(1,T);
s([132 773]) = 1;

tk = t-mean(t);
tau = 0.55/log(2);
kernel = exp(tk./0.2);
kernel(tk>=0) = exp(-tk(tk>=0)./tau);

sk = conv(s,kernel,'same');

Rm = corr(T_all',sk');

[~,srt] = sort(Rm,'descend');

Tm = T_all(srt,:);
Tm = movmean(Tm,2,2);
Tm = Tm./(max(Tm,[],2)*ones(1,T));
Tm(Tm<0) = 0;
Tm = Tm.^gamma;
Tm = uint8(256.*Tm);
K = size(T_all,1);
t = (1:T)*(540/T);
tw = 0;
numT = 1e3;
numS = 5;
Ts = T_all(srt(numS+1:numS+numT),:);

h = figure;
plot(t,movmean(Ts,2,2)+(1:numT)'*ones(1,size(Ts,2)),'k-')
set(gcf,'Position',[50 50 800 650])
xlim([tw tw+120])
ylim([0 50])

xr = [ones(1,200).*120, linspace(120,480,200)];
yr = [ones(1,200).*50, 50.*ones(1,200) + 450.*(1:200).^2./(200.^2)];
blk = [ones(1,375), linspace(1,0,25)];

filename = 'trace_video';
frameRate = 25;

writerObj = VideoWriter(filename,'Uncompressed AVI');
writerObj.FrameRate = frameRate;
open(writerObj)

% First epoch -- scan all traces
for j = 1:numel(xr)
    tw = j/8;
   
    figure(h)

    xlim([tw tw+xr(j)])
    ylim([0 yr(j)])
    
    yTick = linspace(0,yr(j),5);
    xTick = linspace(tw,tw+xr(j),5);
    
    set(gca,'yTick',yTick,'xTick',xTick)
    set(gca,'xTickLabel',{num2str(round(xTick(1))) num2str(round(xTick(2))) num2str(round(xTick(3))) num2str(round(xTick(4))) num2str(round(xTick(5)))})
    set(gca,'yTickLabel',{num2str(yTick(1),3) num2str(yTick(2),3) num2str(yTick(3),3) num2str(yTick(4),3) num2str(yTick(5),3)})

    xlabel('Time (s)')
    ylabel('\DeltaF/F_0')

    frame = getframe(h);
    I = frame.cdata;
    I = blk(j).*I(3:648,3:798,:);
    writeVideo(writerObj,I);
    
end

% Second epoch 
blk = [linspace(0,1,25), ones(1,575)];
yr2 = [ones(1,200).*500, 500.*ones(1,400) + ((size(T_all,1)-500)./400).*(1:400)];
xr = [ones(1,200).*180, linspace(180,480,400)];

clf;

figure(h)
imagesc(t,1:size(Tm,1),Tm);
caxis([0 256])
% axis off
set(gcf,'Position',[50  50   800   650])
set(gca,'ydir','normal')
xlim([tw tw+180])
ylim([0 500])
set(gca,'yTick',linspace(0,yr(j),5),'xTick',linspace(tw,tw+xr(j),5))
hold on


for j = 1:numel(xr)
    tw = min([j/8 200/8]);
    
    figure(h)

    xlim([tw tw+xr(j)])
    ylim([0 yr2(j)])
    
    yTick = linspace(0,yr2(j),5);
    xTick = linspace(tw,tw+xr(j),5);
    
    yT1 = num2str(round(yTick(1)));
    yT2 = num2str(round(yTick(2))); if size(yT2,2) == 4; yT2 = [yT2(1) ',' yT2(2:end)]; elseif size(yT2,2) == 5; yT2 = [yT2(1:2) ',' yT2(3:end)]; elseif size(yT2,2) == 6; yT2 = [yT2(1:3) ',' yT2(4:end)]; end
    yT3 = num2str(round(yTick(3))); if size(yT3,2) == 4; yT3 = [yT3(1) ',' yT3(2:end)]; elseif size(yT3,2) == 5; yT3 = [yT3(1:2) ',' yT3(3:end)]; elseif size(yT3,2) == 6; yT3 = [yT3(1:3) ',' yT3(4:end)]; end
    yT4 = num2str(round(yTick(4))); if size(yT4,2) == 4; yT4 = [yT4(1) ',' yT4(2:end)]; elseif size(yT4,2) == 5; yT4 = [yT4(1:2) ',' yT4(3:end)]; elseif size(yT4,2) == 6; yT4 = [yT4(1:3) ',' yT4(4:end)]; end
    yT5 = num2str(round(yTick(5))); if size(yT5,2) == 4; yT5 = [yT5(1) ',' yT5(2:end)]; elseif size(yT5,2) == 5; yT5 = [yT5(1:2) ',' yT5(3:end)]; elseif size(yT5,2) == 6; yT5 = [yT5(1:3) ',' yT5(4:end)]; end  
    
    set(gca,'yTick',yTick,'xTick',xTick)
    set(gca,'xTickLabel',{num2str(round(xTick(1))) num2str(round(xTick(2))) num2str(round(xTick(3))) num2str(round(xTick(4))) num2str(round(xTick(5)))})
    set(gca,'yTickLabel',{yT1 yT2 yT3 yT4 yT5})
    
    xlabel('Time (s)')
    ylabel('Neuron number')
    
    frame = getframe(h);
    I = frame.cdata;
    I = blk(j).*I(3:648,3:798,:);
    writeVideo(writerObj,I);
end

close(writerObj)
close(h)

ffmpegtranscode(filename, [filename(1:end-3) 'mp4'], 'AudioCodec', 'aac', 'VideoCodec', 'x264', 'Mpeg4Quality',1);
