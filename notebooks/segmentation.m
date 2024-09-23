%% Interactive Segmentation
clear;
%% POINT THIS TO YOUR DESIRED PLANE and MOTION-CORRECTED FILEPATH
plane = 26;
motion_corrected_path = fullfile('C:\Users\RBO\caiman_data\animal_01\session_01\motion_corrected');

%%

motion_corrected_filename = fullfile(motion_corrected_path, sprintf("motion_corrected_plane_%d.h5", plane));

%%
% data_size = metadata.data_size;

data = h5read(motion_corrected_filename, '/Y'); % you can get size from h5 as well
data_size = h5info(motion_corrected_filename, '/Y').ChunkSize(1:2); % you can get size from h5 as well

%%
% Pull metadata from a single file

% Gather relevent metadata
metadata = read_h5_metadata(motion_corrected_filename, '/Y');
data_size = h5info(motion_corrected_filename, '/Y').ChunkSize(1:2);
pixel_resolution = metadata.pixel_resolution;
frame_rate = metadata.frame_rate;
d1=data_size(1);d2=data_size(2);
d = data_size(1)*data_size(2);      % total number of samples
T = metadata.num_frames;
tau = ceil(7.5/metadata.pixel_resolution);


% 
% tau = ceil(7.5./pixel_resolution);  % (a little smaller than) half-size of neuron
% 
% % USER-SET VARIABLES - CHANGE THESE TO IMPROVE SEGMENTATION
% 
% merge_thresh = 0.8;                 % how temporally correlated any two neurons need to be to be merged
% min_SNR = 1.4;                      % signal-noise ratio needed to accept this neuron as initialized (1.4 is liberal)
% space_thresh = 0.2;                 % how spatially correlated nearby px need to be to be considered for segmentation
% sz = 0.1;                           % If masks are too large, increase sz, if too small, decrease. 0.1 lowest.
% p = 2;                              % order of dynamics
% 
% mx = ceil(pi.*(1.33.*tau).^2);
% mn = floor(pi.*(tau.*0.5).^2);     
% 
% % patch set up; basing it on the ~600 um strips of the 2pRAM, +50 um overlap between patches
% fov = metadata.fov(1);
% patch_size = round(fov/4.5).*[1,1];
% overlap = [1,1].*ceil(30./pixel_resolution);
% patches = construct_patches(data_size,patch_size,overlap);
% 
% 

merge_thresh = 0.8; % threshold for merging
min_SNR = 1.4; % liberal threshold, can tighten up in additional post-processing
space_thresh = 0.2; % threhsold for selection of neurons by space
time_thresh = 0.0;
sz = 0.1; % IF FOOTPRINTS ARE TOO SMALL, CONSIDER sz = 0.1
mx = ceil(pi.*(1.33.*tau).^2);
mn = floor(pi.*(tau.*0.5).^2); % SHRINK IF FOOTPRINTS ARE TOO SMALL
p = 2; % order of dynamics

% patch set up; basing it on the ~600 um strips of the 2pRAM, +50 um overlap between patches
sizY = data_size;
patch_size = round(650/pixel_resolution).*[1,1];
overlap = [1,1].*ceil(50./pixel_resolution);
patches = construct_patches(sizY,patch_size,overlap);

K = ceil(9.2e4.*20e-9.*(pixel_resolution.*patch_size(1)).^2); % number of components based on assumption of 9.2e4 neurons/mm^3

% Set caiman parameters
options = CNMFSetParms(...   
'd1',d1,'d2',d2,...                         % dimensionality of the FOV
'deconv_method','constrained_foopsi',...    % neural activity deconvolution method
'temporal_iter',3,...                       % number of block-coordinate descent steps 
'maxIter',15,...                            % number of NMF iterations during initialization
'spatial_method','regularized',...          % method for updating spatial components
'df_prctile',20,...                         % take the median of background fluorescence to compute baseline fluorescence 
'p',p,...                                   % order of AR dynamics    
'gSig',tau,...                              % half size of neuron
'merge_thr',merge_thresh,...                % merging threshold  
'nb',1,...                                  % number of background components  
'gnb',3,...         
'min_SNR',min_SNR,...                       % minimum SNR threshold
'space_thresh',space_thresh ,...            % space correlation threshold
'decay_time',0.5,...                        % decay time of transients, GCaMP6s
'size_thr', sz, ...
'search_method','ellipse',...
'min_size', round(tau), ...                 % minimum size of ellipse axis (default: 3)
'max_size', 2*round(tau), ....              % maximum size of ellipse axis (default: 8)
'dist', 1.25, ...                           % expansion factor of ellipse (default: 3)
'max_size_thr',mx,...                       % maximum size of each component in pixels (default: 300)
'time_thresh',time_thresh,...
'min_size_thr',mn,...                       % minimum size of each component in pixels (default: 9)
'refine_flag',0,...
'rolling_length',ceil(frame_rate*5),...
'fr', frame_rate);

% Run patched caiman
disp('Beginning patched, volumetric CNMF...')
[A,b,C,f,S,P,~,YrA] = run_CNMF_patches(data,K,patches,tau,p,options);
date = datetime(now,'ConvertFrom','datenum');

            %%
% Visualize Patches

figure;
img = h5read(motion_corrected_filename, '/Ym');

imagesc(img); axis image; axis off;
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

%%
% number of components based on assumption of 9.2e4 neurons/mm^3
% K = ceil(9.2e4.*20e-9.*(pixel_resolution.*patch_size(1)).^2);

% Set caiman parameters
 options = CNMFSetParms(...
    'd1',data_size(1),'d2',data_size(2),...                         % dimensionality of the FOV
    'deconv_method','constrained_foopsi',...    % neural activity deconvolution method
    'temporal_iter',3,...                       % number of block-coordinate descent steps
    'maxIter',15,...                            % number of NMF iterations during initialization
    'spatial_method','regularized',...          % method for updating spatial components
    'df_prctile',20,...                         % take the median of background fluorescence to compute baseline fluorescence
    'p',p,...                                   % order of autoregressive system (p = 0 no dynamics, p=1 just decay, p = 2, both rise and decay)
    'gSig',tau,...                              % half size of neuron
    'merge_thr',merge_thresh,...                % how correlated 2 neurons must be to merge
    'nb',1,...                                  % number of background components (keep at 1 or 2, 2 for more noisy background)
    'gnb',3,...
    'min_SNR',min_SNR,...                       % minimum SNR threshold
    'space_thresh',space_thresh ,...            % space correlation threshold
    'decay_time',0.5,...                        % decay time of transients, GCaMP6s
    'size_thr', sz, ...
    'min_size', round(tau), ...                 % minimum size of ellipse axis (default: 3)
    'max_size', 2*round(tau), ....              % maximum size of ellipse axis (default: 8)
    'max_size_thr',mx,...                       % maximum size of each component in pixels (default: 300)
    'min_size_thr',mn,...                       % minimum size of each component in pixels (default: 9)
    'rolling_length',ceil(frame_rate*5),...
    'fr', frame_rate ...
);    


%% run CNMF algorithm on patches and combine
tic;
motion_corrected_data = h5read(motion_corrected_filename, '/Y');
[A,b,C,f,S,P,RESULTS,YrA] = run_CNMF_patches(motion_corrected_data,K,patches,tau,p,options);
[ROIvars.rval_space,ROIvars.rval_time,ROIvars.max_pr,ROIvars.sizeA,keep] = classify_components_jeff(motion_corrected_data,A,C,b,f,YrA,options);
toc

%% Preview neurons aft

Cn =  correlation_image(motion_corrected_data);
Coor = plot_contours(A,Cn,options);

%% Classify / validate components

[rval_space,~,~,sizeA,~,~,traces] = classify_components_jeff(motion_corrected_data,A,C,b,f,YrA,options);
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
plot_components_GUI(motion_corrected_data,A(:,keep),C(keep,:),b,f,Cn,options);
% plot_components_GUI(YrA,A_or,C_or,b2,f2,Cn,options);

%% make movie
make_patch_video(A(:,keep),C(keep,:),b,f,motion_corrected_data,Coor,options);

%% refine temporal components
A_keep = A(:,keep);
C_keep = C(keep,:);
% [C2,f2,P2,S2,YrA2] = update_temporal_components(reshape(motion_corrected_data,d,T),A_keep,b,C_keep,f,P,options);
[C2,f2,P2,S2,YrA2] = update_temporal_components(reshape(motion_corrected_data,d,[]),A_keep,b,C_keep,f,P,options);

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

%%


%% Load variables for inspection

tsub = 6; % temporally downsampling the video helps with visualization

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
