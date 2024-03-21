clear
close all
clc

path = '\\v-storage\vazirilab_medium_data\jeff_demas\Simulation_project\Current_version\Ground_truths\';

% file = 'mb48_chameleon_960nm_z300um_p110mW_00001_00003.tif';
% file = 'mb47_chameleon_960nm_z450um_p148mW_300umFOV_00001_00005.tif';
% file = 'mb47_chameleon_960nm_z300um_p72mW_300umFOV_00001_00001.tif';

files = dir([path,'*.tif']);
N ={files.name};

RMSx = zeros(1,size(N,2));
RMSy = RMSx;

for abc = 1:size(N,2)

    file = N{:,abc};
    
    addpath(genpath('C:\Users\jdemas\Documents\MATLAB\ScanImageTiffReader\share\matlab\'))
    addpath(genpath('\\v-storage\vazirilab_medium_data\jeff_demas\PROCESSING_SCRIPTS\Pre_Processing_Executable\motion_correction\'))

    vol = ScanImageTiffReader([path file]).data();
    vol = vol(:,:,1:4:end);

    sampling = [1 6 10];

    cYs = zeros(size(vol,3),3);
    cM1s = cYs;
    cM2s = cYs;
    shiftsx = cYs;
    shiftsy = cYs;

    for j = 1:3

        pixelResolution = 0.5.*sampling(j);

        Y = vol(1:sampling(j):end,1:sampling(j):end,:);

        [d1,d2,T] = size(Y);

        gcp;

        % Rigid motion correction using NoRMCorre algorithm:    
        options_rigid = NoRMCorreSetParms(...
            'd1',d1,...
            'd2',d2,...
            'bin_width',200,...       % Bin width for motion correction
            'max_shift',round(20/pixelResolution),...        % Max shift in px
            'us_fac',20,...
            'init_batch',200,...     % Initial batch size
            'correct_bidir',false... % Correct bidirectional scanning
            );

        [M1,shifts1,~,~] = normcorre_batch(Y,options_rigid);

        disp('Rigid motion correction complete. Beginning non-rigid motion correction...')

        shifts_r = squeeze(cat(3,shifts1(:).shifts));
        shifts_v = movvar(shifts_r,24,1);
        %     [~,minv_idx] = mink(shifts_v,120,1);
        [srt,minv_idx] = sort(shifts_v,120); 
        best_idx = unique(reshape(minv_idx,1,[]));
        template_good = mean(M1(:,:,best_idx),3);

        % No rigid motion correction using the good tamplate from the rigid
        % correction.
          options_nonrigid = NoRMCorreSetParms(...
            'd1',d1,...
            'd2',d2,...
            'bin_width',24,...
            'max_shift',round(20/pixelResolution),...
            'us_fac',20,...
            'init_batch',120,...
            'correct_bidir',false...
            );

        % Data from the motion correction that will be used for the CNMF
        [M2,shifts2,~,~] = normcorre_batch(Y,options_nonrigid,template_good);

        disp('Calculating motion correction metrics...')

        shifts_r = squeeze(cat(3,shifts1(:).shifts));
        shifts_nr = cat(ndims(shifts2(1).shifts)+1,shifts2(:).shifts);
        shifts_nr = reshape(shifts_nr,[],ndims(Y)-1,T);
        shifts_x = squeeze(shifts_nr(:,1,:))';
        shifts_y = squeeze(shifts_nr(:,2,:))';

        [cY,~,~] = motion_metrics(Y,10);
        [cM1,~,~] = motion_metrics(M1,10);
        [cM2,~,~] = motion_metrics(M2,10);

        cYs(:,j) = cY;
        cM1s(:,j) = cM1;
        cM2s(:,j) = cM2;
        shiftsx(:,j) = shifts_r(:,1);
        shiftsy(:,j) = shifts_r(:,2);
    end

    %%

    figure
    subplot(2,1,1)
    plot(linspace(0,120,T),0.5.*shiftsx.*(ones(T,1)*[1 6 10]))
    xlabel('Time (s)')
    ylabel('Pixel shift in X (\mum)')

    % figure;
    subplot(2,1,2)
    plot(linspace(0,120,T),0.5.*shiftsy.*(ones(T,1)*[1 6 10]))
    xlabel('Time (s)')
    ylabel('Pixel shift in Y (\mum)')

    saveas(gcf,[file(1:end-4) '_shifts_vs_sampling.fig'])

    RMSx(abc) = sqrt(mean(abs(shiftsx(:,1)-shiftsx(:,3)).^2));
    RMSy(abc) = sqrt(mean(abs(shiftsy(:,1)-shiftsy(:,3)).^2));

end

figure;
bar(RMSx)
hold on
bar(RMSy)
