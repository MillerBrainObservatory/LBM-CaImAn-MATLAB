% Load correction movie 
h5_corrected = sprintf('C:/Users/RBO/Documents/data/high_res/corrected_gt/motion_corrected_plane_%d.h5', 1);
h5_extracted = sprintf('C:/Users/RBO/Documents/data/high_res/extracted_gt/extracted_plane_%d.h5', 1);
data_corr = h5read(h5_corrected, '/mov');
data_extr = h5read(h5_extracted, '/Y_gt');

img_frame = data_corr(:,:,200);
[r, c] = find(img_frame == max(img_frame(:)));
[slicey, slicex] = get_central_indices(img_frame,r,c,200);
new = [data_corr(slicey, slicex, 2:402) data_extr(slicey, slicex, 2:402)];
planeToMovie(new, save_path, 10);

%%

T = size(Y,ndims(Y));
%Y = Y - min(Y(:));

options_rigid = NoRMCorreSetParms('d1',size(Y,1),'d2',size(Y,2),'bin_width',200,'max_shift',10,'us_fac',50,'init_batch',200);

%% perform motion correction
tic; [M1,shifts1,template1,options_rigid] = normcorre(Y,options_rigid); toc

%% now try non-rigid motion correction (also in parallel)
options_nonrigid = NoRMCorreSetParms('d1',size(Y,1),'d2',size(Y,2),'grid_size',[32,32],'mot_uf',4,'bin_width',200,'max_shift',10,'max_dev',3,'us_fac',50,'init_batch',200);
tic; [M2,shifts2,template2,options_nonrigid] = normcorre_batch(Y,options_nonrigid); toc

%% plot metrics

nnY = quantile(Y(:),0.005);
mmY = quantile(Y(:),0.995);

[cY,mY,vY] = motion_metrics(Y,10);
[cM1,mM1,vM1] = motion_metrics(M1,10);
[cM2,mM2,vM2] = motion_metrics(M2,10);

T = length(cY);

figure;
ax1 = subplot(2,3,1); imagesc(mY,[nnY,mmY]);  axis equal; axis tight; axis off; title('mean raw data','fontsize',14,'fontweight','bold')
ax3 = subplot(2,3,3); imagesc(mM2,[nnY,mmY]); axis equal; axis tight; axis off; title('mean non-rigid corrected','fontsize',14,'fontweight','bold')
subplot(2,3,4); plot(1:T,cY,1:T,cM1,1:T,cM2); legend('raw data','rigid','non-rigid'); title('correlation coefficients','fontsize',14,'fontweight','bold')
subplot(2,3,5); scatter(cY,cM1); hold on; plot([0.9*min(cY),1.05*max(cM1)],[0.9*min(cY),1.05*max(cM1)],'--r'); axis square;
xlabel('raw data','fontsize',14,'fontweight','bold'); ylabel('rigid corrected','fontsize',14,'fontweight','bold');
subplot(2,3,6); scatter(cM1,cM2); hold on; plot([0.9*min(cY),1.05*max(cM1)],[0.9*min(cY),1.05*max(cM1)],'--r'); axis square;
xlabel('rigid corrected','fontsize',14,'fontweight','bold'); ylabel('non-rigid corrected','fontsize',14,'fontweight','bold');
linkaxes([ax1,ax2,ax3],'xy')
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

%% plot a movie with the results

figure;
for t = 1:1:T
    subplot(121);imagesc(Y(:,:,t),[nnY,mmY]); xlabel('raw data','fontsize',14,'fontweight','bold'); axis equal; axis tight;
    title(sprintf('Frame %i out of %i',t,T),'fontweight','bold','fontsize',14); colormap('bone')
    subplot(122);imagesc(M2(:,:,t),[nnY,mmY]); xlabel('non-rigid corrected','fontsize',14,'fontweight','bold'); axis equal; axis tight;
    title(sprintf('Frame %i out of %i',t,T),'fontweight','bold','fontsize',14); colormap('bone')
    set(gca,'XTick',[],'YTick',[]);
    drawnow;
    pause(0.02);
end

% gtY = gt_extracted.Y;
% Ym = mean(Y, 3);
% gtYm = gt_extracted.Ym;

%% 
p=figure; 
subplot(2,3,1); imagesc(Y(:,:,2)); axis image; title("Second Frame: V2-Pipeline"); set(gca,'Xtick',[]);
subplot(2,3,2); imagesc(gtY(:,:,2)); axis image; title("Second Frame: Ground Truth"); set(gca,'Xtick',[]);
subplot(2,3,3); imagesc(Ym(:,:)); axis image; title("Mean Image: V2-Pipeline"); set(gca,'Xtick',[]);
subplot(2,3,4); imagesc(gtYm(:,:)); axis image; title("Mean Image: Ground Truth"); set(gca,'Xtick',[]);
subplot(2,3,5); imshowpair(Ym, gtYm, 'diff'); axis image; title("Difference: Mean Image"); set(gca,'XTick',[]);
subplot(2,3,6); imshowpair(Y(:,:,2), gtY(:,:,2), 'diff'); axis image; title("Difference: Second Frame"); set(gca,'XTick',[]);
saveas(p, "C:\Users\RBO\Documents\data\bi_hemisphere\registration\figures\ground_truth_comparison_with_diffs.png");

%%
% Create a figure
p = figure;

% Define the positions for the subplots
positions = [
    0.05, 0.55, 0.3, 0.43;  % [left, bottom, width, height]
    0.37, 0.55, 0.3, 0.43;
    0.69, 0.55, 0.3, 0.43;
    0.05, 0.05, 0.3, 0.43;
    0.37, 0.05, 0.3, 0.43;
    0.69, 0.05, 0.3, 0.43
];

% Subplot 1: Second Frame: V2-Pipeline
subplot('Position', positions(1,:));
imagesc(Y(:,:,2)); 
axis image; 
title("Second Frame: V2-Pipeline"); 
set(gca, 'XTick', [], 'YTick', []);

% Subplot 2: Second Frame: Ground Truth
subplot('Position', positions(2,:));
imagesc(gtY(:,:,2)); 
axis image; 
title("Second Frame: Ground Truth"); 
set(gca, 'XTick', [], 'YTick', []);

% Subplot 3: Difference between Second Frames
subplot('Position', positions(3,:));
imshowpair(Y(:,:,2), gtY(:,:,2), 'diff');
axis image; 
title("Difference: Second Frame"); 
set(gca, 'XTick', [], 'YTick', []);

% Subplot 4: Mean Image: Ground Truth
subplot('Position', positions(4,:));
imagesc(gtYm(:,:)); 
axis image; 
title("Mean Image: Ground Truth"); 
set(gca, 'XTick', [], 'YTick', []);

% Subplot 5: Mean Image: V2-Pipeline
subplot('Position', positions(5,:));
imagesc(Ym(:,:)); 
axis image; 
title("Mean Image: V2-Pipeline"); 
set(gca, 'XTick', [], 'YTick', []);

% Subplot 6: Difference between Mean Images
subplot('Position', positions(6,:));
imshowpair(Ym, gtYm, 'diff');
axis image; 
title("Difference: Mean Image"); 
set(gca, 'XTick', [], 'YTick', []);

% Save the figure
saveas(p, "C:\\Users\\RBO\\Documents\\data\\bi_hemisphere\\registration\\figures\\ground_truth_comparison_with_diffs.png");
%% 

figure;
for t = 1:1:T
    subplot(121);imagesc(Y(:,:,t),[nnY,mmY]); xlabel('raw data','fontsize',14,'fontweight','bold'); axis equal; axis tight;
    title(sprintf('Frame %i out of %i',t,T),'fontweight','bold','fontsize',14); colormap('bone')
    subplot(122);imagesc(M2(:,:,t),[nnY,mmY]); xlabel('non-rigid corrected','fontsize',14,'fontweight','bold'); axis equal; axis tight;
    title(sprintf('Frame %i out of %i',t,T),'fontweight','bold','fontsize',14); colormap('bone')
    set(gca,'XTick',[],'YTick',[]);
    drawnow;
    pause(0.02);
end
