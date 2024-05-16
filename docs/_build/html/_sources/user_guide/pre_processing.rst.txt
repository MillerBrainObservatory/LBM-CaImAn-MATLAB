
.. _pre_processing:

**************
Pre-Processing
**************

Before beginning pre-processing, follow setup steps in :ref:`getting_started` to make sure the pipeline and dependencies are installed properly.

See :ref:`troubleshooting` for common issues.

Pre-processing LBM datasets consists of 2 main processing steps:

- 1 ) Reshaping vertically concatenated strips into horizontally concatenated strips
- 2 ) Piecewise motion-correction

--------------------------------------
1. Re-Construct Volumetric Time-Series
--------------------------------------

Before processing starts, the raw scanimage output needs to be reconstructed to form a correctly-ordered time-series.
This is accomplished through the use of :ref:`convertScanImageTiffToVolume` of pre-processing.

Shown in the image below is a graphical representation of this reconstruction. In its raw form (see A in the below figure), ScanImage tiff files are multipage tiffs - like a book. Each page
is one *image*, but it doesn't look like an image:

.. image:: ../_static/_images/abc_strip.png
   :width: 1440

The column labeled A in the above image, represents **strips** of our image, which are tiled horizontally into a full image.

Each Z-Plane is written before moving onto the next timestep, e.g.:
- z-plane 1 @ timepoint 1, z-plane 2 @ timepoint 1, z-plane 3 @ timepoint 1, etc.

Thus, another task :ref:`convertScanImageTiffToVolume` accomplishes are reordering this tiff stack to be:
- z-plane 1 @ timepont 1, z-plane 1 @ timepoint 2, etc ..

The output `volumetric time-series` has dimensions `[Y,X,Z,T]`.

If the user chooses to split frames across multiple `.tiff` files, there will be multiple tiff files in ascending order
of a suffix appended to the filename: `_000N`, where n=number of files chosen by the user.

.. important::

    All output .tiff files for a single imaging session should be placed in the same directory.
    No other .tiff files should be in this directory. If this happens, an error will throw.

You can chain the output of one function to the input of another. Note the path names match :ref:`Directory Structure`.

.. code-block:: MATLAB

    parentpath = 'C:\Users\RBO\Documents\data\bi_hemisphere\';
    raw_path = [ parentpath 'raw\'];
    extract_path = [ parentpath 'extracted2\'];
    mkdir(extract_path); mkdir(raw_path);


Our data are now saved as a single hdf5 file separated by file and by plane. This storage format
makes it easy to motion correct each time-series individually. We will be processing small patches of the total image,
roughly 20um in parallel, so attempting to process multiple time-series will drastically slow down NormCorre.

Using help(function) will show us our parameters:

.. code-block:: MATLAB

    >> help convertScanImageTiffToVolume

      convertScanImageTiffToVolume Convert ScanImage .tif files into a 4D volumetric time-series.

      Parameters
      ----------
      filePath : char
          The directory containing the raw .tif files. Only raw .tif files from one
          session should be in the directory.
      saveDirPath : char, optional
          The directory where processed files will be saved. It is created if it does
          not exist. Defaults to the filePath if not provided.
      diagnosticFlag : double, logical, optional
          If set to 1, the function displays the files in the command window and does
          not continue processing. Defaults to 0.
      nvargs : struct, optional

      Notes
      -----
      The function adds necessary paths for ScanImage utilities and processes each .tif
      file found in the specified directory. It checks if the directory exists, handles
      multiple or single file scenarios, and can optionally report the directory's contents
      based on the diagnosticFlag.

      Each file processed is logged, assembled into a 4D volume, and saved in a specified
      directory as a .mat file with accompanying metadata. The function also manages errors
      by cleaning up and providing detailed error messages if something goes wrong during
      processing.

      Examples
      --------
      convertScanImageTiffToVolume('C:/data/session1/', 'C:/processed/', 0);
      convertScanImageTiffToVolume('C:/data/session1/', 'C:/processed/', 1); % Diagnostic mode

      See also fileparts, addpath, genpath, isfolder, dir, fullfile, error, regexp, savefast

      .. _ScanImage: https://www.mbfbioscience.com/products/scanimage/


Setting `fix_scan_phase=true` attempts to maximize the phase-correlation between each line (row) of each strip, as shown below.

.. image:: ../_static/_images/corr_nocorr_phase_example.png
   :width: 1080

This example shows that shifting every *other* row of pixels +2 (to the right) in our 2D reconstructed image will maximize the correlation between adjacent rows.

For each *session*, we will get a single `h5` output file organized by file, then by plane:

.. code-block:: MATLAB

    h5info(extract_path, 'file_1/plane_1')

      struct with fields:

      Filename: 'C:\Users\<username>\extracted\MH184_both_6mm_FOV_150_600um_depth_410mW_9min_no_stimuli_00001_00001.h5'
          Name: 'plane_1'
      Datatype: [1×1 struct]
     Dataspace: [1×1 struct]
     ChunkSize: [1165 1202 1]
     FillValue: 0
       Filters: [1×1 struct]
    Attributes: [30×1 struct]

The attributes hold our metadata, the result of calling `get_metadata(raw_path)`:

.. code-block:: MATLAB

   >> get_metadata(fullfile(extract_path, "MH184_both_6mm_FOV_150_600um_depth_410mW_9min_no_stimuli_00001_00001.tiff"))

    ans =

      struct with fields:

                           center_xy: [-15.2381 0]
                             size_xy: [3.8095 38.0952]
                        num_pixel_xy: [144 1200]
                     lines_per_frame: 144
                     pixels_per_line: 128
        num_lines_between_scanfields: 24
                        image_length: 11008
                         image_width: 145
                   full_image_height: 1165
                    full_image_width: 1197
                          num_planes: 30
                            num_rois: 9
                    num_frames_total: 1176
                     num_frames_file: 392
                           num_files: 3
                          frame_rate: 2.1797
                objective_resolution: 157.5000
                                 fov: [600 6000]
                   strip_width_slice: [8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 … ] (1×129 double)
                         strip_width: 129
                    pixel_resolution: 4.5833
                       sample_format: 'int16'
                      extra_width_px: 16
             extra_width_per_side_px: 8
                       base_filename: "MH184_both_6mm_FOV_150_600um_depth_410mW_9min_no_stimuli_00001_00001"
                       base_filepath: "\raw"
                        base_fileext: ".tif"


- After successfully running :ref:`convertScanImageTiffToVolume`, there will be a single `.h5` file containing extracted data.

.. _step1_outputs:

Outputs
#######

The HDF5 file contains imaging data and metadata for the dataset. Below is a detailed description of the structure and contents of the HDF5 file.

File Structure
""""""""""""""

The HDF5 file is structured into groups and datasets to store the imaging data. The main components are as follows:

- **Groups**: The file contains several groups, each representing a different file and plane of imaging data.
- **Attributes**: Metadata associated with each group and dataset.

The following is an example structure of the HDF5 file:

.. code-block:: MATLAB

    Filename: 'C:\Users\<username>\MH184_both_6mm_FOV_150_600um_depth_410mW_9min_no_stimuli_00001_00001.h5'
    Name: '/'
    Groups:
        /file_1
        /file_2
        /file_3
    Datasets: []
    Datatypes: []
    Links: []
    Attributes: []

Groups and Datasets
"""""""""""""""""""

Each group represents a different file and contains multiple planes of imaging data. For example:

.. code-block:: MATLAB

    Filename: 'C:\Users\RBO\Documents\data\bi_hemisphere\extracted\MH184_both_6mm_FOV_150_600um_depth_410mW_9min_no_stimuli_00001_00001.h5'
    Name: 'plane_1'
    Datatype: [1×1 struct]
    Dataspace: [1×1 struct]
    ChunkSize: [1165 1202 1]
    FillValue: 0
    Filters: [1×1 struct]
    Attributes: [30×1 struct]


- **/file_1** - **/file_N**: Each group corresponds to a different file, where `N` is the total number of files.
- **/file_N/plane_1** through **/file_N/plane_M**: Each subgroup represents a different plane within the file, where `M` is the number of planar time-series.

Attributes hold metadata about the dataset, including details about the imaging process, dimensions, and other relevant information.

Example Usage
"""""""""""""

You can access the HDF5 file contents using MATLAB commands as follows:

.. code-block:: MATLAB

    % Load HDF5 file information
    info = h5info('C:\Users\RBO\Documents\data\bi_hemisphere\extracted\MH184_both_6mm_FOV_150_600um_depth_410mW_9min_no_stimuli_00001_00001.h5');

    % Access information about a specific plane
    plane_info = h5info('C:\Users\RBO\Documents\data\bi_hemisphere\extracted\MH184_both_6mm_FOV_150_600um_depth_410mW_9min_no_stimuli_00001_00001.h5', '/file_1/plane_1');

This provides detailed information about the file structure, groups, datasets, and attributes, helping you to navigate and understand the contents of the HDF5 file.

------------------------------------
2. Piecewise-Rigid Motion-Correction
------------------------------------

.. image:: ../_static/_images/storage_rec.png
   :width: 1440

Motion correction relies on _`NoRMCorre` for piecewise-rigid motion correction resulting in shifts for each patch.

.. image:: ../_static/_images/patches.png
   :width: 1440

To run motion-correction, call `motionCorrectPlane()`:

.. code-block:: MATLAB

    mcpath = 'C:\Users\RBO\Documents\data\bi_hemisphere\registration';
    motionCorrectPlane(extract_path, mcpath, 23, 1, 3);

- extract_path should point to your re-assembled `.h5`
- The output is a 2D column vector [x, y] with shifts that allow you to reconstruct the motion-corrected movie with _`core.utils.translateFrames`.
- shifts(:,1) represent pixel-shifts in *x*
- shifts(:,2) represent pixel-shifts in *y*

.. code-block:: MATLAB

   >> help translateFrames

     translateFrames Translate image frames based on provided translation vectors.

      This function applies 2D translations to an image time series based on
      a series of translation vectors, one per frame. Each frame is translated
      independently, and the result is returned as a 3D stack of
      (Height x Width x num_frames) translated frames.

      Inputs:
        Y - A 3D time series of image frames (Height x Width x Number of Frames).
        t_shifts - An Nx2 matrix of translation vectors for each frame (N is the number of frames).

      Output:
        translatedFrames - A 3D array of translated image frames, same size and type as Y.


Perform both piecewise-rigid motion correction using `NormCORRe`_ to stabilize the imaging data. Each plane is motion corrected sequentially, so
only a single plane is ever loaded into memory due to large LBM filesizes (>35GB). A template of 150 frames is used to initialize a "reference image".

This image is your "ground truth" per-se, it is the image you want to most accurately represent the movement in your video.

For input, use the same directory as `savePath` parameter in :ref:`convertScanImageTiffToVolume`.

Metrics:

.. image:: ../_static/_images/motion_metrics.png
   :width: 1440

