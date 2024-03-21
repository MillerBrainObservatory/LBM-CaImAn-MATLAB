%% 

clear 
close all
clc

% path = '\\v-storage2.rockefeller.edu\v-data2\jeff_demas\MAxiMuM_data\20200908\MH148_600um_FOV_neg100_350um_depth_250mW_9min_whisker_stim\'; 
% filestem = 'MH148_600um_FOV_neg100_350um_depth_250mW_9min_whisker_stim_00001';

% path = '\\v-storage2.rockefeller.edu\v-data2\jeff_demas\MAxiMuM_data\20200908\MH148_600um_FOV_0_451um_depth_250mW_9min_whisker_stim\'; 
path = 'E:\Data\tempData\';
filestem = 'MH148_600um_FOV_0_450um_depth_250mW_9min_whisker_stim_00001';

spath = 'E:\Jeff\MAxiMuM_processing\';

Ns = [19];

for abc = 1:numel(Ns)
    N = Ns(abc);

    load([path filestem '_plane_' num2str(N) '.mat'])

    ny = sizY(1); nx = sizY(2); nt = sizY(3);
    numAvgs = ceil(volumeRate);
    poi = movmean(Y,numAvgs,3);
    clear Y

    if ny/2 ~= round(ny/2)
        poi = poi(1:end-1,:,:); ny = ny-1;
    end

    if nx/2 ~= round(nx/2)
        poi = poi(:,1:end-1,:); nx = nx-1;
    end

    %% Make movie

    frameRate = 25;
    startframe = 3901;
    ds = 2;
    endframe = startframe-1+round(120*volumeRate);

    [n,edgs] = histcounts(poi(:),'normalization','cdf');
    ind1 = dsearchn(n',0.1);
    mn = edgs(ind1);
    ind2 = dsearchn(n',0.999);
    mx = edgs(ind2);

    figure;
    imagesc(poi(:,:,100));
    colormap(gray)
    axis image
    caxis([mn mx])

    % mx = 12500; mn = 300;

    filename = [spath 'movie_2min_plane_' num2str(N) '.avi'];

    writerObj = VideoWriter(filename,'Uncompressed AVI');
    writerObj.FrameRate = volumeRate*4./ds;
    % writerObj.Quality = 100;
    open(writerObj);

    x = linspace(0,600,size(poi,2));
    y = linspace(0,600,size(poi,1));

    % Set axes and figure properties.
    myfig = figure;
    [xx,yy] = size(poi(:,:,startframe));
    imagesc(x,y,poi(:,:,startframe));
    hold on; plot([25 75],[25 25],'r-','LineWidth',6)
    caxis([mn mx])
    axis image
    set(gca,'yTick',[],'xTick',[])
    colormap(gray)
    set(gcf,'Position', [250 250 xx yy]);
    set(gca,'YDir','normal','XDir','reverse')
    frame = getframe;
    % size(frame.cdata)
    hold on
    clf(myfig)

    % Create movie frames
    for k = startframe:ds:endframe
        imagesc(x,y,poi(:,:,k));
        hold on; plot([25 75],[25 25],'r-','LineWidth',6)
        caxis([mn mx])
        axis off
        set(gca,'YDir','normal','XDir','reverse')
        frame = getframe;
        frame.cdata = frame.cdata(2:end,:,:);
        writeVideo(writerObj,frame);
        clf(myfig)
    end

    % Close file
    close(writerObj);
    close all;

    addpath(genpath('C:\Users\jdemas\Documents\MATLAB\FFMPEG\'))
    ffmpegtranscode(filename, [filename(1:end-3) 'mp4'], 'AudioCodec', 'none', 'VideoCodec', 'x264', 'x264Tune', 'film', 'x264Preset', 'veryslow', 'x264Crf', 17);

end