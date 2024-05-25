function segmentPlane(data_path, save_path, varargin)
% SEGMENTPLANE Segment imaging data using CaImAn for motion-corrected data.
%
% This function applies the CaImAn algorithm to segment neurons from
% motion-corrected, pre-processed and ROI re-assembled MAxiMuM data.
% The processing is conducted for specified planes, and the results
% are saved to disk.
%
% Parameters
% ----------
% data_path : char
%     Path to the directory containing the files extracted via convertScanImageTiffToVolume.
% save_path : char
%     Path to the directory to save the motion vectors.
% data_input_group : string, optional
%     Group path within the hdf5 file that contains raw data.
%     Default is 'registration'.
% data_output_group : string, optional
%     Group path within the hdf5 file to save the registered data.
%     Default is 'registration'.
% debug_flag : double, logical, optional
%     If set to 1, the function displays the files in the command window and does
%     not continue processing. Defaults to 0.
% overwrite : logical, optional
%     Whether to overwrite existing files (default is 1).
% num_cores : double, integer, positive
%     Number of cores to use for computation. The value is limited to a maximum
%     of 24 cores.
% start_plane : double, integer, positive
%     The starting plane index for processing.
% end_plane : double, integer, positive
%     The ending plane index for processing. Must be greater than or equal to
%     start_plane.
%
% Returns
% -------
% None
%
% Notes
% -----
% - Outputs are saved to disk, including:
% - T_keep: neuronal time series [Km, T] (single)
% - Ac_keep: neuronal footprints [2*tau+1, 2*tau+1, Km] (single)
% - C_keep: denoised time series [Km, T] (single)
% - Km: number of neurons found (single)
% - Cn: correlation image [x, y] (single)
% - b: background spatial components [x*y, 3] (single)
% - f: background temporal components [3, T] (single)
% - acx: centroid in x direction for each neuron [1, Km] (single)
% - acy: centroid in y direction for each neuron [1, Km] (single)
% - acm: sum of component pixels for each neuron [1, Km] (single)
% - The function handles large datasets by processing each plane serially.
% - The segmentation settings are based on the assumption of 9.2e4 neurons/mm^3
%   density in the imaged volume.
%
% See also ADDPATH, FULLFILE, DIR, LOAD, SAVEFAST

p = inputParser;
addRequired(p, 'data_path', @ischar);
addRequired(p, 'save_path', @ischar);
addParameter(p, 'data_input_group', "/extraction", @(x) (ischar(x) || isstring(x)) && isValidGroupPath(x));
addParameter(p, 'data_output_group', "/segmentation", @(x) (ischar(x) || isstring(x)) && isValidGroupPath(x));
addOptional(p, 'debug_flag', 0, @(x) isnumeric(x) || islogical(x));
addParameter(p, 'overwrite', 1, @(x) isnumeric(x) || islogical(x));
addParameter(p, 'num_cores', 1, @(x) isnumeric(x) && x > 0 && x <= 24);
addParameter(p, 'start_plane', 1, @(x) isnumeric(x) && x > 0);
addParameter(p, 'end_plane', 1, @(x) isnumeric(x) && x >= p.Results.start_plane);
parse(p, data_path, save_path, varargin{:});

data_path = p.Results.data_path;
save_path = p.Results.save_path;
data_input_group = p.Results.data_input_group;
data_output_group = p.Results.data_output_group;

debug_flag = p.Results.debug_flag;
num_cores = p.Results.num_cores;
start_plane = p.Results.start_plane;
end_plane = p.Results.end_plane;
overwrite = p.Results.overwrite;

% give access to CaImAn files
[currpath, ~, ~] = fileparts(fullfile(mfilename('fullpath'))); % path to this script
addpath(genpath(fullfile(currpath, '../packages/CaImAn_Utilities/CaImAn-MATLAB-master/CaImAn-MATLAB-master/')));
addpath(genpath(fullfile(currpath, './utils')));
addpath(genpath(fullfile(currpath, './io')));

if isempty(save_path)
    save_path = data_path;
end

data_path = fullfile(data_path);
if ~isfolder(data_path)
    error("Filepath %s does not exist", data_path);
end

if debug_flag == 1
    dir([data_path, '*.tif']);
    return;
end

if ~isfolder(save_path)
    fprintf('Given savepath %s does not exist. Creating this directory...\n', save_path);
    mkdir(save_path);
end

fig_save_path = fullfile(save_path, 'figures');
if ~isfolder(fig_save_path)
    mkdir(fig_save_path);
end

files = dir(fullfile(data_path, '*.h5'));
if isempty(files)
    error('No suitable h5 files found in: \n  %s', data_path);
end

h5_fullfile = fullfile(files(1).folder, files(1).name);
h5_savefile = fullfile(save_path, 'segmentation.h5');

%% TODO!! Fix this
metadata = read_h5_metadata(h5_fullfile, '/extraction');

num_planes_to_process = end_plane-start_plane+1;
assert(num_planes_to_process <= metadata.num_planes);

if start_plane == 0 || size(start_plane, 1) == 0
    start_plane = 1;
end
if ~(metadata.num_planes >= end_plane)
    error("Not enough planes to process given user supplied argument: %d as end_plane when only %d planes exist in this dataset.", end_plane, metadata.num_planes);
end

if num_cores == 0 || size(num_cores,1) == 0
    num_cores = 16;
end

log_file_name = sprintf("%s_segmentation", datestr(datetime("now"), 'dd_mmm_yyyy_HH_MM_SS'));
log_full_path = fullfile(data_path, log_file_name);
fid = fopen(log_full_path, 'w');

fprintf(fid, "Beginning processing with %d cores on %d planes: %d - %d\n...", num_planes_to_process, start_plane, end_plane);

dataset_paths = {'T_keep','Ac_keep','C_keep','Km','rVals','Ym','Cn','b','f','acx','acy','acm'};
plane_map = dictionary; tic;
for plane_idx = start_plane:end_plane
    fprintf(fid,'%s : BEGINNING PLANE %u\n', datetime("now"),plane_idx);

    pst = sprintf('plane_%d', plane_idx);
    input_path = sprintf('%s/%s', data_input_group, pst);
    output_path = sprintf('%s/%s', data_output_group, pst);

    fprintf(fid, '%s : Reading in data / metadata...\n',datetime("now"));
    
    poolobj = gcp('nocreate'); % create a parallel pool
    if isempty(poolobj)
        poolobj = parpool('local',num_cores);
        tmpDir = tempname();
        mkdir(tmpDir);
        poolobj.Cluster.JobStorageLocation = tmpDir;
    else
        numworkers = poolobj.NumWorkers;
        disp(['Continuing with existing pool of ' num2str(numworkers) '.'])
    end

    %% CaImAn segmentation
    td_start = tic;

    data = h5read(h5_fullfile, sprintf("%s/Y", input_path));
    data = data - min(data(:));

    pixel_resolution = metadata.pixel_resolution;
    volume_rate = metadata.frame_rate;
    [d1,d2,T] = size(data);
    d = d1*d2; % total number of samples

    t0 = toc(td_start);
    fprintf(fid, "%s : Data loaded in. This process took: %0.1f seconds",datetime("now"), toc(td_start));

    FrameRate = volume_rate;
    tau = ceil(7.5./pixel_resolution);

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
    p = 2; % order of dynamics

    % patch set up; basing it on the ~600 um strips of the 2pRAM, +50 um overlap between patches
    sizY = size(data);
    patch_size = round(650/pixel_resolution).*[1,1];
    overlap = [1,1].*ceil(50./pixel_resolution);
    patches = construct_patches(sizY(1:end-1),patch_size,overlap);

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
        'max_size', 2*round(tau), ...              % maximum size of ellipse axis (default: 8)
        'dist', dist, ...                           % expansion factor of ellipse (default: 3)
        'max_size_thr',mx,...                       % maximum size of each component in pixels (default: 300)
        'time_thresh',time_thresh,...
        'min_size_thr',mn,...                       % minimum size of each component in pixels (default: 9)
        'refine_flag',0,...
        'rolling_length',ceil(FrameRate*5),...
        'fr', FrameRate ...
        );

    % Run patched caiman
    disp('Beginning patched, volumetric CNMF...')
    t_cnmf = tic;

    %% F.O. 05.16.24: BREAKING - remove parallel eval on memmapped file
    [A,b,C,f,S,P,~,YrA] = run_CNMF_patches(data,K,patches,tau,p,options);
    fprintf(fid, '%s : Initialized CNMF patches complete.  Process took: %.2f seconds\Classifying components ...',datetime("now"), toc(t_cnmf));
    
    t_class = tic;
    [rval_space,rval_time,max_pr,sizeA,keep0,~,traces] = classify_components_jeff(data,A,C,b,f,YrA,options);
    fprintf(fid, '%s : Classification complete. Process took: %.2f seconds\Running spatial/temporal acceptance tests ... to dF/F ...', datetime("now"), toc(t_class));

    t_test = tic;
    Cn =  correlation_image(data);
    % Spatial acceptance test:
    ind_corr = (rval_space > space_thresh) & (sizeA >= options.min_size_thr) & (sizeA <= options.max_size_thr);

    % Event exceptionality:
    fitness = compute_event_exceptionality(traces,options.N_samples_exc,options.robust_std);
    ind_exc = (fitness < options.min_fitness);

    % Select components:
    keep = ind_corr & ind_exc;

    A_keep = A(:,keep);
    C_keep = C(keep,:);
    Km = size(C_keep,1);  % total number of components
    rVals = rval_space(keep);
    fprintf(fid, '%s : First CNMF iteration complete. Process took: %.2f seconds\nUpdating tamporal components... ...', datetime("now"), toc(t_test));

    P.p = 0;
    options.nb = options.gnb;

    t_update = tic;
    [C_keep,f,~,~,R_keep] = update_temporal_components(reshape(data,d,T),A_keep,b,C_keep,f,P,options);
    fprintf(fid, '%s : Temporal components updates. Process took: %.2f seconds\nDetrending from raw traces ...', datetime("now"), toc(t_update));

    t_detrend = tic;
    if size(A_keep,2) < 2 % Calculate "raw" traces in terms of delta F/F0
        [T_keep,F0] = detrend_df_f([A_keep,ones(d1*d2,1)],[b,ones(d1*d2,1)],[C_keep;ones(1,T)],[f;-min(min(min(data)))*ones(1,T)],[R_keep; ones(1,T)],options);
    else
        [T_keep,F0] = detrend_df_f(A_keep,[b,ones(d1*d2,1)],C_keep,[f;-min(min(min(data)))*ones(1,T)],R_keep,options);
    end
    fprintf(fid, '%s : Traces detrended. Process took: %.2f seconds\nConverting to sparse matrix ...', datetime("now"), toc(t_detrend));
    
    % Convert sparse A matrix to full 3D matrix
    t_ac = tic;
    [Ac_keep,acx,acy,acm] = AtoAc(A_keep,tau,d1,d2);  % Ac_keep has dims. [2*tau+1,2*tau+1,K] where each element Ki is a 2D map centered on centroid of component acx(Ki),axy(Ki), and acm(Ki) = sum(sum(Ac_keep(:,:,Ki))
    fprintf(fid, '%s : Created sparse component matrix. Process took: %.2f seconds\nSaving data ...', datetime("now"), toc(t_ac));

    % Convert ouputs to single to reduce memory consumption
    Ym = single(mean(data,3));
    Cn = single(Cn);
    C_keep = single(C_keep);
    b = single(b);
    f = single(f);

    % Save data
    t_save = tic;

    write_dataset(h5_savefile, sprintf('%s/T_keep', output_path), T_keep, fid);
    write_dataset(h5_savefile, sprintf('%s/Ac_keep', output_path), Ac_keep, fid);
    write_dataset(h5_savefile, sprintf('%s/C_keep', output_path), C_keep, fid);
    write_dataset(h5_savefile, sprintf('%s/Km', output_path), Km, fid);
    write_dataset(h5_savefile, sprintf('%s/rVals', output_path), rVals, fid);
    write_dataset(h5_savefile, sprintf('%s/Ym', output_path), Ym, fid);
    write_dataset(h5_savefile, sprintf('%s/Cn', output_path), Cn, fid);
    write_dataset(h5_savefile, sprintf('%s/b', output_path), b, fid);
    write_dataset(h5_savefile, sprintf('%s/f', output_path), f, fid);
    write_dataset(h5_savefile, sprintf('%s/acx', output_path), acx, fid);
    write_dataset(h5_savefile, sprintf('%s/acy', output_path), acy, fid);
    write_dataset(h5_savefile, sprintf('%s/acm', output_path), acm, fid);
    % savefast(fullfile(save_path, ['caiman_output_plane_' num2str(plane_idx) '.mat']),'T_keep','Ac_keep','C_keep','Km','rVals','Ym','Cn','b','f','acx','acy','acm')
    fprintf(fid, '%s : Data saved. Process took: %.2f seconds\n', datetime("now"), toc(t_save));
    fprintf(fid, '%s : Plane complete. Process took: %.2f seconds\nBeginning next plane ...', datetime("now"), toc(td_start));
end

fprintf(fid, '%s : Routine complete. Total Completion time: %.2f hours\n', datetime("now"), toc(t_ac)./3600);
end

function [Ac_keep,acx,acy,acm] = AtoAc(A_keep,tau,d1,d2)
%% Convert the sparse matrix A_keep to a full 3D matrix that can be saved to hdf5
tau = tau(1);
x = 1:d2;
y = 1:d1;
[X,Y] = meshgrid(x,y);
Ac_keep = zeros(4*tau+1,4*tau+1,size(A_keep,2),'single');

acx = zeros(1,size(A_keep,2));
acy = acx;
acm = acx;

parfor ijk = 1:size(A_keep,2)

    AOI = reshape(single(full(A_keep(:,ijk))),d1,d2);
    cx = round(trapz(trapz(X.*AOI))./trapz(trapz(AOI)));
    cy = round(trapz(trapz(Y.*AOI))./trapz(trapz(AOI)));

    acx(ijk) = cx;
    acy(ijk) = cy;
    acm(ijk) = sum(AOI(:));

    sx = max([cx-2*tau 1]); % handle cases where neuron is closer than 3*tau pixels to edge of FOV
    sy = max([cy-2*tau 1]);
    ex = min([cx+2*tau d2]);
    ey = min([cy+2*tau d1]);

    AOIc = nan(4*tau+1,4*tau+1);
    AOIc(1:(ey-sy+1),1:(ex-sx+1)) = AOI(sy:ey,sx:ex);
    Ac_keep(:,:,ijk) = single(AOIc);
end
end

function write_dataset(filename, location, data, fid)
%% TODO: test / clean / expand this
try
    h5create(filename, location, size(data), 'Datatype', 'single')
catch ME
    if strcmp(ME.identifier, 'MATLAB:imagesci:h5create:datasetAlreadyExists')
        fprintf(fid, "%s : Skipping dataset creation.\n", location);
    else
        rethrow(ME);
    end
end
try
    h5write(filename, location, data);
    fprintf(fid, "%s : Dataset written\n", location);
catch ME
    if strcmp(ME.identifier, 'MATLAB:imagesci:h5write:fullDatasetDataMismatch')
        new_loc = [location '_1'];
        fprintf(fid, "%s : Corrupt data, size mismatch, attempting to create new dataset at %s.\n", location, new_loc);
        h5create(filename, new_loc, size(data), 'Datatype', 'single');
        h5write(filename, new_loc, data);
    else
        rethrow(ME);
    end
end
end

