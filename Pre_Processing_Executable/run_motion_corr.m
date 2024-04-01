%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% run_motion_corr.m
%
% J.D. 05/19/2020
% F.O. 03/04/2024 - Added 24core option. Need checks for storage capacity.
% 
% For each file, import raw .tif files, assemble ROIs, 
% correct scan phase, re-order planes, and save a memory-mapped file.
% Access each plane in each file and concatenate in time
% Motion correct each plane and save to separate .tif files.
%
% Use the 'filePath' input argument to point to a local folder with raw
% .tif files
%
% Use the 'fileNameRoot' input argument to point toward the root for each
% file in the directory. The code will appeand '_00001.tif' to the end, so
% remove this suffix from the root.
%
% Each motion-corrected plane is saved as a separate .mat file with the following fields:
% Y: single plane recording data (x,y,T) (single)
% Ym: mean projection image of Y (x,y) (single)
% sizY: array with size of dimension of Y (1,3) 
% volumeRate: volume rate of the recording (1,1) (Hz)
% pixelResolution: size of each pixel in microns (1,1) (um)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function run_motion_corr(filePath,fileNameRoot,numCores, startPlane, endPlane)
<<<<<<< HEAD
    logFileName = sprintf('matlab_log_%d_%02d_%02d_%02d_%02d.txt', clck(1), clck(2), clck(3), clck(4), clck(5));
    logFullPath = fullfile(filePath, logFileName);
    fid = fopen(logFullPath, 'w');

    poolobj = gcp('nocreate');
    if ~isempty(poolobj)
        disp('Removing existing parallel pool.');
        delete(poolobj);
=======
    if ~exist([filePath fileNameRoot '_00001.mat'],'file')
        disp([filePath fileNameRoot '_00001.mat'])
        error('File does not exist.')
    fid = fopen(logFullPath, 'w');
>>>>>>> a0e497ffa0b0895f50819dc0ab5b283faa7907d2
    end

    tic
    addpath(genpath(fullfile('CaImAn-MATLAB-master', 'CaImAn-MATLAB-master')));
    addpath(genpath(fullfile('motion_correction/')));

    clck = clock; % use current time and date to make a log file
    disp('Beginning processing routine.');
    numCores = max(str2double(numCores), 23); % Ensure at least 23 cores or use specified number.

    fprintf(fid, '%s Beginning processing routine...\n', datetime);

    files = dir(fullfile(filePath, '*.mat'));
    fileNames = {files.name};
    relevantFiles = contains(fileNames, fileNameRoot) & ~contains(fileNames, 'plane');
    relevantFileNames = fileNames(relevantFiles);
    sprintf('Number of files to process: %d', num2str(length(relevantFileNames)))

    for fname=1:length(relevantFiles)
        disp(fname)
    end

    % Check if at least one relevant file is found
    if isempty(relevantFileNames)
        error('No relevant files found.');
    end

    % Pull dimensions from the file
    data = matfile(fullfile(filePath, relevantFileNames{1}), 'Writable',true);
    volumeRate = data.volumeRate;
    sizY = data.fullVolumeSize;
    pixelResolution = data.pixelResolution;
    d1 = sizY(1);
    d2 = sizY(2);
    numberOfPlanes = sizY(3);

    T = sizY(4);

    % fileInfo = h5info(fullfile(filePath, relevantFileNames{1}), '/data');
    % d1 = fileInfo.Dataspace.Size(1);
    % d2 = fileInfo.Dataspace.Size(2);
    % num_planes = fileInfo.Dataspace.Size(3);
    % T = fileInfo.Dataspace.Size(4); % Number of time points per file

    % preallocate based on the total number of time points across all files
    Y = zeros(d1, d2, T*length(relevantFileNames), 'single');
    for plane_idx = startPlane:endPlane
        sprintf('Loading plane %s', num2str(plane_idx))
        for file_idx = 1:numel(relevantFileNames)
            %% TODO: Make sure we have enough memory to store the frames from each file

            currentFileName = relevantFileNames{file_idx};

            %% TODO: Incorperate
            % h5FilePath = fullfile(filePath, currentFileName);
            % dataset = '/data';
            % start = [1, 1, plane_idx, 1];
            % count = [d1, d2, 1, total_T];
            %
            % % only the plane of interest for all timepoints from the current file
            % data = h5read(h5FilePath, '/data', [1, 1, plane_idx, 1], [d1, d2, 1, T]);
            % pixelResolution = h5readatt(h5FilePath, dataset, 'pixelResolution');
            % volumeRate = h5readatt(h5FilePath, dataset, 'volumeRate');
            % sizY = h5readatt(h5FilePath, dataset, 'fullVolumeSize');

            % Insert the read data into the pre-allocated array Y
            Y(:, :, (file_idx-1)*T+1:file_idx*T) = single(reshape(data.vol(:, :, plane_idx, :), d1, d2, T));
        end

        fprintf(fid, '%s Beginning processing for plane %s with %s matlab workers.', datetime, plane_idx);

        if size(gcp("nocreate"),1)==0
            parpool(numCores);
        end

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
        date = datetime(now,'ConvertFrom','datenum');
        formatSpec = '%s Rigid MC Complete, beginning non-rigid mc...\n';
        fprintf(fid,formatSpec,date);

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

        motionCorrectionFigure = figure;

        ax1 = subplot(311); plot(1:T,cY,1:T,cM1,1:T,cM2); legend('raw data','rigid','non-rigid'); title('correlation coefficients','fontsize',14,'fontweight','bold')
                set(gca,'Xtick',[])
        ax2 = subplot(312); %plot(shifts_x); hold on;
        plot(shifts_r(:,1),'--k','linewidth',2); title('displacements along x','fontsize',14,'fontweight','bold')
                set(gca,'Xtick',[])
        ax3 = subplot(313); %plot(shifts_y); hold on;
        plot(shifts_r(:,2),'--k','linewidth',2); title('displacements along y','fontsize',14,'fontweight','bold')
                xlabel('timestep','fontsize',14,'fontweight','bold')
        linkaxes([ax1,ax2,ax3],'x')

        % Figure: Motion correction Metrics
        saveas(motionCorrectionFigure,[filePath 'motion_corr_metrics_plane_' num2str(plane_idx) '.fig']);
        close(motionCorrectionFigure)

        Y = M2;
        clear M2 M1 cM1 cM2 template_good shifts1 shifts2 shifts_nr shifts_r shifts_x shifts_y cY

        tt = toc/3600;
        disp(['Motion correction complete. Time elapsed: ' num2str(tt) ' hours. Saving to disk...'])

        outputFile = [filePath fileNameRoot '_plane_' num2str(plane_idx) '.mat'];

        Ym = mean(Y,3);

        savefast(outputFile,'Y','volumeRate','sizY','pixelResolution','Ym')

        disp('Data saved, beginning next plane...')
        date = datetime(now,'ConvertFrom','datenum');
        formatSpec = '%s Motion Correction Complete. Beginning next plane...\n';
        fprintf(fid,formatSpec,date);
    end

    %% (III) Delete Remnants
    disp('All planes processed...')
    % for xyz = 1:numFiles
    %     if multiFile % if multiple files, append '_0000x.tif' or '_000xx.tif'
    %             if xyz < 10
    %                 fileName = [fileNameRoot '_0000' num2str(xyz) '.tif'];
    %             else
    %                 fileName = [fileNameRoot '_000'  num2str(xyz) '.tif'];
    %             end
    %         else % single file recording, append '.tif' to end
    %             fileName = [fileNameRoot '.tif'];
    %     end
    %
    %     delete([filePath fileName(1:end-3) 'mat'])
    %
    % end
    t = toc;
    disp(['Routine complete. Total run time ' num2str(t./3600) ' hours.'])
    date = datetime(now,'ConvertFrom','datenum');
    formatSpec = '%s Routine complete.';
    fprintf(fid,formatSpec,date);

end
