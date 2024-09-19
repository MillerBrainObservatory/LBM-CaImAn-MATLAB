clear;

tsub = 6;

raw = "C://Users/RBO/caiman_data/animal_01/session_01/assembled/assembled_plane_26.h5";
motion_corrected = "C://Users/RBO/caiman_data/animal_01/session_01/motion_corrected/motion_corrected_plane_26.h5";
segmented = "C://Users/RBO/caiman_data/animal_01/session_01/segmented_2/segmented_plane_26.h5";

h5disp(segmented);

Cn = h5read(segmented, '/Cn');
rVals = h5read(segmented, '/rVals');
rVals = h5read(segmented, '/rVals');
T_keep = h5read(segmented, '/T_keep');
C_keep = h5read(segmented, '/C_keep');
Ac_keep = h5read(segmented, '/Ac_keep');
acm = h5read(segmented, '/acm');
acx = h5read(segmented, '/acx');
acy = h5read(segmented, '/acy');
b = h5read(segmented, '/b');
f = h5read(segmented, '/f');

Km = h5read(segmented, '/Km');

Y_raw = h5read(raw, '/Y');
Y_raw = downsample_data(Y_raw, 'time', tsub);
Ym_raw = h5read(raw, '/Ym');

Y_mc = h5read(motion_corrected, '/Y');
Y_mc = downsample_data(Y_mc, 'time', tsub);
Ym_raw = h5read(motion_corrected, '/Ym');

%%  view data
figure;play_movie({Y_raw, Y_mc},{'raw data', 'motion-corrected data'});
    
%% save data
filename = "C://Users/RBO/caiman_data/animal_01/session_01/motion_corrected/raw_mc_plane_26.mp4";
figure;write_frames_to_mp4([Y_raw Y_mc], filename, 30);

%% perform motion correction (start with rigid)
% parameters motion correction
% 'd1','d2': size of FOV
% 'bin_width': how often to update the template
% 'max_shift': maximum allowed rigid shift

options_rg = NoRMCorreSetParms('d1',size(Y,1),'d2',size(Y,2),'bin_width',100,'max_shift',15);

[M_rg,shifts_rg,template_rg] = normcorre_batch(Y,options_rg);

%% view data
tsub = 5;   % downsampling factor (only for display purposes)
Y_sub = downsample_data(Y,'time',tsub);
M_rgs = downsample_data(M_rg,'time',tsub);
%%
play_movie_save({Y_sub,M_rgs},{'raw data','rigid'},minY,maxY,1,savename);

play_movie({Y_sub,M_rgs},{'raw data','rigid'});

%% perform non-rigid motion correction    
% parameters motion correction
% 'd1','d2': size FOV movie
% 'grid_size','overlap_pre': parameters regulating size of patch (size patch ~ (grid_size + 2*overlap_pre))
% 'mot_uf': upsampling factor of the grid for shift application
% 'bin_width': how often to update the template
% 'max_shift': maximum allowed rigid shift
% 'max_dev': maximum deviation allowed for each patch from the rigid shift value

options_nr = NoRMCorreSetParms('d1',size(Y,1),'d2',size(Y,2),...
    'grid_size',[48,48],'mot_uf',4,'overlap_pre',[16,16],...
    'bin_width',100,'max_shift',15,'max_dev',8);

[M_nr,shifts_nr,template_nr] = normcorre_batch(Y,options_nr,template_rg);

%% view (downsampled) data
savename = fullfile(parent_path, 'registration_results.mp4');
M_nrs = downsample_data(M_nr,'time',tsub);
play_movie_save({Y_sub,M_rgs,M_nrs},{'raw data','rigid','pw-rigid'},minY,maxY, savename);

%% compute some metrics for motion correction quality assessment

[cY,mY,vY] = motion_metrics(Y,options_rg.max_shift);
[cM_rg,mM_rg,vM_rg] = motion_metrics(M_rg,options_rg.max_shift);
[cM_nr,mM_nr,vM_nr] = motion_metrics(M_nr,options_rg.max_shift);

%% plot metrics
figure;

ax(1) = subplot(2,3,1); imagesc(mY,[minY,maxY]);  axis equal; axis tight; axis off; title('mean raw data','fontsize',14,'fontweight','bold')
ax(2) = subplot(2,3,2); imagesc(mM_rg,[minY,maxY]); axis equal; axis tight; axis off; title('mean rigid corrected','fontsize',14,'fontweight','bold')
ax(3) = subplot(2,3,3); imagesc(mM_nr,[minY,maxY]); axis equal; axis tight; axis off; title('mean non-rigid corrected','fontsize',14,'fontweight','bold')
subplot(2,3,4); plot(1:T,cY,1:T,cM_rg,1:T,cM_nr); legend('raw data','rigid','non-rigid'); title('correlation coefficients','fontsize',14,'fontweight','bold')
subplot(2,3,5); scatter(cY,cM_rg); hold on; plot([0.9*min(cY),1.05*max(cM_rg)],[0.9*min(cY),1.05*max(cM_rg)],'--r'); axis square;
xlabel('raw data','fontsize',14,'fontweight','bold'); ylabel('rigid corrected','fontsize',14,'fontweight','bold');
subplot(2,3,6); scatter(cM_rg,cM_nr); hold on; plot([0.95*min(cM_rg),1.05*max(cM_nr)],[0.95*min(cM_rg),1.05*max(cM_nr)],'--r'); axis square;
xlabel('rigid corrected','fontsize',14,'fontweight','bold'); ylabel('non-rigid corrected','fontsize',14,'fontweight','bold');
linkaxes(ax,'xy')

%% plot shifts

shifts_r = squeeze(cat(3, shifts_rg(:).shifts));
shifts_n = cat(ndims(shifts_nr(1).shifts)+1, shifts_nr(:).shifts);
shifts_n = reshape(shifts_n,[],ndims(Y)-1,T);
shifts_x = squeeze(shifts_n(:,2,:))';
shifts_y = squeeze(shifts_n(:,1,:))';

patch_id = 1:size(shifts_x,2);
str = strtrim(cellstr(int2str(patch_id.')));
str = cellfun(@(x) ['patch # ',x],str,'un',0);

figure;
ax1 = subplot(311); plot(1:T,cY,1:T,cM_rg,1:T,cM_nr); legend('raw data','rigid','non-rigid'); title('correlation coefficients','fontsize',14,'fontweight','bold')
set(gca,'Xtick',[])
ax2 = subplot(312); plot(mean(shifts_x, 2)); hold on; plot(shifts_r(:,2),'--k','linewidth',2); title('displacements along x','fontsize',14,'fontweight','bold')
set(gca,'Xtick',[])
ax3 = subplot(313); plot(shifts_y); hold on; plot(shifts_r(:,1),'--k','linewidth',2); title('displacements along y','fontsize',14,'fontweight','bold')
xlabel('timestep','fontsize',14,'fontweight','bold')
linkaxes([ax1,ax2,ax3],'x')

%% now perform source extraction by splitting the FOV in patches

sizY = size(M_nr);
patch_size = [64,64];                   % size of each patch along each dimension (optional, default: [32,32])
overlap = [8,8];                        % amount of overlap in each dimension (optional, default: [4,4])

patches = construct_patches(sizY(1:end-1),patch_size,overlap);
K = 4;                                            % number of components to be found
tau = 4;                                          % std of gaussian kernel (half size of neuron)
p = 2;                                            % order of autoregressive system (p = 0 no dynamics, p=1 just decay, p = 2, both rise and decay)

options = CNMFSetParms(...
    'd1',sizY(1), ...
    'd2',sizY(2),...
    'ssub',1,...                % downsample in space (NO)
    'tsub',2,...                % downsample in time
    'merge_thr',0.8,...         % correlation threshold for merging
    'gSig',tau,...
    'gnb',2,...                 % number of background components
);

%% run CNMF algorithm on patches and combine
tic;
[A,b,C,f,S,P,RESULTS,YrA] = run_CNMF_patches(M_nr,K,patches,tau,p,options);
[ROIvars.rval_space,ROIvars.rval_time,ROIvars.max_pr,ROIvars.sizeA,keep] = classify_components(M_nr,A,C,b,f,YrA,options);
toc

%% a simple GUI
mat_segmented = fullfile("C://Users/RBO/caiman_data/animal_01/session_01/segmented_2/caiman_output_plane_26.mat");
mat_segmented = open(mat_segmented);

h5_segmented = fullfile("C://Users/RBO/caiman_data/animal_01/session_01/segmented_2/segmented_plane_26.h5");
h5_segmented = h5read(h5_segmented, '/T_keep');

Coor = plot_contours(A,Cn,options,1); close;

%%
h5_segmented_jeff = fullfile("D://Jeffs LBM paper data/Fig4a-c/20191121/MH70/caiman_output_plane_26.mat");
h5_segmented_jeff = open(h5_segmented_jeff);

x = 2;
%%
h5_segmented_jeff = fullfile("D://Jeffs LBM paper data/Fig4a-c/20191121/MH70/caiman_output_plane_26.mat");
h5_segmented_jeff = open(h5_segmented_jeff);

x = 2; 

%% Classify / validate components

h5_segmented = fullfile("C://Users/RBO/caiman_data/animal_01/session_01/segmented_2/segmented_plane_26.h5");
h5_segmented = h5read(h5_segmented, '/T_keep');

pixel_resolution = metadata.pixel_resolution;
frame_rate = metadata.frame_rate;
[d1,d2,T] = size(M_nr);
d = d1*d2; % total number of samples
tau = ceil(7.5./pixel_resolution);

merge_thresh = 0.8; % threshold for merging
min_SNR = 0.8; % liberal threshold, can tighten up in additional post-processing
space_thresh = 0.5; % threhsold for selection of neurons by space
time_thresh = 0.0;

[rval_space,~,~,sizeA,~,~,traces] = classify_components_jeff(M_nr,A,C,b,f,YrA,options);
ind_corr = (rval_space > space_thresh) & (sizeA >= options.min_size_thr) & (sizeA <= options.max_size_thr);

% Event exceptionality:
fitness = compute_event_exceptionality(traces,options.N_samples_exc,options.robust_std);
ind_exc = (fitness < options.min_fitness);

% Select components:
keep = ind_corr & ind_exc;

A_keep = A(:,keep);
C_keep = C(keep,:);
Km = size(C_keep,1); % total number of components

rVals = rval_space(keep);

%% view contour plots of selected and rejected components

throw = ~keep;
figure;
ax1 = subplot(121); plot_contours(A(:,keep),Cn,options,0,[],Coor,1,find(keep)); title('Selected components','fontweight','bold','fontsize',14);
ax2 = subplot(122); plot_contours(A(:,throw),Cn,options,0,[],Coor,1,find(throw));title('Rejected components','fontweight','bold','fontsize',14);
linkaxes([ax1,ax2],'xy')

%% inspect components
plot_components_GUI(M_nr,A(:,keep),C(keep,:),b,f,Cn,options);
plot_components_GUI(Yr,A_or,C_or,b2,f2,Cn,options);

%% make movie

make_patch_video(A(:,keep),C(keep,:),b,f,M_nr,Coor,options)

%% refine temporal components
A_keep = A(:,keep);
C_keep = C(keep,:);
[C2,f2,P2,S2,YrA2] = update_temporal_components(reshape(M_nr,[],T),A_keep,b,C_keep,f,P,options);

%% detrend fluorescence and extract DF/F values

df_percentile = 30;
window = 1000;

F = diag(sum(A_keep.^2))*(C2 + YrA2);                   % fluorescence
Fd = prctfilt(F,df_percentile,window);                  % detrended fluorescence
Bc = prctfilt((A_keep'*b)*f2,30,1000,300,0) + (F-Fd);   % background + baseline for each component
F_dff = Fd./Bc;

%% deconvolve data

nNeurons = size(F_dff,1);
C_dec = zeros(size(F_dff));
S = zeros(size(F_dff));
kernels = cell(nNeurons,1);
min_sp = 3;    % find spikes resulting in transients above min_sp x noise level

for i = 1:nNeurons
    [C_dec(i,:),S(i,:),kernels{i}] = deconvCa(F_dff(i,:), [], min_sp, true, false, [], 20, [], 0);
end

%% plot a random component

i = randi(nNeurons);

figure;plot(1:T,F_dff(i,:),'--w'); hold all; plot(1:T,C_dec(i,:),'r','linewidth',2);
spt = find(S(i,:));
if spt(1) == 1; spt(1) = []; end
hold on; scatter(spt,repmat(-0.25,1,length(spt)),'m*')
title(['Component ',num2str(i)]);

legend('Fluorescence DF/F','Deconvolved','Spikes')

figure;
imshow(Cn);
hold on;

for k = 1:length(patches)
    patch = patches{k};
    x = [patch(3), patch(4), patch(4), patch(3)];
    y = [patch(1), patch(1), patch(2), patch(2)];
    fill(x, y, 'g', 'FaceAlpha', 0.2, 'EdgeColor', 'none');  % Green with 50% opacity
end

% Draw overlaps
for k = 1:length(patches)
    patch = patches{k};
    for i = patch(1):overlap(1):patch(2)-overlap(1)
        for j = patch(3):overlap(2):patch(4)-overlap(2)
            x = [j, j + overlap(2), j + overlap(2), j];
            y = [i, i, i + overlap(1), i + overlap(1)];
            fill(x, y, 'b', 'FaceAlpha', 0.05, 'EdgeColor', 'none');  % Blue with 20% opacity
        end
    end
end

