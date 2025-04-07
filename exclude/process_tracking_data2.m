clear
% close all
clc

%% Import Data

d = importdata('mh89_hemisphere_FOV_50_550um_depth_250mW_dual_stimuli_30min_00001DLC_resnet50_maximumJan21shuffle1_60000filtered.csv');
d = d.data;

wrist_left_x = d(:,14);
wrist_left_y = d(:,15);

wrist_right_x = d(:,17);
wrist_right_y = d(:,18);

ankle_x = d(:,20);
ankle_y = d(:,21);

brush_top_x = d(:,23);
brush_top_y = d(:,24);

brush_bottom_x = d(:,26);
brush_bottom_y = d(:,27);

NP = numel(brush_bottom_x)-1;
tc = (1:NP).*1800./NP;

num_sig = 2;
num_avg = 6;

%% Wrist, Left

wrist_left_d = sqrt(diff(wrist_left_x).^2 + diff(wrist_left_y).^2);
wrist_left_sig = std(wrist_left_d);

figure; 
plot(tc,wrist_left_d)
hold on
plot(tc,num_sig.*wrist_left_sig.*ones(size(wrist_left_d)))


%% Wrist, Right
wrist_right_d = sqrt(diff(wrist_right_x).^2 + diff(wrist_right_y).^2);
wrist_right_sig = std(wrist_right_d);

figure; 
plot(tc,wrist_right_d)
hold on
plot(tc,num_sig.*wrist_right_sig.*ones(size(wrist_right_d)))

%% Ankle

ankle_d = sqrt(diff(ankle_x).^2 + diff(ankle_y).^2);
ankle_sig = std(ankle_d);

figure; 
plot(tc,ankle_d)
hold on
plot(tc,num_sig.*ankle_sig.*ones(size(ankle_d)))

%% Brush Bottom

brush_bottom_d = sqrt(diff(brush_bottom_x).^2 + diff(brush_bottom_y).^2);
brush_bottom_sig = std(brush_bottom_d);

figure; 
plot(tc,brush_bottom_d)
hold on
plot(tc,brush_bottom_sig.*ones(size(brush_bottom_d)))

% Brush Top

brush_top_d = sqrt(diff(brush_top_x).^2 + diff(brush_top_y).^2);
brush_top_sig = std(brush_top_d);

figure; 
plot(tc,brush_top_d)
hold on
plot(tc,brush_top_sig.*ones(size(brush_top_d)))

ff = abs(fftshift(fft(fftshift(brush_top_d)))).^2;
freq = ((1:NP)-ceil(NP/2))./1800;

figure;
plot(freq,log10(ff))

%% Time vector setup

t = (1:2532)./2532.*9.*60;

swli = movmean(wrist_left_d,num_avg,2);
swri = movmean(wrist_right_d,num_avg,2);
sai = movmean(ankle_d,num_avg,2);
sbti = movmean(brush_top_d,1,2);

sig = std([swli swri sai],[],2);

swli(swli<sig.*num_sig) = 0;
swri(swri<sig.*num_sig) = 0;
sai(sai<sig.*num_sig) = 0;

swl = interp1(tc,swli,t);
swr = interp1(tc,swri,t);
sa = interp1(tc,sai,t); 
sm = sa+swl+swr;
sbt = interp1(tc,sbti,t);

swl = swl./max(swl);
swr = swr./max(swr);
sa = sa./max(sa);
sm = sm./max(sm);

swl(isnan(swl)) = 0;

figure;
plot(t,swl,t,swr+1,t,sa+2,t,3+sm)

figure;
plot(tc,sai./max(sai)./0.3386)
hold on
plot(t,sa,'r.')
xlim([0 540])

save('tracking_data2.mat','swl','swr','sa','sm','t')