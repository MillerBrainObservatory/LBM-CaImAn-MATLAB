%% processMAxiMuMtif

function [vol,pixel_resolution,volume_rate] = processMAxiMuMtif(path,filename,trim)

if size(strfind(filename,'hemisphere'),1) > 0
    % Hemisphere
    volume_rate = 4.69;
    pixel_resolution = 5;
    numROI = 5;

elseif size(strfind(filename,'2mm'),1) > 0
    % 2 mm
    volume_rate = 6.45;
    pixel_resolution = 2.75;
    numROI = 5;

elseif size(strfind(filename,'0p6mm'),1) > 0
    % 0.6 mm
    volume_rate = 9.61;
    pixel_resolution = 1;
    numROI = 4;

elseif size(strfind(filename,'0p9mm'),1) > 0
    % 0.9 mm
    volume_rate = 36.89;
    pixel_resolution = 3;
    numROI = 2;
    
elseif size(strfind(filename,'3mm'),1) > 0
    % 3 mm
    volume_rate = 7.69;
    pixel_resolution = 5;
    numROI = 5;
    
elseif size(strfind(filename,'3p6mm'),1) > 0
    % 3.6 mm
    volume_rate = 5.38;
    pixel_resolution = 5;
    numROI = 6;

else
    disp('File name does not contain valid FOV pointers.')   
end 


%% Retrieve and reorder volume

disp('Loading volume from tif...')
if exist([path filename '.mat'],'file')>0
    vol = load([path filename '.mat']); % load from mat file
else
    vol = ProcessROITiff([path filename '.tif'],1:numROI,trim); % load from tif
end
disp('Volume loaded. Detecting scan phase offsets...')

order = [1 5:10 2 11:17 3 18:23 4 24:30];
order = fliplr(order);

vol = vol(:,:,order,:); 

%% Retrive calibration

load([path 'pollen_sample_xy_calibration.mat']) % load most recent calibration file
xs1 = diff(round(diffy/pixel_resolution)); % convert offsets to pixel space
ys1 = diff(round(diffx/pixel_resolution)); % convert offsets to pixel space

%% Determine scan phase offsets and correct
dim = 1;

I = mean(vol,4);
scan_corrections = zeros(1,numel(order));
for ijk = 1:numel(order)
    scan_corrections(ijk) = returnScanOffset2(I(:,:,ijk),1);
end

disp('Offsets returned. Correcting scan phase...')

parfor ijk = 1:numel(order)
    disp(['Correcting plane ' num2str(ijk) ' of ' num2str(numel(order)) '...'])
    POI = vol(:,:,ijk,:); % select plane from buffered volume
    [sy,sx,~,~] = size(POI);
    POI = fixScanPhase(POI,scan_corrections(ijk),dim); % fix scan phase
    POI = POI(1:sy,1:sx,:,:);
    vol(:,:,ijk,:) = POI; % reinsert plane
end

clear POI

%% Calculate new shifts

wind = 200;
mxshift = 50;

xs2 = zeros(size(xs1));
ys2 = zeros(size(ys1));

for ijk = 1:numel(xs1)

    P1 = mean(vol(:,:,ijk,:),4);
    P2 = mean(vol(:,:,ijk+1,:),4);

    P11 = P1(wind:size(P1,1)-wind,wind:size(P1,2)-wind);

    [~,ind] = max(P11(:));
    [yi,xi] = ind2sub(size(P11),ind);

    yi = yi+wind-1;
    xi = xi+wind-1;

    P111 = P1(yi-mxshift:yi+mxshift,xi-mxshift:xi+mxshift);
    P222 = P2(yi+ys1(ijk)-mxshift:yi+ys1(ijk)+mxshift,xi+xs1(ijk)-mxshift:xi+xs1(ijk)+mxshift);

    P111 = P111-mean(P111(:));
    P222 = P222-mean(P222(:));

    R = xcorr2(P111,P222);

    [~,ind] = max(R(:));
    [yoff,xoff] = ind2sub(size(R),ind);
    yoff = yoff - ceil(size(R,1)/2);
    xoff = xoff - ceil(size(R,2)/2);

    xs2(ijk) = xs1(ijk) - xoff;
    ys2(ijk) = ys1(ijk) - yoff;
end

figure
plot([0 cumsum(xs1)],'rx','MarkerSize',10)
hold on
plot([0 cumsum(ys1)],'bx','MarkerSize',10)
plot([0 cumsum(xs2)],'ro','MarkerSize',10)
plot([0 cumsum(ys2)],'bo','MarkerSize',10)
grid(gca,'on')
xlabel('Beam number')
ylabel('Pixel shift')
legend('X correction 1','Y correction 1','X correction 2','Y correction 2')
saveas(gcf,[path filename '_calculated_shifts.fig']);

xshift = [0 cumsum(xs2)]; xshift = xshift-min(xshift);
yshift = [0 cumsum(ys2)]; yshift = yshift-min(yshift);

%% Add buffers

disp('Adding buffers to volume...')   

bx = max(xshift);
bufferx = zeros(size(vol,1),bx,size(vol,3),size(vol,4));

vol = cat(2,vol,bufferx);
clear bufferx

by = max(yshift);
buffery = zeros(by,size(vol,2),size(vol,3),size(vol,4));

vol = cat(1,vol,buffery);
clear bufferx

%% Shift planes with new correction

disp('Buffer constructed. Shifting planes...')

for ijk = 1:numel(order)
    disp(['Shifting plane ' num2str(ijk) ' of ' num2str(numel(order)) '...'])
    POI = vol(1:size(vol,1)-by,1:size(vol,2)-bx,ijk,:); % select plane from buffered volume
    vol(:,:,ijk,:) = 0; % blank the plane
    vol((by+1-yshift(ijk)):(size(vol,1)-yshift(ijk)),(bx+1-xshift(ijk)):(size(vol,2)-xshift(ijk)),ijk,:) = POI; % reinsert plane
end

clear POI

%% Create mean projections

disp('Planes shifted. Creating mean projections...')

I = mean(vol,4); % mean projection in time

figure(101) % image planes 1,2,4,6,8,10,12,14,16,18,20,22,24,26,28, and 30
[ha,~] = tight_subplot(4,4);
imsoi = [1 2:2:30];
for ijk = 1:16
    axes(ha(ijk));
    imagesc(I(:,:,imsoi(ijk))')
    axis image
    xlim([1 size(I,1)])
    ylim([1 size(I,2)])
    colormap(gray)
    set_caxis(I(:,:,imsoi(ijk)));
    set(gca,'xTick',[],'yTick',[])
end
saveas(gcf,[path filename '_mean_projections.fig'])

save([path filename '_mean_projections.mat'],'I','-v7.3')
disp('Mean projections saved.')

figure(101)
close(gcf)

%% Trim the volume

plane = mean(mean(vol,3),4); % 2D plane

plane_x = mean(plane,1); 
vals_x = find(plane_x); % find array of non-zero pixels in x mean projection

plane_y = mean(plane,2);
vals_y = find(plane_y); % find same array for y mean projection

vol = vol(vals_y(1):vals_y(end),vals_x(1):vals_x(end),:,:); % trim to only non-zero values

