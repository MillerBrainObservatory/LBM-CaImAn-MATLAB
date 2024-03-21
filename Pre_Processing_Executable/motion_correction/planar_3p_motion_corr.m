%% Load file and pre-process
% clear
% gcp;
% 
% file = 'MB19_3p_d1130_p75_00001.hdf5';
% Y = h5read(file,'/mov');
timepoints = size(Y,3);
% Y = single(Y);


%% set parameters (first try out rigid motion correction)
options_rigid = NoRMCorreSetParms('d1',size(Y,1),'d2',size(Y,2),'bin_width',24,'max_shift',8,'us_fac',20,'init_batch',120,'correct_bidir',false);
tic; [M1,shifts1,template1,options_rigid] = normcorre(Y,options_rigid); toc


%% now try non-rigid motion correction (also in parallel)
options_nonrigid = NoRMCorreSetParms('d1',size(Y,1),'d2',size(Y,2),'grid_size',[32,32],'mot_uf',4,'bin_width',24,'max_shift',8,'max_dev',3,'us_fac',20,'init_batch',120,'correct_bidir',false);
tic; [M2,shifts2,template2,options_nonrigid] = normcorre(Y,options_nonrigid); toc


%% compute metrics

nnY = quantile(Y(:),0.005);
mmY = quantile(Y(:),0.995);

[cY,mY,vY] = motion_metrics(Y,[10,10,10,10,2,2]);
[cM1,mM1,vM1] = motion_metrics(M1,[10,10,10,10,2,2]);
[cM2,mM2,vM2] = motion_metrics(M2,[10,10,10,10,2,2]);
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
    ax1 = subplot(311); plot(1:T,cY,1:T,cM1,1:T,cM2); legend('Raw data','Rigid','Non-rigid'); title('Correlation coefficients')
            set(gca,'Xtick',[])
    ax2 = subplot(312); plot(3.4.*shifts_x); hold on; plot(3.4.*shifts_r(:,1),'--k'); title('Displacements along x')
            set(gca,'Xtick',[])
    ax3 = subplot(313); plot(3.4.*shifts_y); hold on; plot(3.4.*shifts_r(:,2),'--k'); title('Displacements along y')
            xlabel('Frames')
    linkaxes([ax1,ax2,ax3],'x')


%% Save data
[~,fname,~] = fileparts(file);
[x,y,z,t] = size(Y);
h5create([fname,'_mc.hdf5'],'/mov',[x y z t]);
h5write([fname,'_mc.hdf5'], '/mov', M1);
%h5create([fname,'_mc.hdf5'],'/m1',[x y z t]);
%h5write([fname,'_mc.hdf5'], '/m1', M1);
