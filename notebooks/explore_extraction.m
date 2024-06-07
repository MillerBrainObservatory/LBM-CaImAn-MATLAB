%% TEST SCAN PHASE FOR GROUND TRUTH VS PIPELINE


%% Analysis for what inputs to the scan phase algorithm lead to 
%% what offsets.

clc; clear;

gt_mf = matfile("E:\ground_truth\high_res\offset_data.mat");
gt_raw = single(gt_mf.Iin);
gt_cut = gt_raw(18:end, 7:end-6);

[yind, xind] = get_central_indices(gt_raw,50);

f = figure('Color', 'black', 'Visible', 'on', 'Position', [100, 100, 1400, 600]); % Adjust figure size as needed
sgtitle(sprintf('Scan-Correction Validation: Frame 2, Plane %d', plane_idx), 'FontSize', 16, 'FontWeight', 'bold', 'Color', 'w');
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact'); 

nexttile; imagesc(gt_raw);
axis image; axis tight; axis off; colormap('gray');
title('Raw ROI', 'FontSize', 14, 'FontWeight', 'bold', 'Color', 'k');
nexttile; imagesc(gt_raw(100:115,end-10:end));
axis image; axis tight; axis off; colormap('gray');
title('ROI 1: Cut', 'FontSize', 14, 'FontWeight', 'bold', 'Color', 'k');

gt_square = gt_raw(yind, xind);

scanphase = returnScanOffset(gt_raw, 1, 'single');
scanphase_cut = returnScanOffset(gt_cut, 1, 'single');
scanphase_square = returnScanOffset(gt_square, 1, 'single');

corrected = fixScanPhase(gt_raw, scanphase, 1, 'single');
corrected_cut = fixScanPhase(gt_cut, scanphase_cut, 1, 'single');
corrected_square = fixScanPhase(gt_square, scanphase_square, 1, 'single');

[xr, yr] = get_central_indices(corrected, 50);
[xc, yc] = get_central_indices(corrected_cut, 50);
[xs, ys] = get_central_indices(corrected_square, 50);

imagesc([corrected(xr, yr) corrected_cut(xc, yc) corrected_square(xs, ys)]);

%%

h5_corrected = sprintf('C:/Users/RBO/Documents/data/high_res/corrected_gt/motion_corrected_plane_%d.h5', 1);
h5_extracted = sprintf('C:/Users/RBO/Documents/data/high_res/extracted_gt/extracted_plane_%d.h5', 1);
data_corr = h5read(h5_corrected, '/mov');
data_extr = h5read(h5_extracted, '/Y_gt');

img_frame = data_corr(:,:,200);
[r, c] = find(img_frame == max(img_frame(:)));
[slicey, slicex] = get_central_indices(img_frame,r,c,200);
new = [data_corr(slicey, slicex, 2:402) data_extr(slicey, slicex, 2:402)];
planeToMovie(new, save_path, 10);

%%
save_path = 'C:/Users/RBO/Documents/data/high_res/extracted_phase/';
filename = fullfile(save_path, "extracted_plane_1.h5");

files = dir([save_path '*.h5']);
info = h5info(filename, '/Y');
h = zeros([1 length(files)]);
h2 = zeros([4 length(files)]);
for i=1:length(files)
    filename = fullfile(save_path, sprintf("extracted_plane_%d.h5", i));
    h(i) = h5read(filename, '/offsets_plane');
    metadata = read_h5_metadata(filename, '/Y');
    h2(:, i) = metadata.offsets_roi;
end

%% Analysis matching offsets taken for the entire plane, vs offsets 
% taken for individual ROI's
clc;

for iplane=1:length(h2(1,:))
    roi_vals = h2(:,iplane); % size 4 double, 
    p_val = h(iplane);
    filename = fullfile(save_path, sprintf("extracted_plane_%d.h5", iplane));
    if any(diff(roi_vals))
        
        data = h5read(filename, '/Y');
        figure; imagesc(data(:, :, 2)); axis image; axis tight; axis off; colormap gray; title("Variable between-ROI Scan Offset Correction\nPlane %d", iplane);
    elseif roi_vals(1) ~= p_val
        
        figure; imagesc(data(:, :, 2)); axis image; axis tight; axis off; colormap gray; title("Between-ROI Offsets different from Plane Offset\nPlane %d", iplane);
    else
        disp(p_val);
    end
end

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