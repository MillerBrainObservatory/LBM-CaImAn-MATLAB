%% Select file, read in

clear
% close all
clc

% path = '\\v-storage.rockefeller.edu\vazirilab_medium_data\jeff_demas\MAxiMuM_data\20191122\mh89_2mm_FOV_50_550um_depth_250mW_som_stimuli_9min_00001\';

choice = menu('Select NAS:','v-data1','v-data2','v-data3');

addpath(genpath('\\v-storage\vazirilab_medium_data\jeff_demas\PROCESSING_SCRIPTS\CaImAn_Utilities\motion_correction\'));

switch choice
    case 1
        path = '\\v-storage.rockefeller.edu\vazirilab_medium_data\jeff_demas\MAxiMuM_data\';
    case 2
        path = '\\v-storage2.rockefeller.edu\v-data2\jeff_demas\MAxiMuM_data\';
    case 3
        disp('Drive is not configured for use yet.')
end

[fileCSV,path] = uigetfile('*.csv','','MultiSelect','off',path);

%% Load in tracking data

d = importdata([path fileCSV]);
data = d.data;

paw_left_x = data(:,2);
paw_left_y = data(:,3);

paw_right_x = data(:,5);
paw_right_y = data(:,6);

dpL = sqrt(diff(paw_left_x).^2 + diff(paw_left_y).^2);
dpR = sqrt(diff(paw_right_x).^2 + diff(paw_right_y).^2);

figure; plot(dpR); hold on; plot(dpL)
xlabel('t (a.u.)')
ylabel('paw velocity (a.u.)')
legend('Right paw','Left paw')
saveas(gcf,[path 'raw_paw_tracking_data.fig'])
print(gcf,[path 'raw_paw_tracking_data.png'],'-dpng','-r600')

%% Load in LED clock

fileVID = uigetfile('*.mp4','','MultiSelect','off',path);

v = VideoReader([path fileVID]);

ind = 1;
val = nan(1,1e6);

f = readFrame(v);

hhh=figure;
set(gcf,'position',[200 200 800 600])
imagesc(f)
axis image
rect = round(getrect(gcf));
close(hhh)

fLight = f(rect(2):(rect(2)+rect(4)),rect(1):(rect(1)+rect(3)),:);
val(1) = mean(fLight(:));

nframes = numel(dpR);

hh = waitbar(0,'Parsing video...');

disp('Parsing video...')
while hasFrame(v)
    f = readFrame(v);
    ind = ind+1;
    fLight = f(rect(2):(rect(2)+rect(4)),rect(1):(rect(1)+rect(3)),:);
    val(ind) = mean(fLight(:));
    waitbar(ind./nframes,hh)
end

close(hh)

val = val(~isnan(val));

%% Set up blinking vector

[~,inds] = sort(val,'ascend');
bL = mean(val(inds(1:round(numel(val)/10))));

blink = val-bL;
blink = blink./max(blink);

tinds = 1:numel(blink);

[pks,locs] = findpeaks(blink,'minpeakdist',100);
locs = locs(pks>0.5);

t0 = locs(1);
dtcam = mean(diff(locs));

%% Load in data from MATLAB pulse configuration

[filePULSE,path2] = uigetfile('*.mat','','MultiSelect','Off',path);

load([path2 filePULSE])
FrameRate = P.fps;
dtmatlab = P.period_arduino_clk_secs;

t = 1:numel(blink);
t = t-t0;
t = t.*dtmatlab./dtcam;

tt = t(1:end-1);

figure; 
plot(t,blink)
hold on
plot(t(locs),blink(locs),'r.')
xlabel('time (a.u.)')
ylabel('LED power (a.u.)')
saveas(gcf,[path 'LED_time_sync.fig'])
print(gcf,[path 'LED_time_sync.png'],'-dpng','-r600')

% figure;
% plot(tt,dpL,tt,dpR)

dtt = mean(diff(tt));
tk = (-300:300).*dtt;
kernel = exp(tk./0.2);
tau = 0.55/log(2);
kernel(tk>=0) = exp(-tk(tk>=0)./tau);

% figure;
% plot(tk,kernel)

dpLc = conv(dpL,kernel,'same');
dpRc = conv(dpR,kernel,'same');

% figure;
% plot(tt,dpL,tt,dpLc,tt,dpR,tt,dpRc)

dtm = 1./FrameRate;

FrameClock = dtm:dtm:(540-dtm);

ftL = fit(tt',dpRc,'cubicspline');
ftR = fit(tt',dpLc,'cubicspline');

spawR = ftR(FrameClock);
spawL = ftL(FrameClock);

spaw = spawR+spawL;

figure;
plot(FrameClock,spawR,FrameClock,spawL,FrameClock,spaw)
xlabel('Time (s)')
ylabel('Paw motion (a.u.)')
legend('Right paw','Left paw','Both paws')
saveas(gcf,[path 'paw_tracking.fig'])
print(gcf,[path 'paw_tracking.png'],'-dpng','-r600')

save([path 'paw_tracking.mat'],'FrameClock','spaw','spawL','spawR')