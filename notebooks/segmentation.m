%% Interactive segmentation for mk303 01/30/25
% This notebook goes through the same process that occurs 
% when calling segmentPlane.m
plane = 7;

motion_corrected_path = "D:\W2_DATA\kbarber\2025-01-30\mk303\green\lbm_caiman_matlab\v4\results";
motion_corrected_filename = fullfile(motion_corrected_path, sprintf("motion_corrected_plane_%d.h5", plane));
data = h5read(motion_corrected_filename, '/Y');

%% Gather relevent metadata
metadata = read_h5_metadata(motion_corrected_filename, '/Y');

% Metadata holds our data size, frame rate and resolution
% with this we set Tau, the neuron half-size

data_size = h5info(motion_corrected_filename, '/Y').ChunkSize(1:2);
pixel_resolution = metadata.pixel_resolution;
frame_rate = metadata.frame_rate;
d1=data_size(1);d2=data_size(2);
d = data_size(1)*data_size(2);      % total number of samples
T = metadata.num_frames;
tau = ceil(7.5/metadata.pixel_resolution);

%% Set evaluation parameters
%  Evaluation parameters control which neurons are accepted/rejected

merge_thresh = 0.8;                 % how temporally correlated any two neurons need to be to be merged
min_SNR = 1.4;                      % signal-noise ratio needed to accept this neuron as initialized (1.4 is liberal)
space_thresh = 1;                 % how spatially correlated nearby px need to be to be considered for segmentation
time_thresh = 0.0;
sz = 0.1;                           % IF FOOTPRINTS ARE TOO LARGE, CONSIDER sz = 0.2
mx = ceil(pi.*(1.33.*tau).^2);
mn = floor(pi.*(tau.*0.5).^2); 
p = 2;

sizY = data_size;
patch_size = [128,128];                   % size of each patch along each dimension (optional, default: [32,32])
overlap = [16,16];                        % amount of overlap in each dimension (optional, default: [4,4])

patches = construct_patches(sizY,patch_size,overlap);

% K = ceil(9.2e4.*20e-9.*(pixel_resolution.*patch_size(1)).^2); % number of components based on assumption of 9.2e4 neurons/mm^3
K = 45;
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
'fr', frame_rate ...
);

%% Visualize Patches

figure;
img = h5read(motion_corrected_filename, '/Ym');

%% Patch setup
patch_size = [128,128];             % size of each patch along each dimension (optional, default: [32,32])
overlap = [16,16];                  % amount of overlap in each dimension (optional, default: [4,4])
patches = construct_patches(data_size,patch_size,overlap);
% patches = construct_patches(data_size,data_size,[]); % use this for a single patch

%% Visualize patches
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

%% Run planar-CNMF
disp('Beginning patched, volumetric CNMF...')

K=800;
[A,b,C,f,~,P,~,YrA] = run_CNMF_patches(data,K,patches,tau,p,options);
sprintf("Number of neurons: %d", size(A, 2))

%% Preview accepted/rejected neurons before any tuning

Cn =  correlation_image(data);
Coor = plot_contours(A,Cn,options);

%% Classify / validate components
space_thresh = 0.2;
[rval_space,~,~,sizeA,~,~,traces] = classify_components_jeff(data,A,C,b,f,YrA,options);
ind_corr = (rval_space > space_thresh) & (sizeA >= options.min_size_thr) & (sizeA <= options.max_size_thr);

keep = ind_corr;
A_keep = A(:,keep);

Coor = plot_contours(A_keep,Cn,options);
sprintf("Number of neurons: %d", sum(ind_corr))

%%
% Event exceptionality:
fitness = compute_event_exceptionality(traces,options.N_samples_exc,options.robust_std);
ind_exc = (fitness < options.min_fitness);
%%
% Select components:
keep = ind_corr & ind_exc;

A_keep = A(:,keep);
C_keep = C(keep,:);
Km = size(C_keep,1); % total number of components

rVals = rval_space(keep);

Coor = plot_contours(A_keep,Cn,options);


%% view contour plots of selected and rejected components

plane_idx = 7;
fig_save_path = "E:\W2_archive\demas_2021\high_resolution\matlab\segmented\figures";
component_save_path = fullfile(fig_save_path, sprintf("plane_%d_accepted_rejected_neurons.png", plane_idx));

throw = ~keep;
figure;
set(gcf, 'Color', 'k'); % Set figure background to black
set(gcf, 'InvertHardcopy', 'off'); % Prevents MATLAB from inverting colors on save

ax1 = subplot(121); 
plot_contours(A(:,keep), Cn, options, 0, [], Coor, 1, find(keep)); 
set(ax1, 'Color', 'k', 'XColor', 'w', 'YColor', 'w'); % Make axis background black, text white
title('Selected components', 'FontWeight', 'bold', 'FontSize', 14, 'Color', 'w');

ax2 = subplot(122); 
plot_contours(A(:,throw), Cn, options, 0, [], Coor, 1, find(throw)); 
set(ax2, 'Color', 'k', 'XColor', 'w', 'YColor', 'w');
title('Rejected components', 'FontWeight', 'bold', 'FontSize', 14, 'Color', 'w');

linkaxes([ax1, ax2],'xy');

% saveas(gcf, component_save_path); % Save as PNG
% close(gcf);

%% inspect components
plot_components_GUI(data,A(:,keep),C(keep,:),b,f,Cn,options);

%% make movie
make_patch_video(A(:,keep),C(keep,:),b,f,data,Coor,options);

%% refine temporal components

A_keep = A(:,keep);
C_keep = C(keep,:);
[C2,f2,P2,S2,YrA2] = update_temporal_components(reshape(data,d,[]),A_keep,b,C_keep,f,P,options);

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

%% Load variables from file for inspection

segmented = "D:\W2_DATA\kbarber\2025-01-30\mk303\green\lbm_caiman_matlab\v4\results/segmented_plane_7.h5";

Cn = h5read(segmented, '/Cn');
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

% Helper function to plot the new sparse contours
plot_contours_Ac(Ac_keep, acx, acy);
%%



