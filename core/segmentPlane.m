function segmentPlane(data_path, save_path, varargin)
% SEGMENTPLANE Segment imaging data using CaImAn for motion-corrected data.
%
% This function applies the CaImAn algorithm to segment neurons from
% motion-corrected, pre-processed and ROI re-assembled MAxiMuM data.
% The processing is conducted for specified planes, and the results
% are saved to disk.
%
% MOTIONCORRECTPLANE Perform rigid and non-rigid motion correction on imaging data.
%
% Parameters
% ----------
% data_path : char
%     Path to the directory containing the files extracted via convertScanImageTiffToVolume.
% save_path : char
%     Path to the directory to save the motion vectors.
% dataset_name : string, optional
%     Group path within the hdf5 file that contains raw data.
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
% cnmf_options : dictionary, mapping
%     key:value pairs of all of your CNMF parameters.
%     See the example parameters in the LBM_demo_pipeline.
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
addParameter(p, 'dataset_name', "/mov", @(x) (ischar(x) || isstring(x)) && isValidGroupPath(x));
addOptional(p, 'debug_flag', 0, @(x) isnumeric(x) || islogical(x));
addParameter(p, 'overwrite', 1, @(x) isnumeric(x) || islogical(x));
addParameter(p, 'num_cores', 1, @(x) isnumeric(x));
addParameter(p, 'start_plane', 1, @(x) isnumeric(x) && x > 0);
addParameter(p, 'end_plane', 1, @(x) isnumeric(x) && x >= p.Results.start_plane);
parse(p, data_path, save_path, varargin{:});

data_path = p.Results.data_path;
save_path = p.Results.save_path;
dataset_name = p.Results.dataset_name;
debug_flag = p.Results.debug_flag;
overwrite = p.Results.overwrite;
num_cores = p.Results.num_cores;
start_plane = p.Results.start_plane;
end_plane = p.Results.end_plane;

% give access to CaImAn files
[currpath, ~, ~] = fileparts(fullfile(mfilename('fullpath'))); % path to this script
addpath(genpath(fullfile(currpath, '../packages/CaImAn_Utilities/CaImAn-MATLAB-master/CaImAn-MATLAB-master/')));
addpath(genpath(fullfile(currpath, './utils')));
addpath(genpath(fullfile(currpath, './io')));

if ~isfolder(data_path); error("Data path:\n %s\n ..does not exist", data_path); end
if debug_flag == 1; dir([data_path, '*.tif']); return; end

if isempty(save_path)
    warning("No save_path given. Saving data in data_path: %s\n", data_path);
    save_path = data_path;
end

fig_save_path = fullfile(save_path, "figures");
if ~isfolder(fig_save_path); mkdir(fig_save_path); end

files = dir([fullfile(data_path, '*.h*')]);
if isempty(files)
    error('No suitable data files found in: \n  %s', data_path);
end

log_file_name = sprintf("%s_segmentation", datestr(datetime('now'), 'yyyy_mm_dd_HH_MM_SS'));
log_full_path = fullfile(save_path, log_file_name);
fid = fopen(log_full_path, 'w');
if fid == -1
    error('Cannot create or open log file: %s', log_full_path);
else
    fprintf('Log file created: %s\n', log_full_path);
end
% closeCleanupObj = onCleanup(@() fclose(fid));

%% Pull metadata from attributes attached to this group
num_cores = max(num_cores, 23);
fprintf(fid, '%s : Beginning registration with %d cores...\n\n', datestr(datetime('now'), 'yyyy_mm_dd_HH_MM_SS'), num_cores); tall=tic;
t_all=tic;
first = true;
for plane_idx = start_plane:end_plane
    fprintf(fid, '%s : Beginning plane %d\n', datestr(datetime('now'), 'yyyy_mm_dd_HH_MM_SS'), plane_idx);
    z_str = sprintf('plane_%d', plane_idx);
    plane_name = sprintf("%s//motion_corrected_%s.h5", data_path, z_str);
    plane_name_save = sprintf("%s//segmented_%s.h5", save_path, z_str);
    if isfile(plane_name_save)
        fprintf(fid, '%s : %s already exists.\n', datestr(datetime('now'), 'yyyy_mm_dd_HH_MM_SS'), plane_name_save);
        if overwrite
            fprintf(fid, '%s : Parameter Overwrite=true. Deleting file: %s\n', datestr(datetime('now'), 'yyyy_mm_dd_HH_MM_SS'), plane_name_save);
            delete(plane_name_save)
        else
            fprintf(fid, '%s : Parameter Overwrite=true. Deleting file: %s\n', datestr(datetime('now'), 'yyyy_mm_dd_HH_MM_SS'), plane_name_save);
        end
    end

    %% Attach metadata to attributes for this plane
    h5_data = h5info(plane_name, dataset_name);
    metadata = struct();
    for k = 1:numel(h5_data.Attributes)
        attr_name = h5_data.Attributes(k).Name;
        attr_value = h5readatt(plane_name, sprintf("/%s",h5_data.Name), attr_name);
        metadata.(matlab.lang.makeValidName(attr_name)) = attr_value;
    end
    if first % log metadata once
        meta_str=formattedDisplayText(metadata);
        writelines(meta_str, log_full_path);
        first = false;
    end
    % if isempty(gcp('nocreate')) && num_cores > 1
    %     parpool(num_cores);
    % end
    if ~(metadata.num_planes >= end_plane)
        error("Not enough planes to process given user supplied argument: %d as end_plane when only %d planes exist in this dataset.", end_plane, metadata.num_planes);
    end

    %% Load in data
    data = h5read(plane_name, dataset_name);
    data = data - min(data(:));
    t_start = tic;
    pixel_resolution = metadata.pixel_resolution;
    frame_rate = metadata.frame_rate;
    [d1,d2,T] = size(data);
    d = d1*d2; % total number of samples
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
        'max_size', 2*round(tau), ...               % maximum size of ellipse axis (default: 8)
        'dist', dist, ...                           % expansion factor of ellipse (default: 3)
        'max_size_thr',mx,...                       % maximum size of each component in pixels (default: 300)
        'time_thresh',time_thresh,...
        'min_size_thr',mn,...                       % minimum size of each component in pixels (default: 9)
        'refine_flag',0,...
        'rolling_length',ceil(frame_rate*5),...
        'fr', frame_rate ...
        );
    fprintf(fid, "%s : Data loaded in. This process took: %0.2f seconds.\nBeginning CNMF.\n\n",datetime("now"), toc(t_start));
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

    %% Convert sparse A matrix to full 3D matrix
    t_sparse = tic;
    [Ac_keep,acx,acy,acm] = AtoAc(A_keep,tau,d1,d2);  % Ac_keep has dims. [2*tau+1,2*tau+1,K] where each element Ki is a 2D map centered on centroid of component acx(Ki),axy(Ki), and acm(Ki) = sum(sum(Ac_keep(:,:,Ki))
    fprintf(fid, '%s : Created sparse component matrix. Process took: %.2f seconds\nSaving data ...', datetime("now"), toc(t_sparse));

    %% Update temporal components
    P.p = 0;
    options.nb = options.gnb;

    t_update = tic;
    [C_keep,f,~,~,R_keep] = update_temporal_components(reshape(data,d,T),A_keep,b,C_keep,f,P,options);
    fprintf(fid, '%s : Temporal components updates. Process took: %.2f seconds\nDetrending from raw traces ...', datetime("now"), toc(t_update));

    %% Detrend
    % t_detrend = tic;
    % if size(A_keep,2) < 2 % Calculate "raw" traces in terms of delta F/F0
    %     [T_keep,F0] = detrend_df_f([A_keep,ones(d1*d2,1)],[b,ones(d1*d2,1)],[C_keep;ones(1,T)],[f;-min(min(min(data)))*ones(1,T)],[R_keep; ones(1,T)],options);
    % else
    %     [T_keep,F0] = detrend_df_f(A_keep,[b,ones(d1*d2,1)],C_keep,[f;-min(min(min(data)))*ones(1,T)],R_keep,options);
    % end
    % fprintf(fid, '%s : Traces detrended. Process took: %.2f seconds\nConverting to sparse matrix ...', datetime("now"), toc(t_detrend));


    % Convert ouputs to single to reduce memory consumption
    Cn = single(Cn);
    C_keep = single(C_keep);
    b = single(b);
    f = single(f);

    % Save data
    t_save = tic;
    fprintf(fid, "%s : Writing data.\n\n", datestr(datetime('now'), 'yyyy_mm_dd:HH:MM:SS'));
    % write_chunk_h5(plane_name_save, T_keep, 2000, '/T_keep');
    write_chunk_h5(plane_name_save, Ac_keep, 2000, '/Ac_keep');
    write_chunk_h5(plane_name_save, C_keep, 2000, '/C_keep');
    write_chunk_h5(plane_name_save, Km, 2000, '/Km');
    write_chunk_h5(plane_name_save, rVals, 2000, '/rVals');
    write_chunk_h5(plane_name_save, Cn, 2000, '/Cn');
    write_chunk_h5(plane_name_save, b, 2000, '/b');
    write_chunk_h5(plane_name_save, f, 2000, '/f');
    write_chunk_h5(plane_name_save, acx, 2000, '/acx');
    write_chunk_h5(plane_name_save, acy, 2000, '/acy');
    write_chunk_h5(plane_name_save, acm, 2000, '/acm');

    write_metadata_h5(metadata, plane_name_save, '/');
    fprintf(fid, "%s : Data saved. Elapsed time: %.2f seconds\n", datestr(datetime('now'), 'yyyy_mm_dd:HH:MM:SS'), toc(t_save)/60);

    % savefast(fullfile(save_path, ['caiman_output_plane_' num2str(plane_idx) '.mat']),'T_keep','Ac_keep','C_keep','Km','rVals','Ym','Cn','b','f','acx','acy','acm')
    fprintf(fid, '%s : Data saved. Process took: %.2f seconds\n', datetime("now"), toc(t_save));
    fprintf(fid, '%s : Plane complete. Process took: %.2f seconds\nBeginning next plane ...', datetime("now"), toc(t_start));
end

fprintf(fid, '%s : Routine complete. Total Completion time: %.2f hours\n', datetime("now"), toc(t_all)./3600);
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
