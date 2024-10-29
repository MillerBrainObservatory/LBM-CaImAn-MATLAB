disp('Starting processing')

data_path = fullfile('/lustre/fs4/mbo/scratch/mbo_data/lbm/high_res/');
save_path = fullfile('/lustre/fs4/mbo/scratch/foconnell/');

addpath(genpath(fullfile("./core/")))
addpath(genpath(fullfile("./")))
addpath(genpath(fullfile("./packages/")))

files = dir(data_path);
disp(files(1))

%convertScanImageTiffToVolume(data_path, 'save_path', save_path, debug_flag=0);

%disp(raw_tiff_file);
%hTif=ScanImageTiffReader(raw_tiff_file);
%hTif=hTif.data();
%size_y=size(hTif);
%hTif=reshape(hTif, [size_y(1), size_y(2), num_planes, num_frames]);
%hTif=permute(hTif, [2 1 3 4]);

exit;
