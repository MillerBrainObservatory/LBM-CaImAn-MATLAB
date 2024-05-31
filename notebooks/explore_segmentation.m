clc, clear;

metadata = read_h5_metadata('C:\Users\RBO\Documents\data\high_res\extracted\extracted_plane_1.h5', '/Y');
h5_segmented = sprintf('C:/Users/RBO/Documents/data/high_res/segmented/segmented_plane_%d.h5', 1);
info = h5info(h5_segmented, '/');
Ac_keep = h5read(h5_segmented, '/Ac_keep');
Cn = h5read(h5_segmented, '/Cn');
C_keep = h5read(h5_segmented, '/C_keep');
Km = h5read(h5_segmented, '/Km');
acm = h5read(h5_segmented, '/acm');
acx = h5read(h5_segmented, '/acx');
acy = h5read(h5_segmented, '/acy');
f = h5read(h5_segmented, '/f');
b = h5read(h5_segmented, '/b');
rVals = h5read(h5_segmented, '/rVals');

%%
data_extr = h5read(h5_extracted, '/Y_gt');

img_frame = data_corr(:,:,200);
[r, c] = find(img_frame == max(img_frame(:)));
[slicey, slicex] = get_central_indices(img_frame,r,c,200);
new = [data_corr(slicey, slicex, 2:402) data_extr(slicey, slicex, 2:402)];
planeToMovie(new, save_path, 10);

%% TEST SCAN PHASE FOR GROUND TRUTH VS PIPELINE

clc;
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

sq_raw = get_central_indices(corrected, 40);
sq_cut = get_central_indices(corrected_cut, 40);
sq_square = get_central_indices(corrected_square, 40);

figure;
rows = 1;
cols = 3;
tiledlayout(rows, cols, "TileSpacing","tight","Padding","tight");
nexttile;imagesc(sq_raw(3:end,3:end));axis image; axis off;colormap 'gray'; subtitle(sprintf("600x144 (raw) Input: offset=%d", scanphase));
nexttile;imagesc(sq_square(3:end,3:end));axis image;axis off;colormap 'gray'; subtitle(sprintf("583x132 (trimmed) Input: offset=%d", scanphase_cut));
nexttile;imagesc(sq_cut(3:end,3:end));axis image;axis off;colormap 'gray'; subtitle(sprintf("40x40 (square) Input: offset=%d", scanphase_square));

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
        cnt = cnt+1;
    end
    % close(f);
    write_chunk_h5(h5savefile, z_timeseries, size(z_timeseries,3), '/Y_gt');
    write_metadata_h5(metadata, h5savefile, '/Y_gt');
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
