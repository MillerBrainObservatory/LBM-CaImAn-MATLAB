clear 
close all
clc

addpath(genpath('\\v-storage.rockefeller.edu\vazirilab_medium_data\jeff_demas\PROCESSING_SCRIPTS\Segmentation_Routines\motion_correction\'))

d = load('plane_26_data.mat','poi');
data = single(d.poi);
[ny,nx,nt] = size(data);

%% Motion Correction

gcp;
    
% Rigid motion correction using NoRMCorre algorithm:    
options_rigid = NoRMCorreSetParms(...
    'd1',size(data,1),...
    'd2',size(data,2),...
    'bin_width',24,...       % Bin width for motion correction
    'max_shift',15,...        % Max shift in px
    'us_fac',20,...
    'init_batch',120,...     % Initial batch size
    'correct_bidir',false... % Correct bidirectional scanning
    );
[M1,shifts1,~,~] = normcorre_batch(data,options_rigid);


shifts_r = squeeze(cat(3,shifts1(:).shifts));
shifts_v = movvar(shifts_r,24,1);
% [~,minv_idx] = mink(shifts_v,120,1);
[srt,minv_idx] = sort(shifts_v,120); 
minv_idx = minv_idx(1:120);
best_idx = unique(reshape(minv_idx,1,[]));
template_good = mean(M1(:,:,best_idx),3);

% No rigid motion correction using the good tamplate from the rigid
% correction.
  options_nonrigid = NoRMCorreSetParms(...
    'd1',size(data,1),...
    'd2',size(data,2),...
    'bin_width',24,...
    'max_shift',15,...
    'us_fac',20,...
    'init_batch',120,...
    'correct_bidir',false...
    );

% Data from the motion correction that will be used for the CNMF
[M2,shifts2,~,~] = normcorre_batch(data,options_nonrigid,template_good);

%% Metrics of the motion correction

shifts_r = squeeze(cat(3,shifts1(:).shifts));
shifts_nr = cat(ndims(shifts2(1).shifts)+1,shifts2(:).shifts);
shifts_nr = reshape(shifts_nr,[],ndims(data)-1,nt);
shifts_x = squeeze(shifts_nr(:,1,:))';
shifts_y = squeeze(shifts_nr(:,2,:))';

[cY,~,~] = motion_metrics(data,10);
[cM1,~,~] = motion_metrics(M1,10);
[cM2,~,~] = motion_metrics(M2,10);

motionCorrectionFigure = figure;

ax1 = subplot(311); plot(1:nt,cY,1:nt,cM1,1:nt,cM2); legend('raw data','rigid','non-rigid'); title('correlation coefficients','fontsize',14,'fontweight','bold')
        set(gca,'Xtick',[])
ax2 = subplot(312); %plot(shifts_x); hold on; 
plot(shifts_r(:,1),'--k','linewidth',2); title('displacements along x','fontsize',14,'fontweight','bold')
        set(gca,'Xtick',[])
ax3 = subplot(313); %plot(shifts_y); hold on; 
plot(shifts_r(:,2),'--k','linewidth',2); title('displacements along y','fontsize',14,'fontweight','bold')
        xlabel('timestep','fontsize',14,'fontweight','bold')
linkaxes([ax1,ax2,ax3],'x')

% Figure: Motion correction Metrics
% saveas(motionCorrectionFigure,[filename '_motion_correction_metrics.fig']);
% close(motionCorrectionFigure)

data = M2;
clear M2

%% CaImAn segmentation

addpath(genpath('C:\Users\jdemas\Documents\MATLAB\'))

gcp;                            % start cluster
addpath(genpath('CaImAn-MATLAB-master/CaImAn-MATLAB-master/utilities'));
addpath(genpath('CaImAn-MATLAB-master/CaImAn-MATLAB-master/deconvolution'));

% Give access to CaImAn files
addpath('CaImAn-MATLAB-master/CaImAn-MATLAB-master')
addpath('CaImAn-MATLAB-master/CaImAn-MATLAB-master/utilities/')
addpath('CaImAn-MATLAB-master/CaImAn-MATLAB-master/use_cases/')
addpath('CaImAn-MATLAB-master/CaImAn-MATLAB-master/tests/')
addpath('CaImAn-MATLAB-master/CaImAn-MATLAB-master/Sources2D/')
addpath('CaImAn-MATLAB-master/CaImAn-MATLAB-master/endoscope/')
addpath('CaImAn-MATLAB-master/CaImAn-MATLAB-master/docs/')
addpath('CaImAn-MATLAB-master/CaImAn-MATLAB-master/deconvolution/')
addpath('CaImAn-MATLAB-master/CaImAn-MATLAB-master/3D/')
addpath('CaImAn-MATLAB-master/CaImAn-MATLAB-master/@CNMF/')

[d1,d2,T] = size(data);                                % dimensions of dataset
d = d1*d2;                                          % total number of pixels

FrameRate = 9.6;
tau = 7.5;
dist = 1.25;
merge_thresh = 0.8; % threshold for merging
min_SNR = 1.25; 
space_thresh = 0.2; % threhsold for selection of neurons by space
time_thresh = 0.0;
sz = 0.1; % IF FOOTPRINTS ARE TOO SMALL, CONSIDER sz = 0.1
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
'max_size', 2*round(tau), ....             % maximum size of ellipse axis (default: 8)
'dist', dist, ...                              % expansion factor of ellipse (default: 3)
'max_size_thr',mx,...                       % maximum size of each component in pixels (default: 300)
'time_thresh',time_thresh,...
'min_size_thr',mn,...                       % minimum size of each component in pixels (default: 9)
'refine_flag',0,...
'fr', FrameRate);

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
K = size(C_keep,1);  % total number of components

disp('Extracting raw fluorescence traces...');               

P.p = 0;
options.nb = options.gnb;
[C_keep,f,~,~,R_keep] = update_temporal_components_fast(data,A_keep,b,C_keep,f,P,options);

disp('Reordering components...')

try
    [A_keep,C_keep,S,P] = order_ROIs(A_keep,C_keep,S,P); % order components
catch
    disp('Reordering failed.')
end

[T_keep,F0] = detrend_df_f(A_keep,[b,ones(d1*d2,1)],C_keep,[f;-min(min(min(data)))*ones(1,T)],R_keep,options);

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