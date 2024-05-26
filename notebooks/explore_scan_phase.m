% folder heirarchy
% -| Parent
% --| raw  <--scanimage .tiff files live here
% ----| basename.h5
% --| extraction
% ----| basename_shifts.h5
% --| registration
% ----| shift_vectors_plane_N.h5
% --| segmentation
% ----| caiman_output_plane_N.h5
% ----| caiman_output_collated_min1.4snr.h5

%% Example script that will run the full pipeline.
% This code block adds all modules inside the "core" directory to the
% matlab path.
% This isn't needed if the path to this package is added to the MATLAB path
% manually by right clicking caiman_matlab folder and "add packages and
% subpackages to path" or via the startup.m file. Both methods described in
% more detail in the README.
clc, clear;
[fpath, fname, ~] = fileparts(fullfile(mfilename('fullpath'))); % path to this script
addpath(genpath(fullfile(fpath, 'core')));
addpath(genpath(fullfile(fpath, 'core', 'utils')));
addpath(genpath(fullfile(fpath, 'core', 'io')));

%% Here you can validate that all packages are on the path and accessible
% from within this pipeline.

result = validateRequirements();
if ischar(result)
    error(result);
else
    disp('Proceeding with execution...');
end

parent_path = fullfile('C:\Users\RBO\Documents\data\high_res');
data_path = fullfile(parent_path, 'raw');
save_path = fullfile(parent_path, 'extracted');
if ~isfolder(save_path)
    mkdir(save_path)
end

%% 1a) Pre-Processing
dataset_path = "/extraction"; % where data is saved in the h5 file (this is default)
compute = 1;
if compute
    convertScanImageTiffToVolume( ...
        data_path, ...
        save_path, ...
        'dataset_name', dataset_path, ...
        'debug_flag', 0, ...
        'fix_scan_phase', 0, ...
        'trim_pixels', [6 6 17 0], ...
        'overwrite', 1 ...
        );
end

%% quick vis
clc;
h5file = 'C:\Users\RBO\Documents\data\high_res\extracted\MH70_0p6mm_FOV_50_550um_depth_som_stim_199mW_3min_M1_00001_00001.h5';
metadata = read_h5_metadata(h5file, '/extraction');

plane = 1;
frame_start = 10;
frame_end = 100;
xs=(236:408);
ys=(210:377);
ts=(2:202);
dataset_path = sprintf('/extraction/plane_%d', plane);
% data_path = sprintf("%s/Y", dataset_path);
info = h5info(h5file, dataset_path);

count_x = length(xs);
count_y = length(ys);
count_t = frame_end - frame_start + 1;

data = h5read( ...
    h5file, ... % filename
    dataset_path, ... % dataset location
    [xs(1), ys(1), frame_start], ... % start index for each dimension [X,Y,T]
    [count_x, count_y, count_t] ... % count for each dimension [X,Y,T]
    );

%% 1b) Motion Correction

compute = 0;
if compute
    motionCorrectPlane( ...
        save_path, ...
        save_path, ...
        'data_input_group', '/extraction', ... % from the last step
        'data_output_group', "/registration", ... % "str" or 'char' both work for inputs
        'overwrite', 1, ...
        'num_cores', 23, ...
        'start_plane', 2, ...
        'end_plane', 30  ...
        );
end

% 
% % 
%% 2) CNMF Plane-by-plane SegmentationS
% % 
compute = 1;
if compute
    segmentPlane( ...
        save_path, ...
        save_path, ...
        'data_input_group', '/registration', ... % from the last step
        'data_output_group', "/segmentation", ... % "str" or 'char' both work for inputs
        'overwrite', 1, ...
        'num_cores', 23, ...
        'start_plane', 1, ...
        'end_plane', 1  ...
        );
end

% % 
% % %% 3) Axial Offset Correction
% % collatePlanes()
% 
% function has_mc = has_registration(ih5_path)
%     if numel(h5info(ih5_path, '/').Groups) < 2
%         has_mc = false;
%     else
%         has_mc = true;
%     end
% end

%%
clc;
start = 1;
stop = 1;
frame = 1;
ds_size = info.Dataspace.Size;

mxs = (1:ds_size(1));
mys = (1:ds_size(2));
mts = (1:ds_size(3));

xs = mxs(2:143);
ys = mys;
ts = mts;

data = h5read( ...
    h5file, ... % filename
    dataset_path, ... % dataset location
    [ys(1), xs(1), ts(1)], ... % start index for each dimension [X,Y,T]
    [length(ys), length(xs), length(ts)] ... % count for each dimension [X,Y,T]
);

size(data)
scanphase = returnScanOffset(data, 1, 'int16')
corrected = fixScanPhase(data, scanphase, 1, 'int16');

plane_save = fullfile(save_path, 'plane1_offset2_x_8to130_y_full_t_5to205.mp4');
% planeToMovie(corrected, plane_save, metadata.frame_rate);

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