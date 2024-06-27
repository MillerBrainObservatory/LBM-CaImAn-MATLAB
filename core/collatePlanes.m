function [] = collatePlanes(data_path, save_path, varargin)
% COLLATEPLANES Analyzes and processes imaging data by extracting and correcting features across multiple planes.
%
% Parameters
% ----------
% data_path : string
%     Path to the directory containing the image data and calibration files.
%     The function expects to find 'pollen_sample_xy_calibration.mat' in this directory along with each caiman_output_plane_N.
% save_path : char
%     Path to the directory to save the motion vectors.
% dataset_name : string, optional
%     Group path within the hdf5 file that contains raw data.
%     Default is 'registration'.
% debug_flag : double, logical, optional
%     If set to 1, the function displays the files in the command window and does
%     not continue processing. Defaults to 0.
% overwrite : logical, optional
%     Whether to overwrite existing files (default is 1).
% start_plane : double, integer, positive
%     The starting plane index for processing.
% end_plane : double, integer, positive
%     The ending plane index for processing. Must be greater than or equal to
%     start_plane.
% reordered : logical, optional
%      if `rename_planes` was ran, "reordered" will be in the name. 
%
% Returns
% -------
% offsets : Nx2 array
%     An array of offsets between consecutive planes, where N is the number
%     of planes processed. Each row corresponds to a plane, and the two columns
%     represent the calculated offset in pixels along the x and y directions,
%     respectively.
%
% Notes
% -----
% - This function requires calibration data in input datapath:
%   - pollen_sample_xy_calibration.mat
% - The function uses MATLAB's `ginput` function for manual feature selection
%   on the images. It expects the user to manually select the corresponding
%   points on each plane.
% - The function assumes that the consecutive images will have some overlap
%   and that features will be manually identifiable and trackable across planes.
%
% Example
% -------
% offsets = calculateZOffset('C:/data/images/', metadata, 1, 10, 5);
%
% See also LOAD, MAX, IND2SUB, XCORR2, GINPUT, NANMEAN

p = inputParser;
addRequired(p, 'data_path');
addRequired(p, 'save_path');
addParameter(p, 'dataset_name', "/mov", @(x) (ischar(x) || isstring(x)) && isValidGroupPath(x));
addOptional(p, 'debug_flag', 0, @(x) isnumeric(x));
addParameter(p, 'overwrite', 1, @(x) isnumeric(x));
addParameter(p, 'start_plane', 1, @(x) isnumeric(x) && x > 0);
addParameter(p, 'end_plane', 1, @(x) isnumeric(x) && x >= p.Results.start_plane);
addParameter(p, 'num_features', 3, @(x) isnumeric(x) && isPositiveIntegerValuedNumeric(x));
parse(p, data_path, save_path, varargin{:});

data_path = p.Results.data_path;
save_path = p.Results.save_path;
dataset_name = p.Results.dataset_name; % here for param consistency but ignored
debug_flag = p.Results.debug_flag;
overwrite = p.Results.overwrite;
start_plane = p.Results.start_plane;
end_plane = p.Results.end_plane;

if ~isfolder(data_path)
    error("Data path:\n %s\n ..does not exist", data_path);
end

if debug_flag == 1; dir([data_path, '*.tif']); return; end
if isempty(save_path)
    warning("No save_path given. Saving data in data_path: %s\n", data_path);
    save_path = data_path;
end

files = dir(fullfile(data_path, '*.h*'));
if isempty(files)
    error('No suitable data files found in: \n  %s', data_path);
end

log_file_name = sprintf("%s_collation.log", datestr(datetime('now'), 'yyyy_mm_dd_HH_MM_SS'));
log_full_path = fullfile(save_path, log_file_name);
fid = fopen(log_full_path, 'w');
if fid == -1
    error('Cannot create or open log file: %s', log_full_path);
else
    fprintf('Log file created: %s\n', log_full_path);
end
% closeCleanupObj = onCleanup(@() fclose(fid));

calib_files = fullfile(data_path, 'pollen*');
calib_files = dir(calib_files);
if length(calib_files) < 2
    error("Missing pollen calibration files in folder:\n%s\n", data_path);
else
    for i=length(calib_files)
        calib = fullfile(calib_files(i).folder, calib_files(i).name);
        if calib_files(i).name == "pollen_sample_xy_calibration.mat"
            pollen_offsets = matfile(calib);
            diffx = pollen_offsets.diffx;
            diffy = pollen_offsets.diffy;
        end
        fprintf("Loaded calibration file:\n");
        fprintf("%s\n",fullfile(calib_files(i).folder, calib_files(i).name));
    end
end

if ~exist("diffx", "var")
    error("Missing or incorrect pollen calibration file supplied.");
end

fprintf(fid, '%s : Beginning axial offset correction...\n', datestr(datetime('now'), 'yyyy_mm_dd_HH_MM_SS'));
tall = tic;
for curr_plane = start_plane:end_plane
    if curr_plane + 1 > end_plane
        fprintf("Current plane (%d) > Last Plane (%d)", curr_plane, end_plane);
        continue;
    end
    plane_name = sprintf("%s/segmented_plane_%d.h5", data_path, curr_plane);
    plane_name_save = sprintf("%s/collated_plane_%d.h5", save_path, curr_plane);
    if isfile(plane_name_save)
        fprintf(fid, '%s : %s already exists.\n', datestr(datetime('now'), 'yyyy_mm_dd_HH_MM_SS'), plane_name_save);
        if overwrite
            fprintf(fid, '%s : Parameter Overwrite=true. Deleting file: %s\n', datestr(datetime('now'), 'yyyy_mm_dd_HH_MM_SS'), plane_name_save);
            delete(plane_name_save)
        end
    end
    try
        metadata = read_h5_metadata(plane_name, '/');
    catch ME
        if contains(ME.message, 'not found')
            
            error("Error reading data given data-path: %s", data_path)
        end
    end
    if isempty(fieldnames(metadata))
        error("No metadata found for this filepath.");
    end
    if ~(metadata.num_planes >= end_plane)
        error("Not enough planes to process given user supplied argument: %d as end_plane when only %d planes exist in this dataset.", end_plane, metadata.num_planes);
    end

    Y = h5read(plane_name, dataset_name);
    Y = Y - min(Y(:));
    volume_size = size(Y);

    r_thr = metadata.r_thr;
    pixel_resolution = metadata.pixel_resolution;
    min_snr = metadata.min_snr;
    frameRate = metadata.frame_rate;
    FOVx = metadata.fovx;
    FOVy = metadata.fovy;

    tau = ceil(7.5/pixel_resolution);

    merge_thr = 0.8;
    ovp_thr = 0.0;
    Kms = zeros(30,1);
    num_corr_no_ovp = 0;
    num_ovlpd = 0;

    % p = load([path 'caiman_output_plane_1.mat']); % Load stuff from first p
    Ac_keep = h5read(h5_segmented, '/Ac_keep');
    T_keep = h5read(h5_segmented, '/T_keep');

    Cn = h5read(h5_segmented, '/Cn');
    C_keep = h5read(h5_segmented, '/C_keep');
    Km = h5read(h5_segmented, '/Km');
    acm = h5read(h5_segmented, '/acm');
    acx = h5read(h5_segmented, '/acx');
    acy = h5read(h5_segmented, '/acy');
    f = h5read(h5_segmented, '/f');
    b = h5read(h5_segmented, '/b');
    rVals = h5read(h5_segmented, '/rVals');

    % rVals = p.rVals;

    Tinit = T_keep;
    decay_time = 0.5;
    Nsamples = ceil(decay_time*frameRate);
    min_fitness = log(normcdf(-min_snr))*Nsamples;
    [fitness] = compute_event_exceptionality(Tinit,Nsamples,0);

    clear Tinit

    if size(rVals)>0
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
        fff = f;
        bbb = b;
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

    c = load([path 'mean_neuron_offsets.mat'],'offsets');
    offsets = round(c.offsets);

    xo = cumsum(-offsets(:,2));
    xo = xo-min(xo);

    yo = cumsum(-offsets(:,1));
    yo = yo-min(yo);

    for ijk = 2:28

        disp(['Beginning calculation for plane ' num2str(ijk)])

        pm = load([path 'caiman_output_plane_' num2str(ijk) '.mat']);

        Tinit = pm.T_keep;
        [fitness] = compute_event_exceptionality(Tinit,Nsamples,0);

        clear Tinit

        rValsm = pm.rVals;

        kpm = logical(rValsm>r_thr & fitness<min_fitness);

        Tm = pm.T_keep(kpm,:);
        Cm = pm.C_keep(kpm,:);
        Ym = pm.Ym;
        Am = pm.Ac_keep(:,:,kpm);
        Km = size(Tm,1);
        Kms(ijk) = Km;
        Nm = zeros(Km,4);
        Nm(:,1) = pm.acm(kpm)';
        Nm(:,2) = pm.acy(kpm)';
        Nm(:,3) = pm.acx(kpm)';
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
                    else indbuffer = 0;
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
    C_all = C_all(is,:);
    N_all = N_all(is,:);

    C_all = zeros(size(T_all),'single');

    disp('De-convolving raw traces...')
    parfor j = 1:size(T_all,1);
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
        open([path 'pollen_calibration_Z_vs_N.fig'])
    catch
        open([path 'pollen_calibration_z_vs_N.fig'])
    end

    fig = gcf;
    do = findobj(fig,'-property','Ydata');
    x = [do(3,1).XData do(2,1).XData];
    y = [do(3,1).YData do(2,1).YData];
    ftz = fit(x',y','cubicspline');
    close(fig)

    %% X, Y positions and Z field curvature correction

    ny = (FOVy./size(Y,1)).*N_all(:,2);
    nx = (FOVx./size(Y,2)).*N_all(:,3);
    nz = N_all(:,4);

    nz = ftz(nz);
    curvz = 158/2500^2;
    nz = nz - curvz.*((ny-FOVy/2).^2 + (nx-FOVx/2).^2);
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
    saveas(gcf,[path 'all_neuron_z_distribution.fig'])

    figure;
    histogram(sqrt((nx-FOVx/2).^2 + (ny-FOVy/2).^2)/1000)
    title('Neuron distribution in r')
    xlabel('r (mm)')
    saveas(gcf,[path 'all_neuron_r_distribution.fig'])

    %%
    disp('Planes collated. Saving data...')
    savefast([path 'collated_caiman_output_minSNR_' strrep(num2str(min_snr),'.','p') '.mat'],'T_all','nx','ny','nz','C_all','offsets')

end
