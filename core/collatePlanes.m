function [] = collatePlanes(data_path, varargin)
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
% num_features : double, positive
%     The number of neurons to select for the lateral offset correction
%     between z-planes. Default is 1 feature/neuron.
% options : struct
%     Struct containing key-value pairs for 'min_SNR' and 'merge_thresh'.
% motion_corrected_path: string
%     Path to motion corrected data. Default is
%     data_path/../motion_corrected/,

% Correct for lateral offsets between z-planes and merge highly correlated
% neurons. Ensure pollen calibration files are found in data_path!

p = inputParser;
addRequired(p, 'data_path', @(x) ischar(x) || isstring(x));
addParameter(p, 'save_path', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'ds', "/Y", @(x) (ischar(x) || isstring(x)));
addParameter(p, 'debug_flag', 0, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'do_figures', 1, @(x) isnumeric(x) || islogical(x));
addParameter(p, 'overwrite', 1, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'start_plane', 1, @(x) isnumeric(x) && x > 0);
addParameter(p, 'end_plane', 2, @(x) isnumeric(x) && x > 0); % Remove dependence on start_plane
addParameter(p, 'num_features', 3, @(x) isnumeric(x) && isPositiveIntegerValuedNumeric(x));
addParameter(p, 'options', {});
addParameter(p, 'motion_corrected_path', '', @(x) ischar(x) || isstring(x));

parse(p, data_path, varargin{:});

% Ensure end_plane is greater than or equal to start_plane
if p.Results.end_plane < p.Results.start_plane
    error('end_plane must be greater than or equal to start_plane.');
end

data_path = p.Results.data_path;
save_path = p.Results.save_path;
do_figures = p.Results.do_figures;
motion_corrected_path = p.Results.motion_corrected_path;
debug_flag = p.Results.debug_flag;
overwrite = p.Results.overwrite;
start_plane = p.Results.start_plane;
end_plane = p.Results.end_plane;
dataset_name = p.Results.ds;
options = p.Results.options;
num_features = p.Results.num_features;

if ~isfolder(data_path); error("%s does not exist", data_path); end

if debug_flag == 1
    dir([data_path '/' '*.mat*'])
    dir([data_path '/' '*.h*'])
    dir([data_path '/' '*.fig*'])
    return;
end

if isempty(motion_corrected_path)
    motion_corrected_path = fullfile(data_path, '..', 'motion_corrected');
    if ~isfolder(motion_corrected_path)
        error("The filepath for motion corrected videos does not exist. Use 'motion_corrected_path' parameter pointing to this folder.")
    end
end

if isempty(save_path)
    save_path = fullfile(data_path, '../', 'collated');
    if ~isfolder(save_path); mkdir(save_path);
        warning('Creating save path since one was not provided, located: %s', save_path);
    end
elseif ~isfolder(save_path)
    mkdir(save_path);
end

if do_figures
    fig_save_path = fullfile(save_path, "figures");
    if ~isfolder(fig_save_path); mkdir(fig_save_path); end
end

if ~(start_plane<=end_plane); error("Start plane must be < end plane"); end

log_file_name = sprintf("%s_collation.log", datestr(datetime('now'), 'yyyy_mm_dd_HH_MM_SS'));
log_full_path = fullfile(data_path, log_file_name);
fid = fopen(log_full_path, 'w');
if fid == -1
    error('Cannot create or open log file: %s', log_full_path);
else
    fprintf('Log file created: %s\n', log_full_path);
end

offsets_file = fullfile(data_path, sprintf('mean_%d_neuron_offsets.mat', num_features));
if overwrite || ~isfile(offsets_file)
    calculateZOffset(data_path, 'motion_corrected_path', motion_corrected_path, 'debug_flag', debug_flag, 'overwrite', overwrite, 'start_plane', start_plane, 'end_plane', end_plane, 'num_features', num_features);
end

%% First plane

c = load(offsets_file, 'offsets');
offsets = round(c.offsets);

xo = cumsum(-offsets(:,2));
xo = xo-min(xo);

yo = cumsum(-offsets(:,1));
yo = yo-min(yo);

options = struct(options{:});
min_snr = options.min_SNR;
r_thr = 0.4;

for ijk = start_plane:end_plane

    if ijk == start_plane

        merge_thr = 0.8;
        ovp_thr = 0.0;
        Kms = zeros(30,1);
        num_corr_no_ovp = 0; 
        num_ovlpd = 0;

        fpath = fullfile(data_path, sprintf("segmented_plane_%d.h5", ijk));
        tmpfpath = fullfile("E:\W2_archive\demas_2021\high_resolution\matlab\registered", sprintf("motion_corrected_plane_%d.h5", ijk));
        Ym=h5read(tmpfpath, "/Ym");
    
        Tinit = h5read(fpath, "/T_keep");
        rVals = h5read(fpath, "/rVals");
        frame_rate = h5readatt(fpath, '/', 'frame_rate');
        pixel_resolution =  h5readatt(fpath, '/', 'pixel_resolution');
        tau = ceil(7.5/pixel_resolution);

        decay_time = 0.5;
        Nsamples = ceil(decay_time*frame_rate);
        min_fitness = log(normcdf(-min_snr))*Nsamples;
        [fitness] = compute_event_exceptionality(Tinit,Nsamples,0);

        clear Tinit

        if size(rVals)>0
            T_keep = h5read(fpath, "/T_keep");
            C_keep = h5read(fpath, "/C_keep");
            Ac_keep = h5read(fpath, "/Ac_keep");
            acm = h5read(fpath, "/acm");
            acy = h5read(fpath, "/acy");
            acx = h5read(fpath, "/acx");

            kp = logical(rVals>r_thr & fitness<min_fitness);
        
            T = T_keep(kp,:);
            C = C_keep(kp,:);
            Y = Ym;
            A = Ac_keep(:,:,kp);
            K = size(T,1);
            Kms(1) = K;
            N = zeros(K,4);
            N(:,1) = acm(kp)';
            N(:,2) = acy(kp)';
            N(:,3) = acx(kp)';
            N(:,4) = 1;
            
        else
            fff = h5read(fpath, "/f");
            bbb = h5read(fpath, "/b");
            T = NaN(1,size(fff,2));
            C = NaN(1,size(fff,2));
            Y = Ym;
            A = NaN(size(bbb,1),1);
            K = 1;
            Kms(1) = K;
            N = zeros(K,4);
        end
        
        T_all = T;
        N_all = N;
        C_all = C;
            
        continue
    end

    disp(['Beginning calculation for plane ' num2str(ijk)])

    fpath = fullfile(data_path, sprintf("segmented_plane_%d.h5", ijk));
    tmpfpath = fullfile("E:\W2_archive\demas_2021\high_resolution\matlab\registered", sprintf("motion_corrected_plane_%d.h5", ijk));

    rValsm = h5read(fpath, "/rVals");
    Tinit = h5read(fpath, "/T_keep");

    [fitness] = compute_event_exceptionality(Tinit,Nsamples,0);
    clear Tinit

    T_keep = h5read(fpath, "/T_keep");
    C_keep = h5read(fpath, "/C_keep");
    Ac_keep = h5read(fpath, "/Ac_keep");
    acm = h5read(fpath, "/acm");
    acy = h5read(fpath, "/acy");
    acx = h5read(fpath, "/acx");

    kpm = logical(rValsm>r_thr & fitness<min_fitness);
    Tm = T_keep(kpm,:);
    Cm = C_keep(kpm,:);
    Ym=h5read(tmpfpath, "/Ym");
    % Ym = Ym;
    Am = Ac_keep(:,:,kpm);
    Km = size(Tm,1);
    Kms(ijk) = Km;
    Nm = zeros(Km,4);
    Nm(:,1) = acm(kpm)';
    Nm(:,2) = acy(kpm)';
    Nm(:,3) = acx(kpm)';
    Nm(:,4) = ijk;


    Nm(:,2) = Nm(:,2) + cumsum(xo(ijk));
    Nm(:,3) = Nm(:,3) + cumsum(yo(ijk));

    if size(T,1)>0 && size(Tm,1)>0
        RR = corr(T',Tm');
        MM = RR;
        MM(RR<merge_thr) = 0;
    else
        MM = 0;
    end

    if sum(sum(MM))>0

        inds = find(MM(:));
        [ys,xs] = ind2sub(size(MM),inds);
        mm = MM(MM>0);
        [mm,sinds] = sort(mm,'ascend');
        ys = ys(sinds);
        xs = xs(sinds);

        Nk = numel(ys);

        for xyz = 1:Nk
            k = ys(xyz);
            km = xs(xyz);

            distance = sqrt(abs(N(k,2)-Nm(km,2)).^2 + abs(N(k,3)-Nm(km,3)).^2);

            overlapped = distance<3*tau;

            if overlapped
                if ijk>2
                    indbuffer = sum(Kms(1:(ijk-2)));
                else 
                    indbuffer = 0;
                end

                T_all(indbuffer+k,:) = NaN(1,size(T_all,2));
                C_all(indbuffer+k,:) = NaN(1,size(T_all,2));
                N(indbuffer+k,:) = NaN(1,4);

                new_T = (T(k,:).*N(k,1) + Tm(km,:).*Nm(km,1))./(N(k,1) + Nm(km,1));
                new_C = (C(k,:).*N(k,1) + Cm(km,:).*Nm(km,1))./(N(k,1) + Nm(km,1));
                new_x = round((N(k,2)*N(k,1) + Nm(km,2)*Nm(km,1))./(N(k,1) + Nm(km,1)));
                new_y = round((N(k,3)*N(k,1) + Nm(km,3)*Nm(km,1))./(N(k,1) + Nm(km,1)));
                new_z = (N(k,4)*N(k,1) + Nm(km,4)*Nm(km,1))./(N(k,1) + Nm(km,1));
                new_sum = N(k,1) + Nm(km,1);

                Tm(km,:) = new_T;
                Cm(km,:) = new_C;
                Nm(km,:) = [new_sum new_x new_y new_z];

                num_ovlpd = num_ovlpd+1;

            else
                num_corr_no_ovp = num_corr_no_ovp+1;
            end
        end
    end

    T_all = cat(1,T_all,Tm);
    N_all = cat(1,N_all,Nm);
    C_all = cat(1,C_all,Cm);
    T = Tm;
    C = Cm;
    Y = Ym;
    A = Am;
    N = Nm;

    clear pm Tm Ym Cm RR MM XX Am Nm xxx XXX yyy YYY

end

is = ~isnan(sum(T_all,2));
T_all = T_all(is,:);
N_all = N_all(is,:);

C_all = zeros(size(T_all),'single');

disp('De-convolving raw traces...')
parfor j = 1:size(T_all,1)
    spkmin = 0.5*GetSn(T_all(j,:));
    [cc, spk, opts_oasis] = deconvolveCa(T_all(j,:),'ar2','optimize_b',true,'method','thresholded',...
        'optimize_pars',true,'maxIter',100,'smin',spkmin);
    cb = opts_oasis.b;

    C_all(j,:) = full(cc(:)' + cb);

end

if sum(isnan(C_all(:)))>0
    inds = find(isnan(sum(C_all,2)));
    disp(['Replacing ' num2str(numel(inds)) ' traces where de-convolution failed...'])

    for ijk = 1:numel(inds)
        C_all(inds(ijk),:) = T_all(inds(ijk),:);
    end
end

%% Z plane correction
try
    open([data_path '/' 'pollen_calibration_Z_vs_N.fig'])
catch
    open([data_path '/' 'pollen_calibration_z_vs_N.fig'])
end

fig = gcf;
do = findobj(fig,'-property','Ydata');
x = [do(3,1).XData do(2,1).XData];
y = [do(3,1).YData do(2,1).YData];
ftz = fit(x',y','cubicspline');
close(fig)

%% X, Y positions and Z field curvature correction

fov = h5readatt(fpath, '/', 'fov');
FOVy = fov(1);
FOVx = fov(2)*0.97;

ny = (FOVy./size(Y,1)).*N_all(:,2);
nx = (FOVx./size(Y,2)).*N_all(:,3);
nz = N_all(:,4);

nz = ftz(nz);
curvz = 158/2500^2;
nz = nz - curvz.*((ny-FOVy/2).^2 + (nx-FOVx/2).^2);

% z0 = str2double(inputdlg('Enter minimum depth (um):'));
z0 = 50;
nz = nz+z0;

keep = logical(nz>0);

T_all = T_all(keep,:);
C_all = C_all(keep,:);
N_all = N_all(keep,:);
nx = nx(keep);
ny = ny(keep);
nz = nz(keep);

figure;
histogram(nz/1000)
title('Neuron distribution in z')
xlabel('z (mm)')
saveas(gcf,fullfile(fig_save_path, 'all_neuron_z_distribution.fig'))

figure;
histogram(sqrt((nx-FOVx/2).^2 + (ny-FOVy/2).^2)/1000)
title('Neuron distribution in r')
xlabel('r (mm)')
saveas(gcf,fullfile(fig_save_path, 'all_neuron_r_distribution.fig'))

disp('Planes collated. Saving data...')
% savefast([fig_save_path '/' 'collated_caiman_output_minSNR_' strrep(num2str(min_snr),'.','p') '.mat'],'T_all','nx','ny','nz','C_all','offsets')

save_path = fullfile(save_path, sprintf("collated_planes.h5"));
try
    h5create(save_path, "/T_all",size(T_all));
catch
    delete(save_path)
    h5create(save_path, "/T_keep",size(T_keep));
end

h5create(save_path,"/nx",size(nx));
h5create(save_path,"/ny",size(ny));
h5create(save_path,"/nz",size(nz));
h5create(save_path,"/C_all",size(C_all));
h5create(save_path,"/offsets",size(offsets));
h5create(save_path,"/min_snr",size(min_snr));

h5write(save_path,"/T_all",C_all);
h5write(save_path,"/nx",nx);
h5write(save_path,"/ny",ny);
h5write(save_path,"/nz",nz);
h5write(save_path,"/C_all",C_all);
h5write(save_path,"/offsets",offsets);
