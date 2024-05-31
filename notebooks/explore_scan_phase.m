%% Load ground truth dataset
clc; clear;
% raw_fpath = 'C:/Users/RBO/Documents/data/ground_truth/high_res/MH70_0p6mm_FOV_50_550um_depth_som_stim_199mW_3min_M1_00001_00001.tif';
raw_fpath = 'C:/Users/RBO/Documents/data/ground_truth/high_res/strip.mat';
ground_truth = matfile(raw_fpath).stripTemp;

%% FIX SCAN PHASE

% TODO: Function-ize this

clc; clear;
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
        full_ds_path ... % dataset location
    );
    
    cnt = 1;
    offset_x = 0;
    offset_x_og = 0;
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
            offset_x = offset_x + 132;
            offset_x_og = offset_x_og + 144;
        end
    
        arr = data( ...
            :, ... % (offset_y + t_top + 1):(offset_y + raw_y - t_bottom), ...
            (offset_x_og + 1):(offset_x_og + 144), ... 
            : ...
        );
        corr = returnScanOffset(arr,1, 'int16');
        new_arr = fixScanPhase(arr,corr, 1, 'int16');
        trimmed_arr = new_arr(val:end, 7:138, :);
        z_timeseries(:, (offset_x + 1):(offset_x + 132),:) = trimmed_arr;
        
        cnt = cnt+1;
    end
    try
        write_chunk_h5(h5savefile, z_timeseries, size(z_timeseries,3), '/Y_gt');
    catch ME
        delete(h5savefile);
        write_chunk_h5(h5savefile, z_timeseries, size(z_timeseries,3), '/Y_gt');
    end
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
save_path = fullfile('C:\Users\RBO\Documents\data\high_res\');
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