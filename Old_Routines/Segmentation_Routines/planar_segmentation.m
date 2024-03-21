%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% planar_segmentation.m
%
% Jeff 04/16/2019
%
% Load in mouse data, motion correct, extract traces and neurons
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear; 
close all;
clc

addpath(genpath('/vmd/jeff_demas/PROCESSING_SCRIPTS/Tiff_Processing/'))

%% Load image stack

% path = '/raid0/test_folder/';
% path = '/vmd/jeff_demas/MAxiMuM_data/20200629/MF850/MF850_left_hemisphere_FOV_420mW_150_600um_depth_9min_dual_stimuli/';
% path = '/vmd/jeff_demas/MAxiMuM_data/20200702/MF850/MF850_right_hemisphere_FOV_440mW_150_600um_depth_9min_dual_stimuli/';
% path = '/vmd/jeff_demas/MAxiMuM_data/20200702/MH89/MH89_left_hemisphere_FOV_440mW_100_550um_depth_9min_dual_stimuli/';
path = '/v-data2/jeff_demas/MAxiMuM_data/20200904/MH182_right_hemisphere_FOV_415mW_150_600um_depth_9min_dual_stimuli/';

if ~strcmp(path(end),'/')
    path = [path '/'];
end

files = dir([path, '*.mat']);

numfiles = size(files,1);

save_path = [path 'output/'];

if ~logical(exist(save_path,'dir'))
    mkdir(save_path)
end

clck = clock;
fid = fopen(['/raid0/Jeff_Demas/MATLAB_TMP/matlab_log_' num2str(clck(1)) '_' num2str(clck(2)) '_' num2str(clck(3)) '_' num2str(clck(4)) '_' num2str(clck(5)) '.txt'],'w');

disp(['Processing ' num2str(numfiles) ' files found in directory ' path '...'])

poolobj = gcp('nocreate');
if ~isempty(poolobj)
    disp('Removing existing parallel pool.')
    delete(poolobj)
end

filestem = files(1).name;
inds = strfind(filestem,'_');
filestem = filestem(1:inds(end));

% disp('FOR LOOP ALTERED!!!')
for abc = 1:numfiles
    try 
        disp(['Beginning calculations for plane ' num2str(abc) ' of ' num2str(numfiles) '...'])
        date = datetime(now,'ConvertFrom','datenum');
        formatSpec = '%s BEGINNING PLANE %u\n';
        fprintf(fid,formatSpec,date,abc);

        tic

        file = [filestem num2str(abc)];

        d = load([path file '.mat']);
        data = d.Y;

        fullVolumeSize = d.sizY;
        pixel_resolution = d.pixelResolution;
        volume_rate = d.volumeRate;

        t0 = toc;
        disp(['Data loaded in. This process takes ' num2str(t0./60) ' minutes.'])
        date = datetime(now,'ConvertFrom','datenum');
        formatSpec = '%s data loaded.\n';
        fprintf(fid,formatSpec,date,abc);

        poolobj = gcp('nocreate');
        if isempty(poolobj)
            disp('Starting the parallel pool...')
            parpool('local');
        else
            numworkers = poolobj.NumWorkers;
            disp(['Continuing with existing pool of ' num2str(numworkers) '.'])
        end
        
        %% CaImAn segmentation

        % Give access to CaImAn files
        addpath(genpath('/raid0/Jeff_Demas/PROCESSING_SCRIPTS/Segmentation_Routines/CaImAn-MATLAB-master/CaImAn-MATLAB-master/'))
        addpath(genpath('/raid0/Jeff_Demas/PROCESSING_SCRIPTS/Segmentation_Routines/CaImAn-MATLAB-master/CaImAn-MATLAB-master/utilities/'))
        addpath(genpath('/raid0/Jeff_Demas/PROCESSING_SCRIPTS/Segmentation_Routines/CaImAn-MATLAB-master/CaImAn-MATLAB-master/use_cases/'))
        addpath(genpath('/raid0/Jeff_Demas/PROCESSING_SCRIPTS/Segmentation_Routines/CaImAn-MATLAB-master/CaImAn-MATLAB-master/tests/'))
        addpath(genpath('/raid0/Jeff_Demas/PROCESSING_SCRIPTS/Segmentation_Routines/CaImAn-MATLAB-master/CaImAn-MATLAB-master/Sources2D/'))
        addpath(genpath('/raid0/Jeff_Demas/PROCESSING_SCRIPTS/Segmentation_Routines/CaImAn-MATLAB-master/CaImAn-MATLAB-master/endoscope/'))
        addpath(genpath('/raid0/Jeff_Demas/PROCESSING_SCRIPTS/Segmentation_Routines/CaImAn-MATLAB-master/CaImAn-MATLAB-master/docs/'))
        addpath(genpath('/raid0/Jeff_Demas/PROCESSING_SCRIPTS/Segmentation_Routines/CaImAn-MATLAB-master/CaImAn-MATLAB-master/deconvolution/'))
        addpath(genpath('/raid0/Jeff_Demas/PROCESSING_SCRIPTS/Segmentation_Routines/CaImAn-MATLAB-master/CaImAn-MATLAB-master/3D/'))
        addpath(genpath('/raid0/Jeff_Demas/PROCESSING_SCRIPTS/Segmentation_Routines/motion_correction/'))

        [d1,d2,T] = size(data);                                % dimensions of dataset
        d = d1*d2;                                          % total number of pixels

        % volume_rate = 9.6;
        FrameRate = volume_rate;

        tau = ceil(7.5./pixel_resolution);

        if pixel_resolution>3
            dist = 1.5;
        else 
            dist = 1.25;
        end

        % CaImAn settings
        merge_thresh = 0.8; % threshold for merging
        min_SNR = 1.4; 
        space_thresh = 0.2; % threhsold for selection of neurons by space
        time_thresh = 0.0;
        sz = 0.1; % IF FOOTPRINTS ARE TOO SMALL, CONSIDER sz = 0.1
        mx = ceil(pi.*(1.33.*tau).^2);
        mn = floor(pi.*(tau.*0.5).^2); % SHRINK IF FOOTPRINTS ARE TOO SMALL

        p = 2;

        % patch set up
        sizY = size(data);
        patch_size = round(650/pixel_resolution).*[1,1]; % 145
        overlap = [1,1].*ceil(50./pixel_resolution);
        patches = construct_patches(sizY(1:end-1),patch_size,overlap);

        K = ceil(9.2e4.*20e-9.*(pixel_resolution.*patch_size(1)).^2);

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
        'search_method','ellipse',...
        'min_size', round(tau), ...           % minimum size of ellipse axis (default: 3)
        'max_size', 2*round(tau), ....             % maximum size of ellipse axis (default: 8)
        'dist', dist, ...                              % expansion factor of ellipse (default: 3)
        'max_size_thr',mx,...                       % maximum size of each component in pixels (default: 300)
        'time_thresh',time_thresh,...
        'min_size_thr',mn,...                       % minimum size of each component in pixels (default: 9)
        'refine_flag',0,...
        'rolling_length',ceil(FrameRate*5),...
        'fr', FrameRate);

        disp('Beginning patched, volumetric CNMF...')
        [A,b,C,f,S,P,~,YrA] = run_CNMF_patches(data,K,patches,tau,p,options);
        date = datetime(now,'ConvertFrom','datenum');
        formatSpec = '%s Initial CNMF complete.\n';
        fprintf(fid,formatSpec,date,abc);

        disp('Beginning component classification...')
        [rval_space,rval_time,max_pr,sizeA,keep0,~,traces] = classify_components_jeff(data,A,C,b,f,YrA,options);
        date = datetime(now,'ConvertFrom','datenum');
        formatSpec = '%s Component classification complete.\n';
        fprintf(fid,formatSpec,date,abc);

        Cn =  correlation_image(data); 

        %%

        ind_corr = (rval_space > space_thresh) & (sizeA >= options.min_size_thr) & (sizeA <= options.max_size_thr);                     

        % Event exceptionality:
        fitness = compute_event_exceptionality(traces,options.N_samples_exc,options.robust_std);
        ind_exc = (fitness < options.min_fitness);

        % Select components:
        keep = ind_corr & ind_exc;

        % Display kept and discarded components
        A_keep = A(:,keep);
        C_keep = C(keep,:);
        Km = size(C_keep,1);  % total number of components
        rVals = rval_space(keep);

        t1 = toc;
        disp(['CNMF complete. Process took ' num2str((t1-t0)./60) ' minutes. Extracting raw fluorescence traces...']);            

        P.p = 0;
        options.nb = options.gnb;
        [C_keep,f,~,~,R_keep] = update_temporal_components_fast(data,A_keep,b,C_keep,f,P,options);

        t2 = toc;
        disp(['Temporal components updated. Process took ' num2str((t2-t1)./60) ' minutes. Extracting raw fluorescence traces...']);            
        date = datetime(now,'ConvertFrom','datenum');
        formatSpec = '%s Temporal components updated.\n';
        fprintf(fid,formatSpec,date,abc);

        [T_keep,F0] = detrend_df_f(A_keep,[b,ones(d1*d2,1)],C_keep,[f;-min(min(min(data)))*ones(1,T)],R_keep,options);

        t3 = toc;
        disp(['Components detrended. Process took = ' num2str((t3-t2)./60) ' minutes.'])
        date = datetime(now,'ConvertFrom','datenum');
        formatSpec = '%s Temporal components detrended.\n';
        fprintf(fid,formatSpec,date,abc);

        [Ac_keep,acx,acy,acm] = AtoAc(A_keep,tau,d1,d2);
        Ym = single(mean(data,3));
        Cn = single(Cn);
        C_keep = single(C_keep);
        b = single(b);
        f = single(f);
        
        savefast([save_path 'caiman_output_plane_' num2str(abc) '.mat'],'T_keep','Ac_keep','C_keep','Km','rVals','Ym','Cn','b','f','acx','acy','acm')   

        t4 = toc;
        disp(['Segmentation complete and data saved. Total time elapsed for current iteration ' num2str(t4./60) ' minutes.'])
        date = datetime(now,'ConvertFrom','datenum');
        formatSpec = '%s Data saved.\n';
        fprintf(fid,formatSpec,date,abc);

        clearvars -except abc numfiles files path save_path fid filestem

    catch ME
        date = datetime(now,'ConvertFrom','datenum');
        errorMessage = sprintf('%s Error in function %s() at line %d. Error Message: %s', ...
        date,ME.stack(1).name, ME.stack(1).line, ME.message);
        fprintf(1, '%s\n', errorMessage);
        fprintf(fid,errorMessage,date,ME.stack(1).name, ME.stack(1).line, ME.message);

        disp('Shutting down parallel pool to eliminate error propagation.')
        poolobj = gcp('nocreate');
        delete(poolobj)
        
        clearvars -except abc numfiles files path save_path fid filestem
        
    end
end

date = datetime(now,'ConvertFrom','datenum');
formatSpec = '%s Routine complete.\n';
fprintf(fid,formatSpec,date,abc);
fclose(fid);