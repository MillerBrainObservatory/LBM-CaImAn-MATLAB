
Y = tiffreadVolume(fullfile("C:\Users\RBO\caiman_data\M07\M01_C351_Depth1046um_Pw10mW_00001_phaseCorrGreen.tif"));
%%
filtered = imgaussfilt(Y,1, 'FilterDomain','frequency');
%%

Y = Y(:, :, 20:end);

fig_save_path = fullfile('../../Pictures/');
fig_plane_name = sprintf("%s/test_grid_32", fig_save_path);

%%
mcFeat = imopen(Y, strel('disk',2));

%%

% poolobj = gcp("nocreate"); % If no pool, do not create new one.
% if isempty(poolobj)
%     log_message(fid, "Initializing parallel cluster with %d workers.\n", num_cores);
%     clust=parcluster('local');
%     clust.NumWorkers=num_cores;
%     parpool(clust,num_cores, 'IdleTimeout', 30);
% end

volume_size = size(Y);
d1 = volume_size(1);
d2 = volume_size(2);
pixel_resolution = 3;
frame_rate = 30;

options_rigid = NoRMCorreSetParms(...
    'd1',d1,...
    'd2',d2,...
    'fr', frame_rate, ...
    'bin_width',200,...
    'max_shift', round(20/pixel_resolution),...        % Max shift in px
    'us_fac', 20,...                  % upsample factor
    'init_batch',200,...              % frames used to create template
    'correct_bidir', false...         % DONT Correct bidirectional scanning
    );

% start timer for registration after parpool to avoid inconsistent
% pool startup times.
t_rigid=tic;

[M1,shifts1,~,~] = normcorre_batch(Y, options_rigid);

%%

% create the template using X/Y shift displacements
% with the least variance
shifts_r = squeeze(cat(3,shifts1(:).shifts));
shifts_v = movvar(shifts_r, 24, 1);
[~, minv_idx] = sort(shifts_v, 120);
best_idx = unique(reshape(minv_idx, 1, []));
template_good = mean(M1(:,:,best_idx), 3);

%%
% % Non-rigid motion correction using the good template from the rigid
options = NoRMCorreSetParms(...
    'd1', d1,...
    'd2', d2,...
    'fr', frame_rate, ...
    'bin_width', 20,...
    'grid_size', [32,32], ...
    'max_shift', round(100/pixel_resolution),...
    'us_fac', 5,...
    'init_batch', 200,...
    'iter', 1, ...
    'correct_bidir', false...
    );

[M2, shifts2, ~, ~] = normcorre_batch(Y, options, template_good);
%%


metrics_name_png = sprintf("%s_metrics.png", fig_plane_name);
[cY,mY,~] = motion_metrics(Y,10);
[cM1,mM1,~] = motion_metrics(M1,10);
[cM2,mM2,~] = motion_metrics(M2,10);
T = length(cY);

f = figure('Visible', 'off', 'Units', 'normalized', 'OuterPosition', [0 0 1 1]);

ax1 = subplot(2, 3, 1); imagesc(mY); axis equal; axis tight; axis off;
title('Mean raw', 'fontsize',10,'fontweight','bold', 'Color', 'w');

ax2 = subplot(2, 3, 2); imagesc(mM1); axis equal; axis tight; axis off;
title('Mean rigid template', 'fontsize',10,'fontweight','bold', 'Color', 'w');

ax3 = subplot(2, 3, 3); imagesc(mM2); axis equal; axis tight; axis off;
title('Mean registered', 'Color', 'w', 'FontWeight', 'bold');

subplot(2, 3, 4); plot(1:T, cY, 1:T, cM1, 1:T, cM2); legend('Raw', 'Template', 'Registered');
title('Correlation coefficients', 'Color', 'w', 'FontWeight', 'bold');
subplot(2, 3, 5); scatter(cY, cM1); hold on;
plot([0.9 * min(cY), 1.05 * max(cM1)], [0.9 * min(cY), 1.05 * max(cM1)], '--r'); axis square;
title('Template vs Raw Correlation','fontsize',10,'fontweight','bold', 'Color', 'w');
xlabel('Raw data correlation', 'fontsize',10,'fontweight','bold', 'Color', 'w');
ylabel('Template data correlation', 'fontsize',10,'fontweight','bold', 'Color', 'w');

subplot(2, 3, 6); scatter(cM1, cM2,  'MarkerEdgeColor', 'w'); hold on;
title('Registered vs Template Correlation','fontsize',10,'fontweight','bold', 'Color', 'w');
plot([0.9 * min(cY), 1.05 * max(cM1)], [0.9 * min(cY), 1.05 * max(cM1)], '--r'); axis square;
xlabel('Rigid template', 'Color', 'w', 'FontWeight', 'bold'); ylabel('Non-rigid correlation', 'Color', 'w', 'FontWeight', 'bold');
linkaxes([ax1, ax2, ax3], 'xy');

exportgraphics(f, metrics_name_png, 'Resolution', 600);
close(f);

shifts_nr = cat(ndims(shifts2(1).shifts)+1,shifts2(:).shifts);
shifts_nr = reshape(shifts_nr,[],ndims(Y)-1,T);
shifts_x = squeeze(shifts_nr(:,1,:))';
shifts_y = squeeze(shifts_nr(:,2,:))';

shifts_name_png = sprintf("%s_shifts.png", fig_plane_name);

f = figure;
ax1 = subplot(311); plot(1:T,cY,1:T,cM1,1:T,cM2);

title('Correlation coefficients', 'Color', 'w', 'FontWeight', 'bold');

% Set the figure background to black
set(gcf, 'Color', 'black');

% Set the axes background to black, axis lines and labels to white, and add a white border
set(gca, 'Color', 'black', 'XColor', 'white', 'YColor', 'white', 'Box', 'on', 'LineWidth', 1);

% Adjust the legend properties
legend('Raw data', 'Template', 'Registered', ...
    'TextColor', 'white', 'EdgeColor', 'white', 'FontSize', 8, 'Color', 'black', 'FontWeight', 'bold');
set(gca,'Xtick',[])
ax2 = subplot(312); plot(shifts_x, 'LineWidth',.2); title('displacements along x', 'Color', 'w', 'FontWeight', 'bold')
set(gca,'Xtick',[])
ax3 = subplot(313); plot(shifts_y); title('displacements along y', 'Color', 'w', 'FontWeight', 'bold')
xlabel('timestep', 'Color', 'w', 'FontWeight', 'bold')
linkaxes([ax1,ax2,ax3],'x')
exportgraphics(f,shifts_name_png, 'Resolution', 600);
close(f);


%%


