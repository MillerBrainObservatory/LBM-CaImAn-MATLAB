%%

order = [1 5:10 2 11:17 3 18:23 4 24:30];
order = fliplr(order);

%%

[currpath, ~, ~] = fileparts(fullfile(mfilename('fullpath'))); % path to this script
addpath(genpath(fullfile(currpath, '../packages/CaImAn_Utilities/CaImAn-MATLAB-master/CaImAn-MATLAB-master/')));
addpath(genpath(fullfile(currpath, './utils')));
addpath(genpath(fullfile(currpath, './io')));

parent_path = fullfile('C:\Users\RBO\Documents\data\high_res\');
raw_path = fullfile(parent_path, 'raw');

extracted = fullfile(parent_path, 'extracted');
corrected = fullfile(parent_path, 'corrected_gt');
segmented = fullfile(parent_path, 'segmented');
save_path = fullfile(parent_path, 'results');

% metadata = read_h5_metadata('C:\Users\RBO\Documents\data\high_res\segmented\segmented_plane_5.h5', '/mov');

% %%
% data_filename = fullfile(corrected, "motion_corrected_plane_1.h5");
% data = h5read(data_filename, '/mov');
% info = h5info(h5_segmented, '/');
% Ac_keep = h5read(h5_segmented, '/Ac_keep');
% Cn = h5read(h5_segmented, '/Cn');
% C_keep = h5read(h5_segmented, '/C_keep');
% Km = h5read(h5_segmented, '/Km');
% acm = h5read(h5_segmented, '/acm');
% acx = h5read(h5_segmented, '/acx');
% acy = h5read(h5_segmented, '/acy');
% f = h5read(h5_segmented, '/f');
% b = h5read(h5_segmented, '/b');
% rVals = h5read(h5_segmented, '/rVals');
%%

sizY = size(data);
Yr = reshape(data,[],sizY(end));
F_dark = min(Yr(:));

%%
[d1,d2,T] = size(data);     % dimensions of dataset
d = d1*d2;                  % total number of pixels
F_dark = inf;
F_dark = min(min(data(:)),F_dark);

FrameRate = 9.6;
tau = 7.5;
dist = 1.25;
merge_thresh = 0.8;
min_SNR = 1.25; 
space_thresh = 0.2;
time_thresh = 0.0;
sz = 0.1; 
mx = ceil(pi.*(1.33.*tau).^2);
mn = floor(pi.*(tau.*0.5).^2); % SHRINK IF FOOTPRINTS ARE TOO SMALL

srch_method = '';

p = 2;

% patch set up
sizY = size(data);
patch_size = [300,300];
overlap = [15,15];
patches = construct_patches(sizY(1:end-1),patch_size,overlap);
K = ceil(600/numel(patches));  % number of components (neurons) to be found

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
'decay_time',0.5,...
'size_thr', sz, ...
'search_method',srch_method,...
'min_size', round(tau), ...                 % minimum size of ellipse axis (default: 3)
'max_size', 2*round(tau), ...               % maximum size of ellipse axis (default: 8)
'dist', dist, ...                           % expansion factor of ellipse (default: 3)
'max_size_thr',mx,...                       % maximum size of each component in pixels (default: 300)
'time_thresh',time_thresh,...
'min_size_thr',mn,...                       % minimum size of each component in pixels (default: 9)
'refine_flag',0,...
'fr', FrameRate ...
);
%%
segmentPlane( ...
        corrected, ... % we used this to save extracted data
        save_path, ... % save registered data here
        'dataset_name', '/mov', ... % where we saved the last step in h5
        'debug_flag', 0, ...
        'overwrite', 1, ...
        'num_cores', 23, ...
        'start_plane', 1, ...
        'end_plane', 1  ...
        );

%%

disp('Beginning patched, volumetric CNMF...')
[A,b,C,f,S,P,~,YrA] = run_CNMF_patches(data,K,patches,tau,p,options);

disp('Beginning component classification...')
[rval_space,rval_time,max_pr,sizeA,keep0,~,traces] = classify_components_jeff(data,A,C,b,f,YrA,options);

Cn =  correlation_image(data); 

%%

rVal = 0.2;
ind_corr = (rval_space > rVal);% & (sizeA >= options.min_size_thr) & (sizeA <= options.max_size_thr);                     

% Event exceptionality:
fitness = compute_event_exceptionality(C+YrA,options.N_samples_exc,options.robust_std);
ind_exc = (fitness < options.min_fitness);

% Select components:
keep = ind_corr & ind_exc;

% Display kept and discarded components
A_keep = A(:,keep);
C_keep = C(keep,:);
K = size(C_keep,1); % total number of components

disp('Extracting raw fluorescence traces...');               

P.p = 0;
options.nb = options.gnb;
[C_keep,f,~,~,R_keep] = update_temporal_components_fast(data,A_keep,b,C_keep,f,P,options);

disp('Reordering components...')
[A_keep,C_keep,S,P] = order_ROIs(A_keep, C_keep, S, P); % order components

[T_keep,F0] = detrend_df_f( ...
    A_keep, ...
    [b,ones(d1*d2,1)], ...
    C_keep, ...
    [f;-double(F_dark)*ones(1,T)], ...
    R_keep, ...
    options ...
);

%%
AK = reshape(full(A_keep),d1,d2,[]);

% Correlation maps
AKm = mean(AK,3);
AKm(AKm>0) = 1;

h = figure;

imagesc(Cn)
colormap(gray)
axis image
set(gca,'yTick',[],'xTick',[])
hold on
AKC = zeros(size(AKm,1),size(AKm,2),3);
AKC(:,:,1) = AKm;

im = imagesc(AKC);
im.AlphaData = 0.3;

% save('caiman_output_plane_26.mat','A_keep','T_keep','Cn')

%% Correlation of Contours
Cn = correlation_image_max(data);  % background image for plotting
run_GUI = false;
if run_GUI
    Coor = plot_contours(A,Cn,options,1); close;
    GUIout = ROI_GUI(A,options,Cn,Coor,keep,ROIvars);   
    options = GUIout{2};
    keep = GUIout{3};    
end

%% Load new dataset 

data = matfile("D:\Jeffs LBM paper data\Fig5\Fig5_dataset_plane_30.mat")
h5_segmented = fullfile("C:\Users\RBO\Documents\data\high_res\results\segmented_plane_1.h5")

Ac_keep_n = h5read(h5_segmented, '/Ac_keep');
Cn_n = h5read(h5_segmented, '/Cn');
C_keep_n = h5read(h5_segmented, '/C_keep');
Km_n = h5read(h5_segmented, '/Km');
acm_n = h5read(h5_segmented, '/acm');
acx_n = h5read(h5_segmented, '/acx');
acy_n = h5read(h5_segmented, '/acy');
f_n = h5read(h5_segmented, '/f');
b_n = h5read(h5_segmented, '/b');
rVals_n = h5read(h5_segmented, '/rVals');

%%