segmentation_path = fullfile("C:\Users\RBO\caiman_data\mk717\1um_72hz\segmented\");
segmentation_file = fullfile(segmentation_path, 'segmented_plane_14.h5');
isfile(segmentation_file)
% Specify your HDF5 file name
filename = segmentation_file;
% Get info about the HDF5 file
info = h5info(filename);
% Preallocate a cell array to hold your data
data = struct();
% Loop through each group
for i = 1:length(info.Datasets)
    group_name = info.Datasets(i).Name;
    group_value = info.Datasets(i).Datatype;
    data.(group_name) = h5read(filename, sprintf("/%s",group_name)); % Create a struct for the group
end

%%
m = read_h5_metadata(segmentation_file, '/');
%% inspect components
Y = h5read(m.movie_path, '/Y');
[d1,d2,T] = size(Y);
d = d1*d2; % total number of samples

pixel_resolution=m.pixel_resolution;
tau = ceil(7.5./pixel_resolution);

% expansion factor for the ellipse
if pixel_resolution>3
    dist = 1.5;
else
    dist = 1.25;
end

% CaImAn settings
merge_thresh = 0.8; % threshold for merging
min_SNR = 1.4; % liberal threshold, can tighten up in additional post-processing
space_thresh = 0.2; % threhsold for selection of neurons by space
time_thresh = 0.0;
sz = 0.1; % IF FOOTPRINTS ARE TOO SMALL, CONSIDER sz = 0.1
mx = ceil(pi.*(1.33.*tau).^2);
mn = floor(pi.*(tau.*0.5).^2); % SHRINK IF FOOTPRINTS ARE TOO SMALL
sizY = size(Y);
% patch_size = [100,100];
% overlap = [10,10];
% patches = construct_patches(sizY(1:end-1),patch_size,overlap);
% K = ceil(9.2e4.*20e-9.*(pixel_resolution.*patch_size(1)).^2);
patch_size = [40,40];                   % size of each patch along each dimension (optional, default: [32,32])
overlap = [8,8];                        % amount of overlap in each dimension (optional, default: [4,4])

patches = construct_patches(sizY(1:end-1),patch_size,overlap);
K = 7;                                            % number of components to be found
tau = 8;                                          % std of gaussian kernel (half size of neuron)
p = 2;

%%
frame_rate = 7.7;
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
    'min_size', round(tau), ...                 % minimum size of ellipse axis (default: 3)
    'max_size', 2*round(tau), ...               % maximum size of ellipse axis (default: 8)
    'dist', dist, ...                           % expansion factor of ellipse (default: 3)
    'max_size_thr',mx,...                       % maximum size of each component in pixels (default: 300)
    'time_thresh',time_thresh,...
    'min_size_thr',mn,...                       % minimum size of each component in pixels (default: 9)
    'refine_flag',0,...
    'rolling_length',ceil(frame_rate*5),...
    'fr', frame_rate ...
    );

%
%%

plot_components_GUI(Y,data.Ac_keep,data.C_keep,data.b,data.f,data.Cn, options);

