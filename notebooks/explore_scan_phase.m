clc, clear;

metadata = read_h5_metadata('C:\Users\RBO\Documents\data\high_res\extracted\extracted_plane_1.h5', '/Y');
dataset_path = "/"; % where data is saved in the h5 file (this is default)
num_px = metadata.num_pixel_xy;

%%
clc
gt_mf = matfile("E:\ground_truth\high_res\offset_data.mat");
gt_raw = single(gt_mf.Iin);

gt_cut = gt_raw(18:end, 7:end-6);
gt_square = get_centered_image(gt_raw, 31);

scanphase = returnScanOffset(gt_raw, 1, 'single');
scanphase_cut = returnScanOffset(gt_cut, 1, 'single');
scanphase_square = returnScanOffset(gt_square, 1, 'single');

corrected = fixScanPhase(gt_raw, scanphase, 1, 'single');
corrected_cut = fixScanPhase(gt_cut, scanphase_cut, 1, 'single');
corrected_square = fixScanPhase(gt_square, scanphase_square, 1, 'single');

sq_raw = get_(corrected, 25);
sq_cut = square_image_from_center(corrected_cut, 25);
sq_square = square_image_from_center(corrected_square, 25);

%%

figure;
rows = 1;
cols = 3;
tiledlayout(rows, cols, "TileSpacing","tight","Padding","tight");
nexttile;imagesc(sq_raw(3:end,3:end));axis image; axis off;colormap 'gray'; subtitle(sprintf("600x144 (raw) Input: offset=%d", scanphase)); 
nexttile;imagesc(sq_square(3:end,3:end));axis image;axis off;colormap 'gray'; subtitle(sprintf("583x132 (trimmed) Input: offset=%d", scanphase_cut)); 
nexttile;imagesc(sq_cut(3:end,3:end));axis image;axis off;colormap 'gray'; subtitle(sprintf("40x40 (square) Input: offset=%d", scanphase_square)); 

%% Load registration results
% TODO: Functionize this

clc;
start = 1;
stop = 1;
frame = 1;
plane = 1;
h5file = 'C:\Users\RBO\Documents\data\high_res\corrected\motion_corrected_plane_1.h5';
full_ds_path = "/mov";
info = h5info(h5file, full_ds_path);
metadata = read_h5_metadata(h5file, full_ds_path);
ds_size = info.Dataspace.Size;

mys = (1:ds_size(1));
mxs = (1:ds_size(2));
mts = (1:ds_size(3));

xs = mxs;
ys = mys;
ts = mts;

data = h5read( ...
    h5file, ... % filename
    full_ds_path, ... % dataset location
    [ys(1), xs(1), ts(1)], ... % start index for each dimension [X,Y,T]
    [length(ys), length(xs), length(ts)] ... % count for each dimension [X,Y,T]
);
%%
save_path = fullfile('C:\Users\RBO\Documents\data\high_res\motion_corrected_plane1_200.mp4');
img_frame = data(:,:,200);
[r, c] = find(img_frame == max(img_frame(:)));
[slicey, slicex] = get_central_indices(img_frame,r,c,200);
planeToMovie(data(:,:,2:402), save_path, metadata.frame_rate);

%%
% imagesc(groundt.Iin); axis image; axis off; xlim([69.2 88.2]); ylim([510.4 589.4]);
imagesc(data); axis image; axis off; xlim([69.2 88.2]); ylim([510.4 589.4]);
%%
function dataOut = fixScanPhase(dataIn,offset,dim, dtype)
% Find the lateral shift that maximizes the correlation between
% alternating lines for the resonant galvo. Correct for phase-offsets
% occur between each successive line.
[sy,sx,sc,sz] = size(dataIn);
dataOut = zeros(sy,sx,sc,sz, dtype);
if dim == 1
    if offset>0
        dataOut(1:2:sy,1:sx,:,:) = dataIn(1:2:sy,:,:,:);
        dataOut(2:2:sy,1+offset:(offset+sx),:) = dataIn(2:2:sy,:,:);
    elseif offset<0
        offset = abs(offset);
        dataOut(1:2:sy,1+offset:(offset+sx),:,:) = dataIn(1:2:sy,:,:,:);
        dataOut(2:2:sy,1:sx,:,:) = dataIn(2:2:sy,:,:,:);
    else
        dataOut(:,1+floor(offset/2):sx+floor(offset/2),:,:) = dataIn;
    end

elseif dim == 2
    if offset>0
        dataOut(1:sy,1:2:sx,:,:) = dataIn(:,1:2:sx,:,:);
        dataOut(1+offset:(offset+sy),2:2:sx,:) = dataIn(:,2:2:sx,:);
    elseif offset<0
        offset = abs(offset);
        dataOut(1+offset:(offset+sy),1:2:sx,:,:) = dataIn(:,1:2:sx,:,:);
        dataOut(1:sy,2:2:sx,:,:) = dataIn(:,2:2:sx,:,:);
    else
        dataOut(1+floor(offset/2):sy+floor(offset/2),:,:,:) = dataIn;
    end
end
end

function correction = returnScanOffset(Iin,dim,dtype)
if isempty(dtype)
    dtype = class(Iin);
end
if numel(size(Iin)) == 3
    Iin = mean(Iin,3);
elseif numel(size(Iin)) == 4
    Iin = mean(mean(Iin,4),3);
end

n = 8;
switch dim
    case 1
        Iv1 = Iin(1:2:end,:);
        Iv2 = Iin(2:2:end,:);

        Iv1 = Iv1(1:min([size(Iv1,1) size(Iv2,1)]),:);
        Iv2 = Iv2(1:min([size(Iv1,1) size(Iv2,1)]),:);

        buffers = zeros(size(Iv1,1),n, dtype);

        Iv1 = cat(2,buffers,Iv1,buffers);
        Iv2 = cat(2,buffers,Iv2,buffers);

        Iv1 = reshape(Iv1',[],1);
        Iv2 = reshape(Iv2',[],1);

    case 2
        Iv1 = Iin(:,1:2:end);
        Iv2 = Iin(:,2:2:end);

        Iv1 = Iv1(:,1:min([size(Iv1,2) size(Iv2,2)]));
        Iv2 = Iv2(:,1:min([size(Iv1,2) size(Iv2,2)]),:);

        buffers = zeros(n,size(Iv1,2), dtype);

        Iv1 = cat(1,buffers,Iv1,buffers);
        Iv2 = cat(1,buffers,Iv2,buffers);

        Iv1 = reshape(Iv1,[],1);
        Iv2 = reshape(Iv2,[],1);
end

Iv1 = Iv1-mean(Iv1); Iv1(Iv1<0) = 0;
Iv2 = Iv2-mean(Iv2); Iv2(Iv2<0) = 0;
[r,lag] = xcorr(Iv1,Iv2,n,'unbiased');
[~,ind] = max(r);
correction = lag(ind);
end