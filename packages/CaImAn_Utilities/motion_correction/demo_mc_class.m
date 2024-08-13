clc;
% gcp;

parent_path = fullfile("C:\Users\RBO\caiman_data\mk717\1um_72hz\extracted");
data_path = fullfile(parent_path, "extracted_plane_14.h5");
metadata = read_h5_metadata(data_path);

Y = single(h5read(data_path, '/Y'));

%% rigid motion correction 
clc;
MC_rigid = MotionCorrection(convertStringsToChars(data_path));
options_rigid = NoRMCorreSetParms('d1',MC_rigid.dims(1),'d2',MC_rigid.dims(2),'bin_width',50,'max_shift',15,'us_fac',50,'init_batch',200);
MC_rigid.motionCorrectSerial(options_rigid);  % can also try parallel

%% pw-rigid motion correction (in parallel)

MC_nonrigid = MotionCorrection(convertStringsToChars(data_path));
options_nonrigid = NoRMCorreSetParms('d1',MC_nonrigid.dims(1),'d2',MC_nonrigid.dims(2),'grid_size',[128,128],'mot_uf',4,'bin_width',50,'max_shift',100,'max_dev',4,'us_fac',50,'init_batch',200);
MC_nonrigid.motionCorrectSerial(options_nonrigid);

%% compute metrics

MC_rigid.correlationMean(10);
MC_rigid.crispness(10);
%% 
MC_nonrigid.correlationMean(10);
MC_nonrigid.crispness(10);

%% do some plotting
nnY = quantile(MC_rigid.meanY(:),0.005);
mmY = quantile(MC_rigid.meanY(:),0.995);
T = MC_rigid.T;
cY = MC_rigid.corrY;

cM1 = MC_rigid.corrM;
cM2 = MC_nonrigid.corrM;
%%
figure;
    title_y = sprintf("%0.2f", MC_rigid.crispY);
    title_r = sprintf("%0.2f", MC_rigid.crispM);
    title_nr = sprintf("%0.2f", MC_nonrigid.crispM);
    ax1 = subplot(2,3,1); imagesc(MC_rigid.meanY);  axis equal; axis tight; axis off; title(title_y,'fontsize',14,'fontweight','bold')
    ax2 = subplot(2,3,2); imagesc(MC_rigid.meanM);  axis equal; axis tight; axis off; title(title_nr,'fontsize',14,'fontweight','bold')
    ax3 = subplot(2,3,3); imagesc(MC_nonrigid.meanM,[nnY,mmY]); axis equal; axis tight; axis off; title(title_r,'fontsize',14,'fontweight','bold')
    subplot(2,3,4); plot(1:T,cY,1:T,cM1,1:T,cM2); legend('raw data','rigid','non-rigid'); title('correlation coefficients','fontsize',14,'fontweight','bold')
    subplot(2,3,5); scatter(cY,cM1); hold on; plot([0.9*min(cY),1.05*max(cM1)],[0.9*min(cY),1.05*max(cM1)],'--r'); axis square;
        xlabel('raw data','fontsize',14,'fontweight','bold'); ylabel('rigid corrected','fontsize',14,'fontweight','bold');
    subplot(2,3,6); scatter(cM1,cM2); hold on; plot([0.9*min(cY),1.05*max(cM1)],[0.9*min(cY),1.05*max(cM1)],'--r'); axis square;
        xlabel('rigid corrected','fontsize',14,'fontweight','bold'); ylabel('non-rigid corrected','fontsize',14,'fontweight','bold');
    linkaxes([ax1,ax2,ax3],'xy')
    
%% plot shifts

patch_id = 1:size(MC_nonrigid.shifts_x,2);
str = strtrim(cellstr(int2str(patch_id.')));
str = cellfun(@(x) ['patch # ',x],str,'un',0);

figure;
    ax1 = subplot(311); plot(1:T,cY,1:T,cM1,1:T,cM2); legend('raw data','rigid','non-rigid'); title('correlation coefficients','fontsize',14,'fontweight','bold')
            set(gca,'Xtick',[])
    ax2 = subplot(312); plot(MC_nonrigid.shifts_x); hold on; plot(MC_rigid.shifts_x,'--k','linewidth',2); title('displacements along x','fontsize',14,'fontweight','bold')
            set(gca,'Xtick',[])
    ax3 = subplot(313); plot(MC_nonrigid.shifts_y); hold on; plot(MC_rigid.shifts_y,'--k','linewidth',2); title('displacements along y','fontsize',14,'fontweight','bold')
            xlabel('timestep','fontsize',14,'fontweight','bold')
    linkaxes([ax1,ax2,ax3],'x'); legend(str);

 %%
 clc;

% Create figure
figure;

% First subplot
ax1 = subplot(311);
plot(1:T, cY, 1:T, cM1, 1:T, cM2);
legend('raw data', 'rigid', 'non-rigid');
title('correlation coefficients', 'fontsize', 14, 'fontweight', 'bold');
set(gca, 'Xtick', []);

% Second subplot with shaded error bars
ax2 = subplot(312);
hold on;
for i = 1:size(MC_nonrigid.shifts_x, 2)
    % Mean and standard deviation
    y = MC_nonrigid.shifts_x(:, i);
    mean_y = mean(y);
    std_y = std(y);
    
    % Shaded area
    fill([1:T, fliplr(1:T)], [mean_y + std_y, fliplr(mean_y - std_y)], 'b', 'FaceAlpha', 0.3, 'EdgeColor', 'none');
end
plot(1:T, mean(MC_nonrigid.shifts_x, 2), 'b');  % Plot the mean line
plot(1:T, MC_rigid.shifts_x, '--k', 'linewidth', 2);  % Plot the rigid line
title('displacements along x', 'fontsize', 14, 'fontweight', 'bold');
set(gca, 'Xtick', []);

% Third subplot with shaded error bars
ax3 = subplot(313);
hold on;
for i = 1:size(MC_nonrigid.shifts_y, 2)
    % Mean and standard deviation
    y = MC_nonrigid.shifts_y(:, i);
    mean_y = mean(y);
    std_y = std(y);
    
    % Shaded area
    fill([1:T, fliplr(1:T)], [mean_y + std_y, fliplr(mean_y - std_y)], 'r', 'FaceAlpha', 0.3, 'EdgeColor', 'none');
end
plot(1:T, mean(MC_nonrigid.shifts_y, 2), 'r');  % Plot the mean line
plot(1:T, MC_rigid.shifts_y, '--k', 'linewidth', 2);  % Plot the rigid line
title('displacements along y', 'fontsize', 14, 'fontweight', 'bold');
xlabel('timestep', 'fontsize', 14, 'fontweight', 'bold');

% Link the axes
linkaxes([ax1, ax2, ax3], 'x');
legend(ax2, str);  % Adding legend only to ax2

 %%

time = 0:0.01:10; % seconds, sampled at 100 Hz
data(:, :, 1) = bsxfun(@plus, sin(time), randn(100, length(time)));
data(:, :, 2) = bsxfun(@plus, cos(time), randn(100, length(time)));
 
colors = cbrewer('qual', 'Set2', 8);
 
subplot(4,4,[13 14]);  % plot across two subplots
hold on;
bl = boundedline(time, mean(data(:, :, 1)), std(data(:, :, 1)), ...
    time, mean(data(:, :, 2)), std(data(:, :, 2)), ...
    'cmap', colors);
% boundedline has an 'alpha' option, which makes the errorbars transparent
% (so it's nice when they overlap). However, when saving to pdf this makes
% the files HUGE, so better to keep your hands off alpha and make the final
% figure transparant in illustrator
 
xlim([-0.4 max(time)]); xlabel('Time (s)'); ylabel('Signal');
 
% instead of a legend, show colored text
lh = legend(bl);
legnames = {'sin', 'cos'};
for i = 1:length(legnames),
    str{i} = ['\' sprintf('color[rgb]{%f,%f,%f} %s', colors(i, 1), colors(i, 2), colors(i, 3), legnames{i})];
end
lh.String = str;
lh.Box = 'off';
 
% move a bit closer
lpos = lh.Position;
lpos(1) = lpos(1) + 0.15;
lh.Position = lpos;
 
% you'll still have the lines indicating the data. So far I haven't been
% able to find a good way to remove those, so you can either remove those
% in Illustrator, or use the text command to plot the legend (but then
% you'll have to specify the right x and y position for the text to go,
% which can take a bit of fiddling).
 
% we might want to add significance indicators, to show when the time
% courses are different from each other. In this case, use an uncorrected
% % t-test
% for t = 1:length(time)
%     [~, pval(t)] = ttest(data(:, t, 1), data(:, t, 2));
% end
% % convert to logical
% signific = nan(1, length(time)); 
% signific(pval &amp;amp;amp;amp;lt; 0.001) = 1;
% plot(time, signific * -3, '.k');
% % indicate what we're showing
% text(10.2, -3, 'p &amp;amp;amp;amp;lt; 0.001');