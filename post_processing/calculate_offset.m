%% Offset correction script
clear
close all
clc

choice = menu('Select NAS:','v-data1','v-data2','v-data3');

switch choice
    case 1
        path = '\\v-storage.rockefeller.edu\vazirilab_medium_data\jeff_demas\MAxiMuM_data\';
    case 2
        path = '\\v-storage2.rockefeller.edu\v-data2\jeff_demas\MAxiMuM_data\';
    case 3
        disp('Drive is not configured for use yet.')
end

path = uigetdir(path);
path = [path '/'];

load([path 'pollen_sample_xy_calibration.mat'])

if size(strfind(path,'hemisphere'),1) > 0
    r_thr = 0.4;
    pixel_resolution = 5;
    min_snr = 1.4;
    frameRate = 4.69;
    FOVx = 3000;
    FOVy = 5000*0.97;
elseif size(strfind(path,'2mm'),1) > 0 && size(strfind(path,'1p2mm'),1) == 0
    r_thr = 0.4;
    pixel_resolution = 2.75;
    min_snr = 1.4;
    frameRate = 6.45;
    FOVx = 2000;
    FOVy = 2000*0.97;
elseif size(strfind(path,'0p9mm'),1) > 0
    r_thr = 0.4;
    pixel_resolution = 3;
    min_snr = 1.5;
    frameRate = 36.89;
    FOVx = 900;
    FOVy = 900*0.97;
elseif size(strfind(path,'0p6mm'),1) > 0
    r_thr = 0.4;
    pixel_resolution = 1;
    min_snr = 1.5;
    frameRate = 9.61;
    FOVx = 600;
    FOVy = 600*0.97;
elseif size(strfind(path,'6mm'),1) > 0 && size(strfind(path,'0.6mm'),1) == 0 && size(strfind(path,'3p6mm'),1) == 0
    r_thr = 0.4;
    pixel_resolution = 4.6;
    min_snr = 1.4;
    frameRate = 2.18;
    FOVx = 5400;
    FOVy = 6000*0.97;
elseif size(strfind(path, '1p2mm'),1) > 0
    r_thr = 0.4;
    pixel_resolution = 2;
    min_snr = 1.4;
    frameRate = 9.61;
    FOVx = 1200;
    FOVy = 1200*0.97;
elseif size(strfind(path,'3p6mm'),1) > 0
    r_thr = 0.4;
    pixel_resolution = 4.6;
    frameRate = 5.37;
    FOVx = 3708;
    FOVy = 3600;
end

dy = round(diffy/pixel_resolution);
dx = round(diffx/pixel_resolution);

ddx = diff(dy);
ddy = diff(dx);

nsize = ceil(10/pixel_resolution);
ds = 10;

offsets = zeros(30,2);

for m = 21:27

    p1 = load([path 'caiman_output_plane_' num2str(m) '.mat'],'Ym'); p1 = p1.Ym;
    p2 = load([path 'caiman_output_plane_' num2str(m+1) '.mat'],'Ym'); p2 = p2.Ym;

    gix = nan(1,3);
    giy = gix;

    for ijk = 1:3
        try 
            buffer = 5*nsize;
            p1m = p1;
            p1m(1:buffer,:) = 0;
            p1m(end-buffer:end,:) = 0;
            p1m(:,1:buffer) = 0;
            p1m(:,end-buffer:end) = 0;

            [mx,inds] = max(p1m(:));
            [yi,xi] = ind2sub(size(p1),inds);

            h1 = figure;
            set(h1,'position',[100 400 560 420])
            imagesc(p1); axis image
            xlim([xi-ds*nsize xi+ds*nsize])
            ylim([yi-ds*nsize yi+ds*nsize])

            h2 = figure;
            set(h2,'position',[700 400 560 420])
            imagesc(p2); axis image
            xlim([xi-ds*nsize+ddx(m) xi+ds*nsize+ddx(m)])
            ylim([yi-ds*nsize+ddy(m) yi+ds*nsize+ddy(m)])

            figure(h1)
            [x1,y1] = ginput(1);

            y1 = round(y1);
            x1 = round(x1);
            p1w = p1(y1-2*nsize:y1+2*nsize,x1-2*nsize:x1+2*nsize);

            figure(h2)
            [x2,y2] = ginput(1);

            if x2 > xi+ds*nsize+ddx(m) || x2 < xi-ds*nsize+ddx(m) || y2 >  yi+ds*nsize+ddy(m) || y2 < yi-ds*nsize+ddy(m)

                disp('Current point ignored.')

                gix(ijk) = NaN;
                giy(ijk) = NaN;

                close all
                p1(y1-nsize:y1+nsize,x1-nsize:x1+nsize) = 0;

            else

                y2 = round(y2);
                x2 = round(x2);
                p2w = p2(y2-nsize:y2+nsize,x2-nsize:x2+nsize);

                r = xcorr2(p1w,p2w);
                [mx,inds] = max(r(:));
                [yo,xo] = ind2sub(size(r),inds);
                yo = yo-ceil(size(r,1)/2);
                xo = xo-ceil(size(r,2)/2);

                oy = (y2-y1)-yo;
                ox = (x2-x1)-xo;

                gix(ijk) = ox;
                giy(ijk) = oy;

                close all
                p1(y1-nsize:y1+nsize,x1-nsize:x1+nsize) = 0;
                p2(y2-nsize:y2+nsize,x2-nsize:x2+nsize) = 0;

            end
        catch
            disp('Current mapping failed.')
        end
    end

    offsets(m+1,:) = [round(nanmean(giy)) round(nanmean(gix))];

end

offsets = round(offsets);

save([path 'three_neuron_mean_offsets.mat'],'offsets')