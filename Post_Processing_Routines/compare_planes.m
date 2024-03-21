clear
% close all
clc

% path = '\\v-storage.rockefeller.edu\vazirilab_medium_data\jeff_demas\MAxiMuM_data\20191122\mh89_2mm_FOV_50_550um_depth_250mW_som_stimuli_9min_00001\';
path = uigetdir;
path = [path '\'];

if size(strfind(path,'hemisphere'),1) > 0
    r_thr = 0.2;
    pixel_resolution = 5;
    min_snr = 1.4;%1.5;
    frameRate = 4.69;
elseif size(strfind(path,'2mm'),1) > 0
    r_thr = 0.4;
    pixel_resolution = 2.75;
    min_snr = 1.4;
    frameRate = 6.45;
elseif size(strfind(path,'0p9mm'),1) > 0
    r_thr = 0.4;
    pixel_resolution = 3;
    min_snr = 1.5;
    frameRate = 36.89;
elseif size(strfind(path,'0p6mm'),1) > 0
    r_thr = 0.4;
    pixel_resolution = 1;
    min_snr = 1.5;
    frameRate = 9.61;
end
            
merge_thr = 0.8;
ovp_thr = 0.0;
Kms = zeros(30,1);
num_corr_no_ovp = 0; 
num_ovlpd = 0;

p = load([path 'caiman_output_plane_1.mat']); % Load stuff from first p
rVals = p.rVals;

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
    A = p.A_keep(:,kp);
    K = size(T,1);
    Kms(1) = K;
    N = zeros(K,4);
    N(:,1) = sum(full(A))';
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

xxx = 1:size(Y,2);
yyy = 1:size(Y,1);
[XXX,YYY] = meshgrid(xxx,yyy);

cx = zeros(K,1);
cy = cx;

for aa = 1:K
    Ak = reshape(full(A(:,aa)),size(Y,1),size(Y,2));
    cx(aa) = round(trapz(trapz(XXX.*Ak))./trapz(trapz(Ak)));
    cy(aa) = round(trapz(trapz(YYY.*Ak))./trapz(trapz(Ak)));
end

N(:,2) = cx;
N(:,3) = cy;

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
    
    Tinit = pm.T_keep;
    [fitness] = compute_event_exceptionality(Tinit,Nsamples,0);
    
    clear Tinit
    
    rValsm = pm.rVals;

    kpm = logical(rValsm>r_thr & fitness<min_fitness);
    
    Tm = pm.T_keep(kpm,:);    
    Cm = pm.C_keep(kpm,:);
    Ym = pm.Ym;
    Am = pm.A_keep(:,kpm);
    Km = size(Tm,1);
    Kms(ijk) = Km;
    Nm = zeros(Km,4);
    Nm(:,1) = sum(full(Am))';
    Nm(:,4) = ijk;
    
    xxx = 1:size(Ym,2);
    yyy = 1:size(Ym,1);
    [XXX,YYY] = meshgrid(xxx,yyy);

    cxm = zeros(Km,1);
    cym = cxm;

    for aa = 1:Km
        Ak = reshape(full(Am(:,aa)),size(Ym,1),size(Ym,2));
        cxm(aa) = round(trapz(trapz(XXX.*Ak))./trapz(trapz(Ak)));
        cym(aa) = round(trapz(trapz(YYY.*Ak))./trapz(trapz(Ak)));
    end

    Nm(:,2) = cxm + cumsum(xo(ijk));
    Nm(:,3) = cym + cumsum(yo(ijk));
    
    RR = corr(T',Tm');
    MM = RR;
    MM(RR<merge_thr) = 0;
    
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
            
            num = round(10/pixel_resolution);
            
            AOIk = full(reshape(A(:,k),size(Y,1),size(Y,2)));
            
            numx = max([num abs(offsets(ijk-1,2))]);
            numy = max([num abs(offsets(ijk-1,1))]);
            
            yS = max([cy(k)-numy 1]);
            yE = min([cy(k)+numy size(AOIk,1)]);
            xS = max([cx(k)-numx 1]);
            xE = min([cx(k)+numx size(AOIk,2)]);
            
            AOIk = AOIk(yS:yE,xS:xE);
            AOIk = AOIk./trapz(trapz(AOIk));
            
            AOIkm = full(reshape(Am(:,km),size(Ym,1),size(Ym,2)));
            
            try
                AOIkm = AOIkm(yS+offsets(ijk,1):yE+offsets(ijk,1),xS+offsets(ijk,2):xE+offsets(ijk,2));
                AOIkm = AOIkm./trapz(trapz(AOIkm));

                ovp = abs(trapz(trapz(sqrt(AOIk.*AOIkm)))).^2;
            catch
                ovp = 0;
            end
            
            if ovp_thr>0
                overlapped = ovp>ovp_thr;
            else
                overlapped = sum(sum(AOIkm))>0;
            end
            
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
    cx = cxm;
    cy = cym;
    clear pm Tm Ym Cm RR MM XX Am Nm xxx XXX yyy YYY

end

is = ~isnan(sum(T_all,2));
T_all = T_all(is,:);
C_all = C_all(is,:);
N_all = N_all(is,:);

disp('Planes collated. Saving data...')
save([path 'collated_caiman_output_minSNR_1p4.mat'],'T_all','N_all','C_all','offsets','-v7.3')
disp('Routine complete.')