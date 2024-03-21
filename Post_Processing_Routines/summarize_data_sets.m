clear 
clc
% 
% paths = {'E:\Data\Scrooge\20210120\scrooge_0p6mmFOV_single_plane_300um_FOV5_depth_15percent_vis_stim_3min\output\'; ...
%          'E:\Data\Scrooge\20210120\scrooge_0p6mmFOV_single_plane_400um_FOV3_depth_20percent_vis_stim_3min\output\';...
%          'E:\Data\Scrooge\20210120\scrooge_0p6mmFOV_single_plane_500um_FOV5_depth_25percent_vis_stim_3min\output\';...
%          '\\v-storage\vazirilab_medium_data\joint_projects\marmoset\Scrooge\20210113\scrooge_anterior_middle_FOV1_600um_depth_100um_5percent_vis_stim\output\';...
%          '\\v-storage\vazirilab_medium_data\joint_projects\marmoset\Scrooge\20210113\scrooge_anterior_middle_FOV1_600um_depth_200um_5percent_vis_stim\output\';...
%          '\\v-storage\vazirilab_medium_data\joint_projects\marmoset\Scrooge\20210113\scrooge_anterior_middle_FOV1_600um_depth_300um_10percent_no_stim\output\';...
%          '\\v-storage\vazirilab_medium_data\joint_projects\marmoset\Scrooge\20210113\scrooge_anterior_middle_FOV1_600um_depth_300um_10percent_vis_stim\output\';...
%          '\\v-storage\vazirilab_medium_data\joint_projects\marmoset\Scrooge\20210113\scrooge_anterior_middle_FOV1_600um_depth_400um_15percent_vis_stim\output\';...
%          '\\v-storage\vazirilab_medium_data\joint_projects\marmoset\Scrooge\20210113\scrooge_anterior_middle_FOV1_600um_depth_500um_20percent_vis_stim\output\';...
%          '\\v-storage\vazirilab_medium_data\joint_projects\marmoset\Scrooge\20210113\scrooge_anterior_middle_FOV1_600um_depth_600um_20percent_vis_stim\output\';...
%          '\\v-storage\vazirilab_medium_data\joint_projects\marmoset\Scrooge\20210113\scrooge_anterior_middle_FOV1_600um_depth_200um_5percent_vis_stim\output\';...
%          '\\v-storage\vazirilab_medium_data\joint_projects\marmoset\Scrooge\20210113\scrooge_posterior_middle_FOV2_600um_depth_100um_5percent_vis_stim\output\';...
%          '\\v-storage\vazirilab_medium_data\joint_projects\marmoset\Scrooge\20210113\scrooge_posterior_middle_FOV2_600um_depth_200um_5percent_vis_stim\output\';...
%          '\\v-storage\vazirilab_medium_data\joint_projects\marmoset\Scrooge\20210113\scrooge_posterior_middle_FOV2_600um_depth_300um_10percent_vis_stim\output\';...
%          '\\v-storage\vazirilab_medium_data\joint_projects\marmoset\Scrooge\20210113\scrooge_posterior_middle_FOV2_600um_depth_400um_15percent_vis_stim\output\';...
%          '\\v-storage\vazirilab_medium_data\joint_projects\marmoset\Scrooge\20210113\scrooge_posterior_middle_FOV2_600um_depth_500um_20percent_vis_stim\output\';};

% paths = {'\\v-storage\vazirilab_medium_data\joint_projects\marmoset\Scrooge\20210113\scrooge_posterior_lateral_FOV4_2mm_depth_200um_5percent_vis_stim\output\';...
%          '\\v-storage\vazirilab_medium_data\joint_projects\marmoset\Scrooge\20210113\scrooge_posterior_lateral_FOV4_2mm_depth_300um_10percent_vis_stim\output\';...
%          '\\v-storage\vazirilab_medium_data\joint_projects\marmoset\Scrooge\20210113\scrooge_posterior_lateral_FOV4_2mm_depth_400um_15percent_vis_stim\output\';...
%          '\\v-storage\vazirilab_medium_data\joint_projects\marmoset\Scrooge\20210113\scrooge_posterior_lateral_FOV4_2mm_depth_500um_20percent_vis_stim\output\';...
%          '\\v-storage\vazirilab_medium_data\joint_projects\marmoset\Scrooge\20210113\scrooge_posterior_lateral_FOV4_2mm_depth_600um_25percent_vis_stim\output\';};

paths = {'E:\Data\Scrooge\20210120\scrooge_2mmFOV_single_plane_300um_depth_10percent_vis_stim_3min\output\';...
         'E:\Data\Scrooge\20210120\scrooge_2mmFOV_single_plane_300um_FOV2_depth_15percent_vis_stim_3min\output\';};

for abc = 1:size(paths,1)     
     
path = paths{abc};
file = 'caiman_output_plane_1.mat';

load([path file])

duration = 3;
FOV = 2000;

minSNR = 2;
minrVal = 0.4;

volumeRate = size(T_keep,2)./duration./60;
Ns = ceil(volumeRate*0.5);

ftn = compute_event_exceptionality(T_keep,Ns,0);

min_fitness = log(normcdf(-minSNR))*Ns;

keep = logical(ftn<min_fitness) & logical(rVals > minrVal);

C = C_keep(keep,:);

Ac = Ac_keep(:,:,keep);
cx = acx(keep);
cy = acy(keep);
num = (size(Ac,1)-1)/2;

Km = size(C,1);

A = zeros(size(Cn,1)+100,size(Cn,2)+100,Km);

for m = 1:Km
   Aoi = Ac(:,:,m);
   A(cy(m)+50-num:cy(m)+50+num,cx(m)+50-num:cx(m)+50+num,m) = Aoi;
end

A = A(51:size(A,1)-50,51:size(A,2)-50,:);

t = linspace(0,duration.*60,size(T_keep,2));

Cnorm = C;
Cnorm = Cnorm./(max(C,[],2)*ones(1,size(C,2)));

h = figure;
imagesc(t,1:Km,Cnorm)
xlabel('Time (s)')
ylabel('Neuron')
saveas(h,[path 'trace_heatmap.fig'])
print([path 'trace_heatmap.png'],'-dpng','-r600')


x = linspace(0,FOV,size(Cn,2));
y = linspace(0,FOV,size(Cn,1));

h = figure;
imagesc(x,y,Cn);
axis equal
colormap(gray)
xlim([0 FOV]); ylim([0 FOV])
xlabel('X (\mum)')
hold on
Ai = mean(A,3);
Ai(Ai>0) = 1;
Aic = repmat(Ai,[1 1 3]);
Aic(:,:,2:3) = 0;
h = imagesc(x,y,Aic);
h.AlphaData = 0.25.*Aic(:,:,1);
ylabel('Y (\mum)')
saveas(h,[path 'components.fig'])
print([path 'components.png'],'-dpng','-r600')



%%

Tk = T_keep(keep,:);

T = size(C,2);
dt = round(5*volumeRate);
s = zeros(1,T);
s(1:dt:end) = 1;

r = zeros(1,T);
r(randi(T,1,sum(s))) = 1;

tp = (-T:T)./volumeRate;

tau1 = 0.2;
tau2 = 0.55/log(2);
kernel = exp(tp./tau1);
kernel(tp>0) = exp(-tp(tp>0)./tau2);

kernel2 = zeros(size(tp));
kernel2(abs(tp)<1) = 1;

stim = conv(s,kernel,'same');

shuf = conv(r,kernel,'same');

Rstim = corr(Tk',stim');
Rshuf = corr(Tk',shuf');

figure;
% histogram(Rshuf,-0.5:0.01:1);
% hold on
histogram(Rstim,-0.5:0.01:1)
xlabel('Correlation')
xlim([-0.3 0.5])
title('Correlation of all traces with stimulus')
ylabel('Number')
saveas(gcf,[path 'correlation.fig'])
print([path 'correlation.png'],'-dpng','-r600')

[~,srt] = sort(Rstim,'descend');

Ntraces = 25;
if size(C,1) < Ntraces
    Ntraces = size(C,1);
end


offset = 1;

t = (1:T)./volumeRate;

figure; plot(t,movmean(Tk(srt(1:Ntraces),:),5,2)+(0:Ntraces-1)'*ones(1,T));
ylim([0 (Ntraces+1)*offset])

S = stim;
S(S>0.1) = 1;
S(S<1) = 0;
S = ones(Ntraces+1,1)*S;
S = repmat(S,[1 1 3]);
S(:,:,2:3) = 0;

hold on
h = imagesc(t,-1:(Ntraces+1)*offset,S);
h.AlphaData = S(:,:,1).*0.25;
xlim([0 max(t)])
xlabel('Time (s)')
ylabel('\DeltaF/F_0')
title('Top 25 most correlated traces')
saveas(gcf,[path 'corr_traces.fig'])
print([path 'corr_traces.png'],'-dpng','-r600')

close all
end