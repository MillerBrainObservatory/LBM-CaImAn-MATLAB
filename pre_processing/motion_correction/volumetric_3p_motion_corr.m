%% Load file and pre-process
clear
gcp;

Y = permute(data_4d,[1,2,4,3]);

%% set parameters (first try out rigid motion correction)
options_rigid = NoRMCorreSetParms('d1',size(Y,1),'d2',size(Y,2),'d3',size(Y,3),'bin_width',24,'max_shift',[8,8,2],'us_fac',20,'init_batch',120,'correct_bidir',false);
tic; [M1,shifts1,template1,options_rigid] = normcorre_batch(Y,options_rigid); toc

%% Compute template from the best frames:
shifts_r = squeeze(cat(3,shifts1(:).shifts));
shifts_v = movvar(shifts_r,24,1);
[~,minv_idx] = mink(shifts_v,120,1);
best_idx = unique(reshape(minv_idx,1,[]));
template_good = mean(M1(:,:,:,best_idx),4);

%% now try non-rigid motion correction (also in parallel)
options_nonrigid = NoRMCorreSetParms('d1',size(Y,1),'d2',size(Y,2),'d3',size(Y,3),'grid_size',[32,32],'mot_uf',4,'bin_width',24,'max_shift',[8,8,2],'max_dev',3,'us_fac',20,'init_batch',120,'correct_bidir',false);
tic; [M2,shifts2,template2,options_nonrigid] = normcorre_batch(Y,options_nonrigid,template_good); toc


%% compute metrics

nnY = quantile(Y(:),0.005);
mmY = quantile(Y(:),0.995);

[cY,mY,vY] = motion_metrics(Y,[10,10,10,10,2,2]);
[cM1,mM1,vM1] = motion_metrics(M1,[10,10,10,10,2,2]);
%[cM2,mM2,vM2] = motion_metrics(M2,[10,10,10,10,2,2]);
T = length(cY);


%% plot shifts        

shifts_r = squeeze(cat(3,shifts1(:).shifts));
shifts_nr = cat(ndims(shifts2(1).shifts)+1,shifts2(:).shifts);
shifts_nr = reshape(shifts_nr,[],ndims(Y)-1,T);
shifts_x = squeeze(shifts_nr(:,1,:))';
shifts_y = squeeze(shifts_nr(:,2,:))';

patch_id = 1:size(shifts_x,2);
str = strtrim(cellstr(int2str(patch_id.')));
str = cellfun(@(x) ['patch # ',x],str,'un',0);

figure;
    ax1 = subplot(311); plot(1:T,cY,1:T,cM1,1:T,cM2); legend('raw data','rigid','non-rigid'); title('correlation coefficients','fontsize',14,'fontweight','bold')
            set(gca,'Xtick',[])
    ax2 = subplot(312); plot(shifts_x); hold on; plot(shifts_r(:,1),'--k','linewidth',2); title('displacements along x','fontsize',14,'fontweight','bold')
            set(gca,'Xtick',[])
    ax3 = subplot(313); plot(shifts_y); hold on; plot(shifts_r(:,2),'--k','linewidth',2); title('displacements along y','fontsize',14,'fontweight','bold')
            xlabel('timestep','fontsize',14,'fontweight','bold')
    linkaxes([ax1,ax2,ax3],'x')


%% Save data
[~,fname,~] = fileparts(file);
[x,y,z,t] = size(Y);
h5create([fname,'_mc.hdf5'],'/mov',[x y z t]);
h5write([fname,'_mc.hdf5'], '/mov', M1);
%h5create([fname,'_mc.hdf5'],'/m1',[x y z t]);
%h5write([fname,'_mc.hdf5'], '/m1', M1);
