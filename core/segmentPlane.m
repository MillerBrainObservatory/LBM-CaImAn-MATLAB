function segmentPlane(data_path, varargin)
% Segment imaging data using CaImAn CNMF.
%
% This function applies the CaImAn algorithm to segment neurons from
% motion-corrected, pre-processed and ROI re-assembled MAxiMuM data.
% The processing is conducted for specified planes, and the results
% are saved to disk.
%
% Parameters
% ----------
% data_path : char
%     Path to the directory containing the files assembled via convertScanImageTiffToVolume.
% save_path : char
%     Path to the directory to save the motion vectors.
% ds : string, optional
%     Group path within the hdf5 file that contains raw data.
% debug_flag : double, logical, optional
%     If set to 1, the function displays the files in the command window and does
%     not continue processing. Defaults to 0.
% do_figures : double, integer, positive
%     If true, correlation metrics will be saved to save_path/figures.
% overwrite : logical, optional
%     Whether to overwrite existing files (default is 0).
% num_cores : double, integer, positive
%     Number of cores to use for computation. The value is limited to a maximum
%     of 24 cores.
% start_plane : double, integer, positive
%     The starting plane index for processing.
% end_plane : double, integer, positive
%     The ending plane index for processing. Must be greater than or equal to
%     start_plane.
% options : struct
%     key:value pairs of all of your CNMF parameters.
%     See the example parameters in the LBM_demo_pipeline.
%
%
% Notes
% -----
%
% :code:`T_keep`
% :  neuronal time series [Km, T]. :code:`single`
%
% :code:`Ac_keep`
% :  neuronal footprints [2*tau+1, 2*tau+1, Km]. :code:`single`
%
% :code:`C_keep`
% :  denoised time series [Km, T]. :code:`single`
%
% :code:`Km`
% :  number of neurons found. :code:`single`
%
% :code:`Cn`
% :  correlation image [x, y]. :code:`single`
%
% :code:`b`
% :  background spatial components [x*y, 3]. :code:`single`
%
% :code:`f`
% :  background temporal components [3, T]. :code:`single`
%
% :code:`acx`
% :  centroid in x direction for each neuron [1, Km]. :code:`single`
%
% :code:`acy`
% :  centroid in y direction for each neuron [1, Km]. :code:`single`
%
% :code:`acm`
% :  sum of component pixels for each neuron [1, Km]. :code:`single`

p = inputParser;
addRequired(p, 'data_path', @(x) ischar(x) || isstring(x));
addParameter(p, 'save_path', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'ds', "/Y", @(x) (ischar(x) || isstring(x)));
addParameter(p, 'debug_flag', 0, @(x) isscalar(x) || islogical(x));
addParameter(p, 'overwrite', 0, @(x) isnumeric(x) || islogical(x));
addParameter(p, 'num_cores', 1, @(x) isnumeric(x));
addParameter(p, 'start_plane', 1, @(x) isnumeric(x));
addParameter(p, 'end_plane', 1, @(x) isnumeric(x) && x >= p.Results.start_plane);
addParameter(p, 'do_figures', 1, @(x) isnumeric(x) || islogical(x));
addParameter(p, 'patches', []);
addParameter(p, 'K', 1, @(x) isnumeric(x));
addParameter(p, 'options', {}, @(x) isstruct(x));
parse(p, data_path, varargin{:});

data_path = p.Results.data_path;
save_path = p.Results.save_path;
ds = p.Results.ds;
debug_flag = p.Results.debug_flag;
overwrite = p.Results.overwrite;
num_cores = p.Results.num_cores;
start_plane = p.Results.start_plane;
end_plane = p.Results.end_plane;
do_figures = p.Results.do_figures;
patches = p.Results.patches;
K = p.Results.K;
options = p.Results.options;

data_path = convertStringsToChars(data_path);
save_path = convertStringsToChars(save_path);

% give access to CaImAn files
[currpath, ~, ~] = fileparts(fullfile(mfilename('fullpath'))); % path to this script
addpath(genpath(fullfile(currpath, '../packages/CaImAn_Utilities/CaImAn-MATLAB-master/CaImAn-MATLAB-master/')));
addpath(genpath(fullfile(currpath, './utils')));
addpath(genpath(fullfile(currpath, './internal')));

if ~isfolder(data_path); error("Data path:\n %s\n ..does not exist, but should contain motion corrected HDF5 files.", data_path); end

if debug_flag == 1; dir([data_path '/' '*.h*']); return; end

if isempty(save_path)
    save_path = fullfile(data_path, '../', 'segmented');
    if ~isfolder(save_path); mkdir(save_path);
        warning('Creating save path since one was not provided, located: %s', save_path);
    end
elseif ~isfolder(save_path)
    mkdir(save_path);
end

fig_save_path = fullfile(save_path, "segmentation_figs");
if ~isfolder(fig_save_path); mkdir(fig_save_path); end

files = dir([fullfile(data_path, '*.h*')]);
if isempty(files)
    error('No suitable data files found in: \n  %s', data_path);
end

log_file_name = sprintf("%s_segmentation.log", datestr(datetime('now'), 'yyyy_mm_dd_HH_MM_SS'));
log_full_path = fullfile(save_path, log_file_name);
fid = fopen(log_full_path, 'w');
if fid == -1
    error('Cannot create or open log file: %s', log_full_path);
else
    fprintf('Log file created: %s\n', log_full_path);
end

num_cores = max(num_cores, 23);
log_message(fid, 'Beginning registration with %d cores...\n',num_cores);
t_all=tic;
% try
for plane_idx = start_plane:end_plane
    log_message(fid, 'Beginning plane: %d\n',plane_idx);
    p_str = sprintf('plane_%d', plane_idx);
    plane_name = sprintf("%s//motion_corrected_%s.h5", data_path, p_str);
    plane_name_save = sprintf("%s//segmented_%s.h5", save_path, p_str);
    
    if isfile(plane_name_save)
        if overwrite
            log_message(fid, 'File: %s esists. Overwrite set to true. Deleting ...\n',plane_name_save);
            delete(plane_name_save)
        else
            log_message(fid, 'File: %s esists. Overwrite set to false. Skipping plane %d ...\n',plane_name_save, plane_idx);
            continue
        end
    end
    
    %% Attach metadata to attributes for this plane
    metadata = read_h5_metadata(plane_name, '/');
    if isempty(fieldnames(metadata)); error("No metadata found for this filepath."); end
    log_struct(fid,metadata,'metadata', log_full_path);
    
    %% Load in data
    data = h5read(plane_name, ds);
    Ym = h5read(plane_name, "/Ym");
    if ~isa(data, 'single'); data=single(data); end
    metadata.movie_path = plane_name;
    
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
    
    if isempty(patches)
        log_message(fid, "Creating default patches.\n")

        % patch set up; basing it on the ~600 um strips of the 2pRAM, +50 um overlap between patches
        sizY = size(data);
    
        patch_size = round(650/pixel_resolution).*[1,1];
        overlap = [1,1].*ceil(50./pixel_resolution);
        patches = construct_patches(sizY(1:end-1),patch_size,overlap);
    end

    if isempty(K)
        % number of components based on assumption of 9.2e4 neurons/mm^3
        K = ceil(9.2e4.*20e-9.*(pixel_resolution.*patch_size(1)).^2); 
    end

    % Set caiman parameters
    if isempty(options)

        % Set caiman parameters
        log_message(fid, "Setting default CNMF parameters.\n")
    
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
        'dist', dist, ...                           % expansion factor of ellipse (default: 3)
        'max_size_thr',mx,...                       % maximum size of each component in pixels (default: 300)
        'time_thresh',time_thresh,...
        'min_size_thr',mn,...                       % minimum size of each component in pixels (default: 9)
        'refine_flag',0,...
        'rolling_length',ceil(frame_rate*5),...
        'fr', frame_rate);                                      % order of autoregressive system (p = 0 no dynamics, p=1 just decay, p = 2, both rise and decay)
    else
        % Validate that options.nb is 1, cnmf will fail otherwise
        if options.nb ~= 1
            disp(options.nb)
            error('The value of options.nb must be 1.');
        end
    end
   
    poolobj = gcp('nocreate'); % create a parallel pool
    if isempty(poolobj)
        disp('Starting the parallel pool...')
        poolobj = parpool('local',num_cores);
        tmpDir = tempname();
        mkdir(tmpDir);
        poolobj.Cluster.JobStorageLocation = tmpDir;
    else
        numworkers = poolobj.NumWorkers;
        disp(['Continuing with existing pool of ' num2str(numworkers) '.'])
    end
    
    log_message(fid, "Data loaded in. This process took: %0.2f seconds... Beginning CNMF.\n\n", toc(t_start));
    log_message(fid, "--------------------------------------------------\n");
    log_struct(fid,options,'CNMF Parameters', log_full_path);
    log_message(fid, "--------------------------------------------------\n");
    
    t_cnmf = tic;
    [A,b,C,f,~,P,~,YrA] = run_CNMF_patches(data,K,patches,tau,p,options);
    
    log_message(fid, 'Initialized CNMF patches complete.  Process took: %.2f seconds\nClassifying components ...\n',toc(t_cnmf));
    log_message(fid, "--------------------------------------------------\n");
    
    t_class = tic;
    [rval_space,~,~,sizeA,~,~,traces] = classify_components_jeff(data,A,C,b,f,YrA,options);
    log_message(fid, 'Classification complete. Process took: %.2f seconds\nRunning spatial/temporal acceptance tests...\n', toc(t_class));
    log_message(fid, "--------------------------------------------------\n");
    
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
    Km = size(C_keep,1); % total number of components
    
    rVals = rval_space(keep);
    log_message(fid, 'Spatial acceptance and event exceptionality tests complete. Process took: %.2f seconds\nUpdating tamporal components...', toc(t_test));
    log_message(fid, "--------------------------------------------------\n");

    component_save_path = fullfile(fig_save_path, sprintf("plane_%d_accepted_rejected_neurons.png", plane_idx));
    component_save_path2 = fullfile(fig_save_path, sprintf("plane_%d_accepted_rejected_neurons_p.png", plane_idx));
    
    Coor = plot_contours(A,Cn,options);
    throw = ~keep;
    figure;
    set(gcf, 'Color', 'k'); % Set figure background to black
    set(gcf, 'InvertHardcopy', 'off'); % Prevents MATLAB from inverting colors on save
    
    ax1 = subplot(121); 
    plot_contours(A(:,keep), Cn, options, 0, [], Coor, 1, find(keep)); 
    set(ax1, 'Color', 'k', 'XColor', 'w', 'YColor', 'w'); % Make axis background black, text white
    title(sprintf('Accepted Components: count=%d', sum(keep)), 'FontWeight', 'bold', 'FontSize', 14, 'Color', 'w');
    
    ax2 = subplot(122); 
    plot_contours(A(:,throw), Cn, options, 0, [], Coor, 1, find(throw)); 
    set(ax2, 'Color', 'k', 'XColor', 'w', 'YColor', 'w');
    title(sprintf('Rejected Components: count=%d', sum(throw)), 'FontWeight', 'bold', 'FontSize', 14, 'Color', 'w');
    
    linkaxes([ax1, ax2],'xy');
    
    saveas(gcf, component_save_path); % Save as PNG
    print(gcf, component_save_path2, '-dpng', '-r600'); 
    close(gcf);
    
    %% Update temporal components
    P.p = 0;
    options.nb = options.gnb;
    
    t_update = tic;
    [C_keep,f,~,~,R_keep] = update_temporal_components(reshape(data,d,T),A_keep,b,C_keep,f,P,options);
    log_message(fid, 'Temporal components updates. Process took: %.2f seconds.\nDetrending from raw traces ...',toc(t_update));
    log_message(fid, "--------------------------------------------------\n");
    options.nb = 1;
    
    %% Detrend
    t_detrend = tic;
    % Calculate "raw" traces in terms of delta F/F0
    if size(A_keep,2) < 2
        log_message(fid, '  Detrending multiple components.');
        [T_keep,~] = detrend_df_f([A_keep,ones(d1*d2,1)],[b,ones(d1*d2,1)],[C_keep;ones(1,T)],[f;-min(min(min(data)))*ones(1,T)],[R_keep; ones(1,T)],options);
        log_message(fid, '  Detrending Complete ...');
    else % total number of pixels
        % handle min(data) = 0
        log_message(fid, '  Detrending A_keep of >2 components.');
        F_dark = min(min(data(:)),eps);
        log_message(fid, '  F_Dark complete.');
        if F_dark == 0
            log_message(fid, '  F_Dark == 0.');
            F_dark = eps;
        end
        log_message(fid, ' Detrending components ...');
        [T_keep,~] = detrend_df_f( ...
            A_keep, ...
            [b,ones(d1*d2,1)], ...
            C_keep, ...
            [f;F_dark*ones(1,T)], ...
            R_keep, ...
            options ...
            );
    end
    
    log_message(fid, 'Traces detrended. Process took: %.2f seconds.\nConverting to sparse matrix ...',toc(t_detrend));
    log_message(fid, "--------------------------------------------------\n");
    
    %% Convert sparse A matrix to full 3D matrix
    t_sparse = tic;
    [Ac_keep,acx,acy,acm] = AtoAc(A_keep,tau,d1,d2);  % Ac_keep has dims. [2*tau+1,2*tau+1,K] where each element Ki is a 2D map centered on centroid of component acx(Ki),axy(Ki), and acm(Ki) = sum(sum(Ac_keep(:,:,Ki))
    log_message(fid, 'Created sparse component matrix. Process took: %.2f seconds.\nSaving data ...',toc(t_sparse));
    log_message(fid, "--------------------------------------------------\n");
    
    % Convert ouputs to single to reduce memory consumption
    Cn = single(Cn);
    C_keep = single(C_keep);
    b = single(b);
    f = single(f);
    
    % Save data
    t_save = tic;
    log_message(fid, "Writing data to disk to:\n\n %s\n", plane_name_save);
    
    % write frames. Filename, dataset, dataset_name, overwrite, append
    try
        h5create(plane_name_save,"/T_keep",size(T_keep));
    catch
        log_message(fid, "Error writing to hdf5, likely file already exists. Deleting file to attempt another save.");
        delete(plane_name_save)
        h5create(plane_name_save,"/T_keep",size(T_keep));
    end
    h5create(plane_name_save,"/Ac_keep",size(Ac_keep));
    h5create(plane_name_save,"/C_keep",size(C_keep));
    h5create(plane_name_save,"/Km",size(Km));
    h5create(plane_name_save,"/Ym",size(Ym));
    
    h5create(plane_name_save,"/rVals",size(rVals));
    h5create(plane_name_save,"/Cn",size(Cn));
    h5create(plane_name_save,"/b",size(b));
    
    h5create(plane_name_save,"/f",size(f));
    h5create(plane_name_save,"/acx",size(acx));
    h5create(plane_name_save,"/acy",size(acy));
    h5create(plane_name_save,"/acm",size(acm));
    
    h5write(plane_name_save,"/T_keep",T_keep);
    h5write(plane_name_save,"/Ac_keep",Ac_keep);
    h5write(plane_name_save,"/C_keep",C_keep);
    h5write(plane_name_save,"/Km",Km);
    h5write(plane_name_save,"/Km",Km);

    h5write(plane_name_save,"/rVals",rVals);
    h5write(plane_name_save,"/Cn",Cn);
    h5write(plane_name_save,"/b",b);
    
    h5write(plane_name_save,"/f",f);
    h5write(plane_name_save,"/acx",acx);
    h5write(plane_name_save,"/acy",acy);
    h5write(plane_name_save,"/acm",acm);
    
    write_metadata_h5(metadata, plane_name_save, '/');

    num_traces = min(size(T_keep, 1), 500); % Get the minimum of 500 or available traces
    sp = fullfile(save_path, sprintf("top_%d_traces.png", num_traces));
    plot_traces(T_keep, num_traces, sp);

    log_message(fid, "Data saved. Elapsed time: %.2f seconds.\n",toc(t_save));
    clearvars -except poolobj tmpDir numworkers *path fid num_cores t_all files ds start_plane end_plane options plane_idx patches K options
end
fprintf(fid, 'Routine complete for %d planes. Total Completion time: %.2f hours.\n',((end_plane-start_plane)+1),toc(t_all)./3600);
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
sd = size(A_keep, 2);
parfor ijk = 1:sd
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
