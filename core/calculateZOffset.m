function [offsets] = calculateZOffset(datapath, metadata, startPlane, endPlane, numFeatures)
% CALCULATEZOFFSET Calculates Z-axis offsets between consecutive image planes by cross-correlation.
%
% This function loads image data from specified planes, identifies features
% in each plane, and calculates the offset in pixels between these features
% across consecutive planes. The function maximizes cross-correlation on regions
% around identified features to determine the best match and thus the offset.
%
% Parameters
% ----------
% datapath : string
%     Path to the directory containing the image data and calibration files.
%     The function expects to find 'pollen_sample_xy_calibration.mat' in this directory along with each caiman_output_plane_N.
%
% metadata : struct
%     Structure containing metadata for the image data. Expected to have at
%     least the 'pixel_resolution' field which is used to scale distances.
%
% startPlane : int
%     The starting plane index from which to begin processing.
%
% endPlane : int
%     The ending plane index at which to stop processing. The function
%     calculates offsets from startPlane to endPlane, inclusive.
%
% numFeatures : int
%     The number of features to identify and use in each plane for
%     calculating offsets.
%
% Returns
% -------
% offsets : Nx2 array
%     An array of offsets between consecutive planes, where N is the number
%     of planes processed. Each row corresponds to a plane, and the two columns
%     represent the calculated offset in pixels along the x and y directions,
%     respectively.
%
% Notes
% -----
% - This function requires calibration data in input datapath:
%   - pollen_sample_xy_calibration.mat
% - The function uses MATLAB's `ginput` function for manual feature selection
%   on the images. It expects the user to manually select the corresponding
%   points on each plane.
% - The function assumes that the consecutive images will have some overlap
%   and that features will be manually identifiable and trackable across planes.
%
% Example
% -------
% offsets = calculateZOffset('C:/data/images/', metadata, 1, 10, 5);
%
% See also LOAD, MAX, IND2SUB, XCORR2, GINPUT, NANMEAN

load([datapath 'pollen_sample_xy_calibration.mat'])

pixel_resolution = metadata.pixel_resolution;

dy = round(diffy/pixel_resolution);
dx = round(diffx/pixel_resolution);

ddx = diff(dy);
ddy = diff(dx);
scale_fact = 10;
nsize = ceil(scale_fact/pixel_resolution);

offsets = zeros(data.num_planes, 2);

for curr_plane = startPlane:endPlane

    p1 = load([path 'caiman_output_plane_' num2str(curr_plane) '.mat'],'Ym'); p1 = p1.Ym;
    p2 = load([path 'caiman_output_plane_' num2str(curr_plane+1) '.mat'],'Ym'); p2 = p2.Ym;

    gix = nan(1,3);
    giy = gix;

    %% search through the brightest features
    for feature_idx = 1:numFeatures
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
            xlim([xi-scale_fact*nsize xi+scale_fact*nsize])
            ylim([yi-scale_fact*nsize yi+scale_fact*nsize])

            h2 = figure;
            set(h2,'position',[700 400 560 420])
            imagesc(p2); axis image
            xlim([xi-scale_fact*nsize+ddx(curr_plane) xi+scale_fact*nsize+ddx(curr_plane)])
            ylim([yi-scale_fact*nsize+ddy(curr_plane) yi+scale_fact*nsize+ddy(curr_plane)])

            figure(h1)
            [x1,y1] = ginput(1);

            y1 = round(y1);
            x1 = round(x1);
            p1w = p1(y1-2*nsize:y1+2*nsize,x1-2*nsize:x1+2*nsize);

            figure(h2)
            [x2,y2] = ginput(1);

            if x2 > xi+scale_fact*nsize+ddx(curr_plane) || x2 < xi-scale_fact*nsize+ddx(curr_plane) || y2 >  yi+scale_fact*nsize+ddy(curr_plane) || y2 < yi-scale_fact*nsize+ddy(curr_plane)

                disp('Current point ignored.')

                gix(feature_idx) = NaN;
                giy(feature_idx) = NaN;

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

                gix(feature_idx) = ox;
                giy(feature_idx) = oy;

                close all
                p1(y1-nsize:y1+nsize,x1-nsize:x1+nsize) = 0;
                p2(y2-nsize:y2+nsize,x2-nsize:x2+nsize) = 0;

            end
        catch
            disp('Current mapping failed.')
        end
    end
    offsets(curr_plane+1,:) = [round(nanmean(giy)) round(nanmean(gix))];
end

offsets = round(offsets);
save([path 'three_neuron_mean_offsets.mat'],'offsets')

end
