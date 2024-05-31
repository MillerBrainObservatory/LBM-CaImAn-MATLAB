% clc, clear;
% 
% metadata = read_h5_metadata('C:\Users\RBO\Documents\data\high_res\extracted\extracted_plane_1.h5', '/Y');
% dataset_path = "/"; % where data is saved in the h5 file (this is default)
% num_px = metadata.num_pixel_xy;

%% TEST SCAN PHASE FOR GROUND TRUTH VS PIPELINE

clc; clear;
gt_mf = matfile("E:\ground_truth\high_res\offset_data.mat");
gt_raw = single(gt_mf.Iin);
gt_cut = gt_raw(18:end, 7:end-6);

[r, c] = find(gt_raw == max(gt_raw(:)));
[yind, xind] = get_central_indices(gt_raw,r,c,50);

f = figure('Color', 'black', 'Visible', 'on', 'Position', [100, 100, 1400, 600]); % Adjust figure size as needed
% sgtitle(sprintf('Scan-Correction Validation: Frame 2, Plane %d', plane_idx), 'FontSize', 16, 'FontWeight', 'bold', 'Color', 'w');
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact'); % Use 'compact' to minimize extra space

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

sq_raw = get_central_indices(corrected, 40);
sq_cut = get_central_indices(corrected_cut, 40);
sq_square = get_central_indices(corrected_square, 40);

% figure;
% rows = 1;
% cols = 3;
% tiledlayout(rows, cols, "TileSpacing","tight","Padding","tight");
% nexttile;imagesc(sq_raw(3:end,3:end));axis image; axis off;colormap 'gray'; subtitle(sprintf("600x144 (raw) Input: offset=%d", scanphase));
% nexttile;imagesc(sq_square(3:end,3:end));axis image;axis off;colormap 'gray'; subtitle(sprintf("583x132 (trimmed) Input: offset=%d", scanphase_cut));
% nexttile;imagesc(sq_cut(3:end,3:end));axis image;axis off;colormap 'gray'; subtitle(sprintf("40x40 (square) Input: offset=%d", scanphase_square));

%% DATA LOADER
% TODO: Function-ize this

clc; clear;
start = 1;
stop = 1;
frame = 1;
for plane_idx = 1:30
    h5file = sprintf('C:/Users/RBO/Documents/data/high_res/extracted_raw/extracted_plane_%d.h5', plane_idx);
    h5savefile = sprintf('C:/Users/RBO/Documents/data/high_res/extracted_gt/extracted_plane_%d.h5', plane_idx);

    full_ds_path = "/Y";
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
    
    cnt = 1;
    offset_x = 0;
    offset_y = 0;
    
    val = 0.03*metadata.strip_height;
    y_size = length(val:metadata.strip_height);
    z_timeseries = zeros(length(val:metadata.strip_height), ...
        132 * metadata.num_strips, ...
        metadata.num_frames_total, ...
        'int16' ...
    );
    
    for roi_idx = 1:length(metadata.offsets)
        roi_str = sprintf("roi_%d", roi_idx);
        if cnt > 1
            % offset_y = offset_y + metadata.strip_height + metadata.num_lines_between_scanfields;
            offset_x = offset_x + metadata.strip_width;
        end
    
        arr = data( ...
            :, ... % (offset_y + t_top + 1):(offset_y + raw_y - t_bottom), ...
            (offset_x + 1):(offset_x + metadata.strip_width), ... 
            : ...
        );
        new_arr = fixScanPhase(arr, metadata.offsets(roi_idx), 1, 'int16');
    
        z_timeseries( ...
            :, ...
            (offset_x + 1):(offset_x + 132), ...
            : ...
            ) = new_arr( ...
            val:end, ... % Y
            7:138, ... % X
            : ... x T
            );
        % savename = fullfile("C:\Users\RBO\Documents\data\high_res\extracted_2\figures\", roi_str);
        % savename = sprintf("%s_gt.png",savename);
        % 
        % f = figure('Color', 'black',"Visible","off", 'Position', [100, 100, 1400, 600]);
        % tiledlayout("horizontal", 'TileSpacing', 'compact', 'Padding', 'compact');
        % nexttile;
        % imagesc(new_arr(:,:,2)); colormap('gray'); axis image; axis tight; axis off;
        % subtitle(sprintf('Roi %d | Offset %d', roi_idx, metadata.offsets(roi_idx)), 'FontSize', 10, 'FontWeight', 'bold', 'Color', 'w');
        % exportgraphics(f, savename, "Resolution",300,"ContentType","image","Colorspace","gray","BackgroundColor","black");
        cnt = cnt+1;
    end
    % close(f);
    write_chunk_h5(h5savefile, z_timeseries, size(z_timeseries,3), '/Y_gt');
    write_metadata_h5(metadata, h5savefile, '/Y_gt');
end

%%

mc_path = fullfile(parent_path, 'corrected_gt');
if ~isfolder(mc_path); mkdir(mc_path); end

compute = 1;
if compute
    motionCorrectPlane( ...
        fullfile(parent_path, 'extracted_gt'), ... % we used this to save extracted data
        mc_path, ... % save registered data here
        'dataset_name', '/Y_gt', ... % where we saved the last step in h5
        'debug_flag', 0, ...
        'overwrite', 1, ...
        'num_cores', 23, ...
        'start_plane', 1, ...
        'end_plane', 2  ...
    );
end
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