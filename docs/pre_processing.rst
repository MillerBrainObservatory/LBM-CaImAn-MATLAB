.. _pre_proccessing:

Pre-Processing
--------------

Pre-processing LBM datasets consists of 3 main processes:

- 1 ) Reshaping vertically concatenated strips into horizontally concatenated strips and aligning adjacent strips.
- 2 ) Bi-Directional Scan Phase Correction
- 3 ) Peicewise motion-correction

If the user choses to split frames across multiple `.tiff` files, there will be multiple tiff files in ascending order
of an suffix appended to the filename: `_000N`, where n=number of files chosen by the user.

.. important::

    All output .tiff files for a single imaging session should be placed in the same directory.
    No other .tiff files should be in this directory. If this happens, an error will throw.


There are 2 primary functions for pre-processing,
- ..

.. note::

   For detailed documentation in your MATLAB editor, use:

   >> help FunctionName
   >> help convertScanImageTiffToVolume

Convert raw ScanImage .tif files into a 4D format for further processing

.. code-block:: MATLAB

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
    clc
    [fpath, fname, ~] = fileparts(fullfile(mfilename('fullpath'))); % path to this script
    addpath(genpath(fullfile(fpath, 'core/')));

    result = validateRequirements(); % make sure we have dependencies in accessible places
    if ischar(result)
        error(result);
    else
        disp('Proceeding with execution...');
    end

    parentpath = 'C:\Users\RBO\Documents\data\bi_hemisphere\';
    raw_path = [ parentpath 'raw\'];
    extract_path = [ parentpath 'extracted2\'];
    mkdir(extract_path); mkdir(raw_path);

    %% 1a) Pre-Processing

    raw_files = dir([raw_path '*.tif*']);
    metainfo = raw_files(1);
    metaname = metainfo.name;
    metapath = metainfo.folder;

    convertScanImageTiffToVolume(raw_path, extract_path, 0,'fix_scan_phase', false);

    %% 1b) Motion Correction

    mdata = get_metadata(fullfile(metapath, metaname));
    mdata.base_filename = "MH184_both_6mm_FOV_150_600um_depth_410mW_9min_no_stimuli_00001";

    mcpath = 'C:\Users\RBO\Documents\data\bi_hemisphere\registration';
    motionCorrectPlane(extract_path, 23, 1, 3);

    datapath = 'C:\\Users\\LBM_User\\Data\\Session1\\';  # Directory containing raw .tif files
    savepath = 'C:\\Users\\LBM_User\\Data\\Session1\\extracted_volumes\\';  # Output directory for 4D volumes
    convertScanImageTiffToVolume(datapath, savepath, 0);

2. Motion Correction:

Perform both piecewise-rigid motion correction using `NormCORRe`_ to stabilize the imaging data

.. code-block:: MATLAB

    filePath = 'C:\\Data\\';  # Path to the directory containing .mat files for processing
    fileNameRoot = 'session1_';  # Base filename to match for processing
    motionCorrectPlane(filePath, fileNameRoot, 24, 1, 10);  # Process from plane 1 to 10 using 24 cores

