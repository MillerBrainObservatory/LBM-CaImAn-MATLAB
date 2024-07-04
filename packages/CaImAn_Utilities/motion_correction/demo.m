clear; clc;
% gcp;

parent_path = fullfile("C:/Users/RBO/Documents/data/high_res/v1.8/extracted/");
data_path = fullfile(parent_path, "extracted_plane_1.h5");
metadata = read_h5_metadata(data_path);
Y = single(read_plane(data_path)); % convert to single precision 
Y = Y - min(Y(:));

%% set parameters for rigid motion correction

options_rigid = NoRMCorreSetParms('d1',size(Y,1),'d2',size(Y,2),'bin_width',200,'max_shift',10,'us_fac',50,'init_batch',200);
tic; [M1,shifts1,template1,options_rigid] = normcorre(Y,options_rigid); toc

options_nonrigid = NoRMCorreSetParms('d1',size(Y,1),'d2',size(Y,2),'grid_size',[32,32],'mot_uf',4,'bin_width',200,'max_shift',15,'max_dev',3,'us_fac',50,'init_batch',200);
tic; [M2,shifts2,template2,options_nonrigid] = normcorre_batch(Y,options_nonrigid); toc

% cY:           correlation coefficient of each frame with the mean
% mY:           mean image
% ng:           norm of gradient of mean image

[cY,mY,~] = motion_metrics(Y,10);
[cM1,mM1,~] = motion_metrics(M1,10);
[cM2,mM2,~] = motion_metrics(M2,10);
T = length(cY);

f = figure('Visible', 'off', 'Units', 'normalized', 'OuterPosition', [0 0 1 1]);
ax1 = subplot(2, 3, 1); imagesc(mY); axis equal; axis tight; axis off; 
title('mean raw data', 'fontsize', 10, 'fontweight', 'bold');

ax2 = subplot(2, 3, 2); imagesc(mM1); axis equal; axis tight; axis off; 
title('mean rigid corrected', 'fontsize', 10, 'fontweight', 'bold');
ax3 = subplot(2, 3, 3); imagesc(mM2); axis equal; axis tight; axis off; 
title('mean non-rigid corrected', 'fontsize', 10, 'fontweight', 'bold');
subplot(2, 3, 4); plot(1:T, cY, 1:T, cM1, 1:T, cM2); legend('raw data', 'rigid', 'non-rigid'); 
title('correlation coefficients', 'fontsize', 10, 'fontweight', 'bold');
subplot(2, 3, 5); scatter(cY, cM1); hold on; 
plot([0.9 * min(cY), 1.05 * max(cM1)], [0.9 * min(cY), 1.05 * max(cM1)], '--r'); axis square;
xlabel('raw data', 'fontsize', 10, 'fontweight', 'bold'); ylabel('rigid corrected', 'fontsize', 10, 'fontweight', 'bold');
subplot(2, 3, 6); scatter(cM1, cM2); hold on; 
plot([0.9 * min(cY), 1.05 * max(cM1)], [0.9 * min(cY), 1.05 * max(cM1)], '--r'); axis square;
xlabel('rigid corrected', 'fontsize', 10, 'fontweight', 'bold'); ylabel('non-rigid corrected', 'fontsize', 10, 'fontweight', 'bold');
linkaxes([ax1, ax2, ax3], 'xy');
exportgraphics(f, fullfile(parent_path,"metrics.png"), 'Resolution', 600,'BackgroundColor','k');
close(f);

%% plot shifts        

shifts_r = squeeze(cat(3,shifts1(:).shifts));
shifts_nr = cat(ndims(shifts2(1).shifts)+1,shifts2(:).shifts);
shifts_nr = reshape(shifts_nr,[],ndims(Y)-1,T);
shifts_x = squeeze(shifts_nr(:,1,:))';
shifts_y = squeeze(shifts_nr(:,2,:))';

f = figure("Visible","off");
    ax1 = subplot(311);
    plot(1:T,cY,1:T,cM1,1:T,cM2); legend('raw data','rigid','non-rigid');
    title('correlation coefficients','fontsize',8,'fontweight','bold')
            set(gca,'Xtick',[])
    ax2 = subplot(312);
    plot(shifts_x); hold on; plot(shifts_r(:,1),'--r','linewidth',2);
    title('displacements along x','fontsize',8,'fontweight','bold')
            set(gca,'Xtick',[])
    ax3 = subplot(313);
    plot(shifts_y); hold on; plot(shifts_r(:,2),'--r','linewidth',2);
    title('displacements along y','fontsize',8,'fontweight','bold')
            xlabel('timestep','fontsize',8,'fontweight','bold')
linkaxes([ax1,ax2,ax3],'x')
exportgraphics(f, fullfile(parent_path,"shifts.png"), 'Resolution', 600, 'BackgroundColor', 'k');
close(f);

%% save movie with videowriter object
% Create a VideoWriter object
clc; close(gcf);
video_filename = fullfile(parent_path, 'registration_results.avi');
v = VideoWriter(video_filename);
v.FrameRate = metadata.frame_rate;
open(v);

fig = figure;
for t = 1:T
    subplot(121); imagesc(Y(:,:,t));
    xlabel('raw data', 'fontsize', 8, 'fontweight', 'bold'); axis equal; axis tight;
    title(sprintf('Frame %i out of %i', t, T), 'fontweight', 'bold', 'fontsize', 8);
    colormap('gray');
    
    subplot(122); imagesc(M2(:,:,t));
    xlabel('non-rigid corrected', 'fontsize', 8, 'fontweight', 'bold'); axis equal; axis tight;
    title(sprintf('Frame %i out of %i', t, T), 'fontweight', 'bold', 'fontsize', 8);
    colormap('gray');
    
    set(gca, 'XTick', [], 'YTick', []);
    frame = getframe(fig);
    writeVideo(v, frame);
end
close('all');
fprintf('Video saved to %s\n', video_filename);