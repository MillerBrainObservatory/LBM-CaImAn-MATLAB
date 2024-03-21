%% processMAxiMuM

filenames = {'mh18_0p6mm_FOV_50percent_50_550um_depth_3min_00001','mh19_0p6mm_FOV_50percent_50_550um_depth_3min_00001','mb157_0p6mm_FOV_50percent_50_550um_depth_3min_00001','mb163_0p6mm_FOV_50percent_50_550um_depth_3min_00001'};

for abc = 1:4

clearvars -except filenames abc
clc

addpath(genpath('/rugpfs/fs0/vzri_lab/scratch/jdemas/Tiff_Processing/'))

%% Determine file and characteristics

filename = filenames{abc};
path = '/rugpfs/fs0/vzri_lab/scratch/jdemas/Animal_Data/';
stimFlag = 0;

if size(strfind([path filename],'hemisphere'),1) > 0
    % Hemisphere
    volume_rate = 3.91;
    pixel_resolution = 5;
    numROI = 6;
    sizeY = 1000;

elseif size(strfind([path filename],'2mm'),1) > 0
    % 2 mm
    volume_rate = 6.39;
    pixel_resolution = 2.75;
    numROI = 5;
    sizeY = 726;

elseif size(strfind([path filename],'0p6mm'),1) > 0
    % 0.6 mm
    volume_rate = 9.61;
    pixel_resolution = 1;
    numROI = 4;
    sizeY = 600;
    
else
    disp('File name does not contain valid FOV pointers.')
end 

%% Retrive calibration

load([path 'pollen_sample_xy_calibration.mat']) % load most recent calibration file
diffxpix = round(diffx/pixel_resolution); % convert offsets to pixel space
diffypix = round(diffy/pixel_resolution); % convert offsets to pixel space

%% Retrieve volume

disp('Loading volume from tif...')
vol = ProcessROITiff([path filename '.tif'],1:numROI,1);
disp('Volume loaded. Reordering planes...')

order = [1 5:10 2 11:17 3 18:23 4 24:30];
order = fliplr(order);

vol = vol(:,:,order,:); 

disp('Planes reordered. Adding buffer...')

buffnumx = ceil(1.01.*max(abs(diffxpix)));
bufferx = zeros(size(vol,1),buffnumx,size(vol,3),size(vol,4));

vol = cat(2,bufferx,vol);
clear bufferx

buffnumy = ceil(1.01.*max(abs(diffypix)));
buffery = zeros(buffnumy,size(vol,2),size(vol,3),size(vol,4));

vol = cat(1,vol,buffery);
clear buffery

disp('Buffer constructed. Shifting planes...')

for ijk = 1:numel(order)
    disp(['Shifting plane ' num2str(ijk) ' of ' num2str(numel(order)) '...'])
    POI = vol(1:size(vol,1)-buffnumy-1,buffnumx+1:size(vol,2),ijk,:); % select plane from buffered volume
    vol(:,:,ijk,:) = 0; % blank the plane
    vol(1+diffypix(ijk):(diffypix(ijk)+size(POI,1)),1+abs(diffxpix(ijk)):(abs(diffxpix(ijk))+size(POI,2)),ijk,:) = POI; % reinsert plane
end

clear POI
disp('Planes shifted. Detecting scan offset...')

dim = 1;

I = mean(vol,4);
scan_corrections = zeros(1,numel(order));
for ijk = 1:numel(order)
    scan_corrections(ijk) = returnScanOffset(I(:,:,ijk),dim);
end

disp('Offsets returned. Correction scan phase...')


for ijk = 1:numel(order)
    disp(['Correcting plane ' num2str(ijk) ' of ' num2str(numel(order)) '...'])
    POI = vol(:,:,ijk,:); % select plane from buffered volume
    [sy,sx,~,~] = size(POI);
    POI = fixScanPhase(POI,scan_corrections(ijk),dim); % fix scan phase
    POI = POI(1:sy,1:sx,:,:);
    vol(:,:,ijk,:) = POI; % reinsert plane
end

clear POI
disp('Scan phase corrected. Creating mean projections...')


I = mean(vol,4);

% figure(101)
% [ha,~] = tight_subplot(5,6);
% for ijk = 1:30
%     axes(ha(ijk));
%     imagesc(I(:,:,ijk)')
%     axis equal
%     xlim([1 size(I,1)])
%     ylim([1 size(I,2)])
%     colormap(gray)
%     set_caxis(I(:,:,ijk));
%     set(gca,'xTick',[],'yTick',[])
% end
% saveas(gcf,[filename '_mean_projections.fig'])

save([path filename '_mean_projections.mat'],'I','-v7.3')
save([path filename '_processed.mat'],'vol','volume_rate','pixel_resolution','-v7.3')

end