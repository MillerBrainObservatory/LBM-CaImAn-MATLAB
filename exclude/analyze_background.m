clear
close all
clc

N = 18;
load(['data\data_plane_' num2str(N) '.mat'])
load(['data\caiman_output_plane_' num2str(N) '.mat'])

%%
rthr = 0.2;
min_snr= 1.4;
frameRate = 4.7;
decay_time = 0.5;
Nsamples = ceil(decay_time*frameRate);
min_fitness = log(normcdf(-min_snr))*Nsamples;
[fitness] = compute_event_exceptionality(T_keep,Nsamples,0);

kp = logical(fitness<min_fitness & rVals>rthr);

Ak = A_keep(:,kp);
Ak = full(Ak);
Ak = reshape(Ak,size(Cn,1),size(Cn,2),[]);
Ak = mean(Ak,3);
Ak(Ak>0) = 1;

% figure; imagesc(Ak); axis image; 

%% 

poi = single(poi);
Ab = ones(size(Ak))-Ak;
Abp = repmat(Ab,[1 1 size(poi,3)]);

I = mean(Abp.*poi,3);
Ibg = reshape(mean(mean(poi(:,1:250,:).*Abp(:,1:250,:),1),2),1,[]);
Ibg2 = reshape(mean(mean(poi(:,1:end,:).*Abp(:,1:end,:),1),2),1,[]);

t = 1:size(poi,3);
t = t./size(poi,3).*180;

figure;
plot(t,Ibg,t,Ibg2)

figure;
imagesc(I);
axis image