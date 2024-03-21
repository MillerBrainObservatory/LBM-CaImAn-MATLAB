clear
clc

path = input('Enter path:')

z0 = str2double(input('Enter minimum depth (um):'));

try
    addpath(genpath('/vmd/jason_manley/Codes/maximum-analysis/jeff/'))
catch
end

try
    addpath(genpath('/ru-auth/local/home/jmanley/maximum-analysis/caiman_pipeline/'))
catch
end

%% 

if size(strfind(path,'hemisphere'),1) > 0
    r_thr = 0.4;
    pixel_resolution = 5;
    min_snr = 1.4;
    frameRate = 4.69;
    FOVx = 3000;
    FOVy = 5000*0.97;
elseif size(strfind(path,'2mm'),1) > 0 && size(strfind(path,'1p2mm'),1) == 0
    r_thr = 0.4;
    pixel_resolution = 2.75;
    min_snr = 1.4;
    frameRate = 6.45;
    FOVx = 2000;
    FOVy = 2000*0.97;
elseif size(strfind(path,'0p9mm'),1) > 0
    r_thr = 0.4;
    pixel_resolution = 3;
    min_snr = 1.5;
    frameRate = 36.89;
    FOVx = 900;
    FOVy = 900*0.97;
elseif size(strfind(path,'0p6mm'),1) > 0
    r_thr = 0.4;
    pixel_resolution = 1;
    min_snr = 1.5;
    frameRate = 9.61;
    FOVx = 600;
    FOVy = 600*0.97;
elseif size(strfind(path,'6mm'),1) > 0 && size(strfind(path,'0.6mm'),1) == 0
    r_thr = 0.4;
    pixel_resolution = 4.6;
    min_snr = 1.4;
    frameRate = 2.18;
    FOVx = 5400;
    FOVy = 6000*0.97;
elseif size(strfind(path, '1p2mm'),1) > 0
    r_thr = 0.4;
    pixel_resolution = 2;
    min_snr = 1.4;
    frameRate = 9.61;
    FOVx = 1200;
    FOVy = 1200*0.97;
end

min_snr = 2;
         
tau = ceil(7.5/pixel_resolution);

merge_thr = 0.8;
ovp_thr = 0.0;
Kms = zeros(30,1);
num_corr_no_ovp = 0; 
num_ovlpd = 0;

p = load([path 'caiman_output_plane_1.mat']); % Load stuff from first p
rVals = p.rVals;

% DE-TREND
options.df_prctile = 20;
options.df_window = round(60 * frameRate);

num = size(p.Ac_keep,1);

A_keep = zeros(2*num+size(p.Cn,1),2*num+size(p.Cn,2),size(p.Ac_keep,3),'single');

for k = 1:p.Km
    syk = p.acy(k)-floor(num/2)+num;
    sxk = p.acx(k)-floor(num/2)+num;
    A_keep(syk+1:syk+num,sxk+1:sxk+num,k) = p.Ac_keep(:,:,k);
end

A_keep = A_keep(num+1:end,num+1:end,:);
A_keep = A_keep(1:size(p.Cn,1),1:size(p.Cn,2),:);

A_keep = reshape(A_keep, size(A_keep,1)*size(A_keep,2), size(A_keep,3));

[F_dff, F0] = detrend_df_f(A_keep,p.b,p.C_keep,p.f,zeros(size(p.C_keep)),options);

idx = sum(isnan(F_dff(:,:)),2)==0;
p.T_keep = F_dff(idx,:);
p.C_keep = p.C_keep(idx,:);
p.Ac_keep = p.Ac_keep(:,:,idx);
p.acm = p.acm(idx);
p.acy = p.acy(idx);
p.acx = p.acx(idx);
rVals = rVals(idx);

Tinit = p.T_keep; 
decay_time = 0.5;
Nsamples = ceil(decay_time*frameRate);
min_fitness = log(normcdf(-min_snr))*Nsamples;
[fitness] = compute_event_exceptionality(Tinit,Nsamples,0);

clear Tinit

if size(rVals)>0
    kp = logical(rVals>r_thr & fitness<min_fitness);

    T = p.T_keep(kp,:);
    C = p.C_keep(kp,:);
    Y = p.Ym;
    A = p.Ac_keep(:,:,kp);
    K = size(T,1);
    Kms(1) = K;
    N = zeros(K,4);
    N(:,1) = p.acm(kp)';
    N(:,2) = p.acy(kp)';
    N(:,3) = p.acx(kp)';
    N(:,4) = 1;
    
else
    fff = p.f;
    bbb = p.b;
    T = NaN(1,size(fff,2));
    C = NaN(1,size(fff,2));
    Y = p.Ym;
    A = NaN(size(bbb,1),1);
    K = 1;
    Kms(1) = K;
    N = zeros(K,4);
end

T_all = T;
N_all = N;
C_all = C;

c = load([path 'three_neuron_mean_offsets.mat'],'offsets');
offsets = round(c.offsets);

xo = cumsum(-offsets(:,2));
xo = xo-min(xo);

yo = cumsum(-offsets(:,1));
yo = yo-min(yo);

for ijk = 2:30
    
    disp(['Beginning calculation for plane ' num2str(ijk) ' of 30...'])
    
    pm = load([path 'caiman_output_plane_' num2str(ijk) '.mat']);
    
    % DE-TREND
    options.df_prctile = 20;
    options.df_window = round(60 * frameRate);
    
    num = size(pm.Ac_keep,1);

    A_keep = zeros(2*num+size(pm.Cn,1),2*num+size(pm.Cn,2),size(pm.Ac_keep,3),'single');

    for k = 1:pm.Km
        syk = pm.acy(k)-floor(num/2)+num;
        sxk = pm.acx(k)-floor(num/2)+num;
        A_keep(syk+1:syk+num,sxk+1:sxk+num,k) = pm.Ac_keep(:,:,k);
    end

    A_keep = A_keep(num+1:end,num+1:end,:);
    A_keep = A_keep(1:size(pm.Cn,1),1:size(pm.Cn,2),:);
    
    A_keep = reshape(A_keep, size(A_keep,1)*size(A_keep,2), size(A_keep,3));
    
    [F_dff, F0] = detrend_df_f(A_keep,pm.b,pm.C_keep,pm.f,zeros(size(pm.C_keep)),options);
    
    idx = sum(isnan(F_dff(:,:)),2)==0;
    pm.T_keep = F_dff(idx,:);
    pm.C_keep = pm.C_keep(idx,:);
    pm.Ac_keep = pm.Ac_keep(:,:,idx);
    pm.acm = pm.acm(idx);
    pm.acy = pm.acy(idx);
    pm.acx = pm.acx(idx);
    
    Tinit = pm.T_keep;
    [fitness] = compute_event_exceptionality(Tinit,Nsamples,0);
    
    clear Tinit
    
    rValsm = pm.rVals(idx);

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
open([path 'pollen_calibration_z_vs_N.fig'])
fig = gcf;
do = findobj(fig,'-property','Ydata');
if size(do,1) == 2
    x = [do(2,1).XData];
    y = [do(2,1).YData];
else
    x = [do(3,1).XData do(2,1).XData];
    y = [do(3,1).YData do(2,1).YData];
end

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
savefast([path 'collated_detrended_caiman_output_minSNR_' strrep(num2str(min_snr),'.','p') '.mat'],'T_all','nx','ny','nz','C_all','offsets','Y')
disp('Routine complete.')

NN = std(T_all - movmean(T_all,Nsamples,2),[],2);
MM = max(movmean(T_all,Nsamples,2),[],2);
Z = MM./NN;

figure; histogram(Z,0:0.2:20)
xlabel('Z-score')
ylabel('Neurons')
saveas(gcf,[path 'all_neuron_Zscore.fig'])

figure
histogram(100.*max(T_all,[],2))
xlabel('Max \DeltaF/F_0 (%)')
ylabel('Neurons')
saveas(gcf,[path 'all_neuron_maxDF.fig'])
