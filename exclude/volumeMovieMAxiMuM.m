%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% volumeMovieMAxiMuM.m
% Load traces and neuron positions, render as spheres with color and
% opacity based on neuronal activity. Rotate around and zoom in as needed.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


clear
clc
close all

path = '\\v-storage.rockefeller.edu\vazirilab_medium_data\jeff_demas\MAxiMuM_data\20191122\mh89_hemisphere_FOV_50_550um_depth_250mW_dual_stimuli_30min_00001\';
file = [path 'neuron_coordinates_and_traces.mat'];
load(file) % file contains neuron positions and traces

addpath(genpath('\\v-storage.rockefeller.edu\vazirilab_medium_data\jeff_demas\PROCESSING_SCRIPTS\Segmentation_Routines\CaImAn-MATLAB-master\CaImAn-MATLAB-master\'))

averaging = 5; % frame-wise moving avg.
downsampling = 1; % frame-wise downsampling
max_duration = 2; % duration of movie [minutes]
duration = 9; % duration of recording [minutes]
minSNR = 2.22; % minimum SNR of traces to consider, based on CaImAn's SNR calculations
alpha_off = 0.2; % transparency for neurons that are "off"
alpha_on = 0.7; % transparency for neurons that are "off"
zstretch = 3.0; % stretch of z axis relative to the x,y axes
max_ang = 360; % angle of rotation
stim_thresh = 0.2; % threshold for determining a stimulus is occurring
on_thresh = 0.2; % threshold for determining a neuron is "on" relative to max DF/F
max_zoom = 5; % maximum zoom in

% spath = '\\v-storage.rockefeller.edu\vazirilab_medium_data\jeff_demas\MAxiMuM_data\Paper_Videos\S7\';
spath = 'E:\Jeff\'; % saving path
fileName = [spath 'MAxiMuM_hemisphere_movie.avi']; % saving file

writerObj = VideoWriter(fileName,'Uncompressed AVI'); % create AVI object
writerObj.FrameRate = 4.7*4; % 4x speed up
% writerObj.Quality = 100;
open(writerObj);

%%
% Case structure to determine volume rate and pixel resolution from file
% name, disregard as needed
if size(strfind(file,'hemisphere'),1) > 0
    % Hemisphere
    volumeRate = 4.69;
    pixelResolution = 5;
    numROI = 5;
    patchOvp = 4;

elseif size(strfind(file,'2mm'),1) > 0
    % 2 mm
    volumeRate = 6.45;
    pixelResolution = 2.75;
    numROI = 5;
    patchOvp = 9;

elseif size(strfind(file,'0p6mm'),1) > 0
    % 0.6 mm
    volumeRate = 9.61;
    pixelResolution = 1;
    numROI = 4;
    patchOvp = 25;

elseif size(strfind(file,'0p9mm'),1) > 0
    % 0.9 mm
    volumeRate = 36.89;
    pixelResolution = 3;
    numROI = 2;
    patchOvp = 8;

elseif size(strfind(file,'3mm'),1) > 0
    % 3 mm
    volumeRate = 7.69;
    pixelResolution = 5;
    numROI = 5;
    patchOvp = 5;

elseif size(strfind(filename,'3p6mm'),1) > 0
    % 3.6 mm
    volumeRate = 5.38;
    pixelResolution = 5;
    numROI = 6;
    patchOvp = 5;

else
    disp('File name does not contain valid FOV pointers.')   
end 

%%

% Determine fitness based on CaImAn's compute_event_exceptionality
% min SNR --> min fitness, threshold 
decay_time = 0.5;
Nsamples = ceil(volumeRate*decay_time);
min_fitness = log(normcdf(-minSNR))*Nsamples;
fitness = compute_event_exceptionality(T_all,Nsamples,0);

keep = logical(fitness<min_fitness);
Tk = T_all(fitness<min_fitness,:); % 'T_all' contains all the traces (K,T)
nxk = nx(fitness<min_fitness,:); % nx, ny, nz are the coordinates of the neurons (K,1)
nyk = ny(fitness<min_fitness,:);
nzk = nz(fitness<min_fitness,:);

nxk = (nxk-min(nxk)+50);
nyk = (nyk-min(nyk));
nzk = nzk-min(nzk)+50;

% correcting for field curvature
alpha = 158./2500^2;
nzk = nzk - alpha.*((nxk-1500).^2 + (nyk-2500).^2);
nzk = -nzk;

%%

TTT= round(size(T_all,2));
traces = movmean(Tk,averaging,2);
traces = traces(:,1:downsampling:564);
traces = traces - (mean(traces,2)*ones(1,size(traces,2)));
traces = traces./(max(traces,[],2)*ones(1,size(traces,2))); % normalized traces

% Stimulus vectors
ssk = movmean(Ss(1:downsampling:564),averaging);
svk = movmean(Sv(1:downsampling:564),averaging);

% create figure
hh = figure;
hold on
cmap = colormap('parula');
figx = 1284;
figy = 728;
set(hh,'Position',[15 -200 1500 840])

% create vector detailing rotation of the camera
az = linspace(0,max_ang,size(traces,2));
az = az+40;
az = mod(az,360);
az(round(numel(az)/2):end) = az(round(numel(az)/2)-1);

epoch = size(traces,2)/2;

% create the zoom vector
p = epoch/pi;
zm = 1.3+(max_zoom-1.3).*sin((0:size(traces,2)-1)/p).^2;%linspace(1,max_zoom,size(traces,2));
zm(1:round(numel(zm)/2)) = 1.3;

% create a buffered tensor to collect image frames
D = zeros(figy+10,figx+10,3,'uint8');

cx = round(0.07*size(D,1));
cy = cx;
rad = 7;

% create a color map
Tvals = traces(:,1);
inds = round(64*Tvals);
inds(inds<1) = 1;
inds(inds>64) = 64;
C = cmap(inds,:);

% determine which neurons are on and which are off
nON = logical(Tvals>on_thresh);
nOFF = ~nON;

figure(hh)
h = scatter3(nxk(nOFF),nyk(nOFF),zstretch.*nzk(nOFF),20.*(zm(1)-(zm(1)-1)).*ones(size(nxk(nOFF))),C(nOFF),'filled','MarkerFaceAlpha',alpha_off); % plot off neurons
hold on 
h = scatter3(nxk(nON),nyk(nON),zstretch.*nzk(nON),20.*(zm(1)-(zm(1)-1)).*ones(size(nxk(nON))),C(nON),'filled','MarkerFaceAlpha',alpha_on); % plot on neurons
axis image
view(az(1),15) %set the view 
axx = gca;
axx.CameraViewAngleMode = 'manual';
box(gca,'on')
xlim([0 3000]); ylim([0 5000]); % set the camera axes
zlim(zstretch.*[-500 0])
set(gca,'xTick',[0:500:3000],'yTick',[0:500:5000],'zTick',zstretch.*[-500 -250 0]) % the trick here is that the z range is smaller than x,y -- so I stretch the z axis and relabel it to make things easier to see
set(gca,'zTickLabel',{'500', '250', '0'})
set(gca,'Color',[0 0 0])
set(gcf,'Color',[0 0 0])
xlabel('X [\mum]')
ylabel('Y [\mum]')
zlabel('Z [\mum]')
grid(gca,'on')
set(gca,'XColor',[1 1 1],'YColor',[1 1 1]','ZColor',[1 1 1],'GridColor',[1 1 1])
ip = camva;
camva(ip./zm(1)) % set the zoom
frame = getframe(hh);
size(frame.cdata)

% print([spath 'test_frame.png'],'-dpng','-r600','-painters')

hw = waitbar(0,'Generating video...');

tocs = zeros(1,size(traces,2)); % create a waitbar to monitor progress
tic;

val = 5;%round(size(traces,2)/20);
for ijk = 1:size(traces,2) % loop over all frames
    
    waitbar(ijk./size(traces,2),hw)
    
    Tvals = traces(:,ijk);
    inds = round(64*Tvals);
    inds(inds<1) = 1;
    inds(inds>64) = 64;
    C = cmap(inds,:);
    
    nON = logical(Tvals>on_thresh);
    nOFF = ~nON;
    
    figure(hh)
    scatter3(nxk(nOFF),nyk(nOFF),zstretch.*nzk(nOFF),20.*(zm(ijk)-(zm(1)-1)).*ones(size(nxk(nOFF))),C(nOFF),'filled','MarkerFaceAlpha',alpha_off);
    hold on
    scatter3(nxk(nON),nyk(nON),zstretch.*nzk(nON),20.*(zm(ijk)-(zm(1)-1)).*ones(size(nxk(nON))),C(nON),'filled','MarkerFaceAlpha',alpha_on);
    
    axx = gca;
    axx.CameraViewAngleMode = 'manual';
    axis image

    box(gca,'on')
    xlim([0 3000]); ylim([0 5000]); 
    zlim(zstretch.*[-500 0])
    set(gca,'xTick',0:500:3000,'yTick',0:500:5000,'zTick',zstretch.*[-500 -250 0])
    set(gca,'zTickLabel',{'500', '250', '0'})
    set(gca,'Color',[0 0 0])
    set(gcf,'Color',[0 0 0])
    xlabel('X [\mum]')
    ylabel('Y [\mum]')
    zlabel('Z [\mum]')
    grid(gca,'on')
    set(gca,'XColor',[1 1 1],'YColor',[1 1 1]','ZColor',[1 1 1],'GridColor',[1 1 1])

    view(az(ijk),15)
    camva(ip./zm(ijk))
%     h.CData = C;
    
    set(gcf,'renderer','painters')
    drawnow
    pause(.01)
    
    frame = getframe(gcf);
    d = frame.cdata;
    dd = D;
    sx = round(size(D,2)/2)-ceil(size(d,2)/2);
    sy = round(size(D,1)/2)-ceil(size(d,1)/2);
    dd(sy:sy+size(d,1)-1,sx:sx+size(d,2)-1,:) = d; % some times the object from getframe changes size -- this inserts whatever getframe found into a buffered array so that there isn't any sizing problems
    
    % case structure to make a "cigarette burn" when there is a stimulus; 3
    % cases: whisker, visual, both
    if ssk(ijk)>stim_thresh 
        dd(cy-rad:cy+rad,cx-rad:cx+rad,1) = 255;
        dd(cy-rad:cy+rad,cx-rad:cx+rad,2) = 0;
        dd(cy-rad:cy+rad,cx-rad:cx+rad,3) = 0;
    end
    
    if svk(ijk)>stim_thresh
        dd(cy-rad:cy+rad,cx-rad:cx+rad,1) = 0;
        dd(cy-rad:cy+rad,cx-rad:cx+rad,2) = 0;
        dd(cy-rad:cy+rad,cx-rad:cx+rad,3) = 255;
    end
    
    if ssk(ijk)>stim_thresh && svk(ijk)>stim_thresh
        dd(cy-rad:cy+rad,cx-rad:cx+rad,1) = 255;
        dd(cy-rad:cy+rad,cx-rad:cx+rad,2) = 0;
        dd(cy-rad:cy+rad,cx-rad:cx+rad,3) = 255;
    end
    
    frame.cdata = dd;

    writeVideo(writerObj,frame); % write to video
    clf(hh)
    tocs(ijk) = toc;
    
    if mod(val,ijk) == 0
        frames_left = size(traces,2)-ijk;
        avg_frame_time = mean(tocs(tocs>0));
        disp(['Estimated time to completion: ' num2str(frames_left*avg_frame_time/60,3) ' minutes...'])
    end
end

%%
close(hw)

close(writerObj);
close all;

% this uses the ffmpeg library to rewrite the video from avi to mp4
ffmpegtranscode(fileName, [fileName(1:end-3) 'mp4'], 'AudioCodec', 'aac', 'VideoCodec', 'x264', 'Mpeg4Quality',1);
