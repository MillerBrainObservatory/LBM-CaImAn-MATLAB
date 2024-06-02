
%%

clc; clear;
parent_path = fullfile('C:\Users\RBO\Documents\data\high_res\');
raw_path = fullfile(parent_path, 'raw');
extracted = fullfile(parent_path, 'extracted');
corrected = fullfile(parent_path, 'corrected_gt');
segmented = fullfile(parent_path, 'segmented');
save_path = fullfile(parent_path, 'results');

% metadata = read_h5_metadata('C:\Users\RBO\Documents\data\high_res\segmented\segmented_plane_5.h5', '/mov');
data_filename = fullfile(corrected, "motion_corrected_plane_1.h5");
data = h5read(data_filename, '/mov');

%%

info = h5info(h5_segmented, '/');
Ac_keep = h5read(h5_segmented, '/Ac_keep');
Cn = h5read(h5_segmented, '/Cn');
C_keep = h5read(h5_segmented, '/C_keep');
Km = h5read(h5_segmented, '/Km');
acm = h5read(h5_segmented, '/acm');
acx = h5read(h5_segmented, '/acx');
acy = h5read(h5_segmented, '/acy');
f = h5read(h5_segmented, '/f');
b = h5read(h5_segmented, '/b');
rVals = h5read(h5_segmented, '/rVals');

%%

[d1,d2,T] = size(data);     % dimensions of dataset
d = d1*d2;                  % total number of pixels

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
'min_size', round(tau), ...           % minimum size of ellipse axis (default: 3)
'max_size', 2*round(tau), ...             % maximum size of ellipse axis (default: 8)
'dist', dist, ...                              % expansion factor of ellipse (default: 3)
'max_size_thr',mx,...                       % maximum size of each component in pixels (default: 300)
'time_thresh',time_thresh,...
'min_size_thr',mn,...                       % minimum size of each component in pixels (default: 9)
'refine_flag',0,...
'fr', FrameRate);

%%

disp('Beginning patched, volumetric CNMF...')
[A,b,C,f,S,P,~,YrA] = run_CNMF_patches(data,K,patches,tau,p,options);

plot(A(1:5, :)); axis image;

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
F_dark = inf;
F_dark = min(min(data(:)),F_dark);

try
    [A_keep,C_keep,S,P] = order_ROIs(A_keep, C_keep, S, P); % order components
catch
    disp('Reordering failed.')
end

[T_keep,F0] = detrend_df_f( ...
    A_keep, ...
    [b,ones(d1*d2,1)], ...
    C_keep, ...
    [f_full;-double(F_dark)*ones(1,T)], ...
    R_keep, ...
    options ...
);

[F_dff,F0] = detrend_df_f( ...
    A_keep, ...
    [b,ones(prod(FOV),1)], ...
    C_full, ...
    % [f_full;-double(F_dark)*ones(1,T)], ...
    R_full, ...
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

save('caiman_output_plane_26.mat','A_keep','T_keep','Cn')

%%
h5_corrected = sprintf('C:/Users/RBO/Documents/data/high_res/corrected_gt/motion_corrected_plane_%d.h5', 1);
h5_extracted = sprintf('C:/Users/RBO/Documents/data/high_res/extracted_gt/extracted_plane_%d.h5', 1);
data_corr = h5read(h5_corrected, '/mov');
data_extr = h5read(h5_extracted, '/Y_gt');

img_frame = data_corr(:,:,200);
[r, c] = find(img_frame == max(img_frame(:)));
[slicey, slicex] = get_central_indices(img_frame,r,c,200);
new = [data_corr(slicey, slicex, 2:402) data_extr(slicey, slicex, 2:402)];
planeToMovie(new, save_path, 10);
