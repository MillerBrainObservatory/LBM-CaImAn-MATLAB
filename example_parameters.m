% MOTION CORRECTION
% The final argument for motion correction is an options struct for 
% NoRMCorre algorithm parameters. Any parameter that is
% not set gets a default value

options = [
    % dataset info
    'd1                 ' % number of rows
    'd2                 ' % number of cols
    'd3                 ' % number of planes (for 3d imaging, default: 1)
    % patches
    'grid_size          ' % size of non-overlapping regions (default: [d1,d2,d3])
    'overlap_pre        ' % size of overlapping region (default: [32,32,16])
    'min_patch_size     ' % minimum size of patch (default: [32,32,16])    
    'us_fac             ' % upsampling factor for subpixel registration (default: 20)
    'mot_uf             ' % degree of patches upsampling (default: [4,4,1])
    'max_dev            ' % maximum deviation of patch shift from rigid shift (default: [3,3,1])
    'overlap_post       ' % size of overlapping region after upsampling (default: [32,32,16])
    'max_shift          ' % maximum rigid shift in each direction (default: [15,15,5])
    'phase_flag         ' % flag for using phase correlation (default: false)
    'shifts_method      ' % method to apply shifts ('FFT','cubic','linear')
    % template updating
    'upd_template       ' % flag for online template updating (default: true)
    'init_batch         ' % length of initial batch (default: 100)
    'bin_width          ' % width of each bin (default: 10)
    'buffer_width       ' % number of local means to keep in memory (default: 50)
    'method             ' % method for averaging the template (default: {'median';'mean})
    'iter               ' % number of data passes (default: 1)
    'boundary           ' % method of boundary treatment 'NaN','copy','zero','template' (default: 'copy')
    % misc
    'add_value          ' % add dc value to data (default: 0)
    'use_parallel       ' % for each frame, update patches in parallel (default: false)
    'memmap             ' % flag for saving memory mapped motion corrected file (default: false)
    'mem_filename       ' % name for memory mapped file (default: 'motion_corrected.mat')
    'mem_batch_size     ' % batch size during memory mapping for speed (default: 5000)
    % plotting
    'plot_flag          ' % flag for plotting results in real time (default: false)
    'make_avi           ' % flag for making movie (default: false)
    'name               ' % name for movie (default: 'motion_corrected.avi')
    'fr                 ' % frame rate for movie (default: 30)
    % output type
    'output_type        ' % 'mat' (load in memory), 'memmap', 'tiff', 'hdf5', 'bin' (default:mat)
    'h5_groupname       ' % name for hdf5 dataset (default: 'mov')
    'h5_filename        ' % name for hdf5 saved file (default: 'motion_corrected.h5')
    'tiff_filename      ' % name for saved tiff stack (default: 'motion_corrected.tif')
    % use windowing
    'use_windowing      ' % flag for windowing data before fft (default: false)
    'window_length      ' % length of window on each side of the signal as a fraction of signal length
                           %    total length = length(signal)(1 + 2*window_length). (default: 0.5)
    % bitsize for reading .raw files
    'bitsize            ' % (default: 2 (uint16). other choices 1 (uint8), 4 (single), 8 (double))
    % offset from bidirectional sampling
    'correct_bidir      ' % check for offset due to bidirectional scanning (default: true)
    'nFrames            ' % number of frames to average (default: 50)
    'bidir_us           ' % upsampling factor for bidirectional sampling (default: 10)
    'col_shift          ' % known bi-directional offset provided by the user (default: [])
   ]; 

% Set the options like so: 

options_rigid = NoRMCorreSetParms(...
        'd1',d1,...
        'd2',d2,...
        'bin_width',200,...               % Bin width for motion correction
        'max_shift', 50,...        % Max shift in px
        'us_fac',20,...
        'init_batch',200,...              % Initial batch size
        'correct_bidir', false...         % DON'T Correct for bidirectional scanning
);