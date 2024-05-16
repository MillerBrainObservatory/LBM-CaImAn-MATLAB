

Pre-Processing
#######################################

Before beginning pre-processing, follow setup steps in :ref:`getting started` to make sure the pipeline and dependencies are installed properly.
See :ref:`troubleshooting` for common issues.

Pre-processing LBM datasets consists of 2 main processing steps:

1. Reshaping vertically concatenated strips into horizontally concatenated strips
2. Piecewise motion-correction

.. _pipeline step 1:

1. Re-Construct Volumetric Time-Series
================================================================

Before processing starts, the raw scanimage output needs to be reconstructed to form a correctly-ordered time-series.
This is accomplished through the use of :func:`convertScanImageTiffToVolume`.


Shown in the image below is a graphical representation of this reconstruction.

In its raw form (see A in the below figure), ScanImage tiff files are multipage tiffs - like a book. Each page
is one *image*, but it doesn't look like an image:

.. image:: ../_static/_images/abc_strip.png
   :width: 1440

| A: In the above image, represents vertically concatenated **strip** of our image.
| B: Strips are cut and horizontally concatenated.
| C: After a scan-phase correction, lines between strips become unnoticable (ideally)

If you were to open up a raw ScanImage .tiff file in ImageJ, you would see a very long, thin bar as is shown in A.

Each Z-Plane is written before moving onto the next timestep:

- z-plane 1 @ timepoint 1, z-plane 2 @ timepoint 1, z-plane 3 @ timepoint 1, etc.

Thus, another task :func:`convertScanImageTiffToVolume` accomplishes are reordering this tiff stack to be:

- z-plane 1 @ timepont 1, z-plane 1 @ timepoint 2, etc ..

The output `volumetric time-series` has dimensions `[Y,X,Z,T]`.

If the user chooses to split frames across multiple `.tiff` files, there will be multiple tiff files in ascending order
of a suffix appended to the filename: `_000N`, where n=number of files chosen by the user.

.. important::

    All output .tiff files for a single imaging session should be placed in the same directory.
    No other .tiff files should be in this directory. If this happens, an error will throw.

You can chain the output of one function to the input of another. Note the path names match :ref:`Directory Structure`.

.. code-block:: MATLAB

    parent_path = 'C:\Users\<username>\Documents\data\bi_hemisphere\'; %
    raw_path = [ parent_path 'raw\']; % where our raw .tiffs go
    extract_path = [ parent_path 'extracted\'];
    mkdir(extract_path); mkdir(raw_path);

In this example, `raw_path` is where your raw `.tiff` files will be stored and is the first parameter of :func:`convertScanImageTiffToVolume`.


Our data are now saved as a single hdf5 file separated by file and by plane. This storage format
makes it easy to motion correct each time-series individually. We will be processing small patches of the total image,
roughly 20um in parallel, so attempting to process multiple time-series will drastically slow down NormCorre.

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


- After successfully running :func:`convertScanImageTiffToVolume`, there will be a single `.h5` file containing extracted data.

.. _step1_outputs:

The H5 file contains imaging data and metadata for the dataset. Below is a detailed description of the structure and contents of the HDF5 file.

File Structure
****************************************************************

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
****************************************************************

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

Due to this organization, to retrieve a 3D time-series for a single Z-plane, you must collect individual time-series from each file.

:ref:`combinePlanes` will do this for you given the path to the h5file and the index of which plane you wish to aquire.

.. code-block:: MATLAB

    z_time_series = combinePlanes(h5path, 3);
    figure; imagesc(z_time_series(:,:,2)); axis image;

Example Usage
****************************************************************

You can access the HDF5 file contents using MATLAB commands as follows:

.. code-block:: MATLAB

    % Load HDF5 file information
    info = h5info('C:\Users\RBO\Documents\data\bi_hemisphere\extracted\MH184_both_6mm_FOV_150_600um_depth_410mW_9min_no_stimuli_00001_00001.h5');

    % Access information about a specific plane
    plane_info = h5info('C:\Users\RBO\Documents\data\bi_hemisphere\extracted\MH184_both_6mm_FOV_150_600um_depth_410mW_9min_no_stimuli_00001_00001.h5', '/file_1/plane_1');

2. Piecewise-Rigid Motion-Correction
================================================================

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

For input, use the same directory as `savePath` parameter in :func:`convertScanImageTiffToVolume`.

Metrics:

.. image:: ../_static/_images/motion_metrics.png
   :width: 1440

