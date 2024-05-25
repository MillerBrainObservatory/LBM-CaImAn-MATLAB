

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

In its raw form (see A in the below figure), ScanImage tiff files are multipage tiffs - like a book.

Each page is one *image*, but it doesn't look like an image:

.. thumbnail:: ../_static/_images/abc_strip.png
   :width: 1440

| A: In the above image, represents vertically concatenated **strip** of our image.
| B: Strips are cut and horizontally concatenated.
| C: After a scan-phase correction, lines between strips become unnoticable (ideally)

**If you were to open up a raw ScanImage .tiff file in ImageJ, you would see a very long, thin bar as is shown in A.**

- Each Z-Plane is written before moving onto the next timestep
- z-plane 1 @ timepoint 1, z-plane 2 @ timepoint 1, z-plane 3 @ timepoint 1, etc.

Thus, another task :func:`convertScanImageTiffToVolume` accomplishes are reordering this tiff stack to be:

- z-plane 1 @ timepont 1, z-plane 1 @ timepoint 2, etc ..

The output `volumetric time-series` has dimensions `[Y,X,Z,T]`.

If the user chooses to split frames across multiple `.tiff` files, there will be multiple tiff files in ascending order
of a suffix appended to the filename: `_000N`, where n=number of files chosen by the user.

.. important::

    All output .tiff files for a single imaging session should be placed in the same directory.
    No other .tiff files should be in this directory. If this happens, an error will throw.


Extraction Input
****************************************************************

First, we set up our directory paths. You can chain the output of one function to the input of another. Note the path names match :ref:`Directory Structure`:

.. code-block:: MATLAB

    parent_path = 'C:\Users\<username>\Documents\data\bi_hemisphere\'; %
    raw_path = [ parent_path 'raw\']; % where our raw .tiffs go
    extract_path = [ parent_path 'extracted\'];
    mkdir(extract_path); mkdir(raw_path);

.. note::

    The term "parameter" throughout this guide refers to the inputs to each function.
    For example, running "help convertScanImageTiffToVolume" in the command window will
    show to you and describe the parameters of that function.

This is all you need to start processing your data. Actually, it's quite more than you need.

`raw_path` is where your raw `.tiff` files will be stored and is the first parameter of :func:`convertScanImageTiffToVolume`.
`extract_path` is where our data will be saved, and is the second parameter.
- Your raw and extract path can be in any folder you wish without worry of file-name conflicts.
- All future pipeline steps will automatically exclude these files as they will not have the characters `_plane_` in the filename.

.. note::

   Don't put the characters `_plane_` together in your raw/extracted filenames!

`diagnostic_flag` is the next parameter, setting this to 1, '1', or true will display the detected files that would be processed, and stop. This is helpful for controlling which files are processed.

`overwrite`, similar to diagnostic flag, can be set to 1, '1', or true to enable overwriting any previously extracted data. Otherwise, a warning will show and no data will be saved.

`fix_scan_phasee` is a very important parameter: it attempts to maximize the phase-correlation between each line (row) of each strip, as shown below.

.. thumbnail:: ../_static/_images/corr_nocorr_phase_example.png
   :width: 1080

This example shows that shifting every *other* row of pixels +2 (to the right) in our 2D reconstructed image will maximize the correlation between adjacent rows.

Extraction Output
****************************************************************

Our data are now saved as a single h5 file separated by file and by plane. This storage format
makes it easy to motion correct each 3D planar time-series individually. We will be processing small patches of the total image,
roughly 20um in parallel, so attempting to process multiple time-series will drastically slow down NormCorre.
After successfully running :func:`convertScanImageTiffToVolume`, there will be a single `.h5` file containing extracted data.

You can use :code:`h5info(h5path)` in the MATLAB command window to reveal some helpful information about our data.

The following is an example structure of the HDF5 file at the outermost level:

.. code-block:: MATLAB

    h5info(extract_path, '/')

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

We see here that our "parent" group has 3 subgroups corresponding to the number of raw .tiff files. Lets explore one of these "file" subgroups:

.. code-block:: MATLAB

    >> h5info(extract_path, '/file_1')

    info =

      struct with fields:

          Filename: 'C:\Users\RBO\Documents\data\bi_hemisphere\extracted\MH184_both_6mm_FOV_150_600um_depth_410mW_9min_no_stimuli_00001_00001.h5'
              Name: '/file_1'
            Groups: []
          Datasets: [30×1 struct]
         Datatypes: []
             Links: []
        Attributes: []

We see that there are 30 datasets corresponding to each of our Z-planes, but no groups or attributes. That information is stored within each plane:

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

- **Groups**: h5 files can be thought of like directories where a 3D time-series is self contained within its own folder (or group).
- **Attributes**: Attributes are special "tags" attached to a group. This is where we store metadata associated with each group and dataset. The result of calling `get_metadata(raw_path)` (see :ref:`scanimage metadata` for more information about the magic behind the scenes here).

Due to this organization, to retrieve a 3D time-series for a single Z-plane, you must collect individual time-series from each file.

:func:`combinePlanes` will do this for you given the path to the h5file and the index of which plane you wish to aquire.

.. code-block:: MATLAB

    % retrieve a 3D time-series for the third z-plane
    z_time_series = combinePlanes(h5path, 3);

    % visualize the second timestep
    figure; imagesc(z_time_series(:,:,2)); axis image;

.. thumbnail:: ../_static/_images/quickview_blue.png
   :group: ck
   :align: center

2. Piecewise-Rigid Motion-Correction
================================================================

For a quick demo on how to run motion correction, see the demo_registration.m script.

.. note::

   The terms motion-correction and registration are often used interchangably.

The goal of motion correction is to make sure that our neuron in the first frame is in the same spatial location as in frame N throughout the time-series.
Natural movement by the animal during experimental tasks can cause our images spatial potition varying slightly frame by frame. The extent of this movement can also vary widely depending
on the type of task the animal is performing.

For this reason, it is *very* important for the researcher to verify that any motion artifacts in the movie are removed before moving onto any subsequent computations.

Rigid vs Non-Rigid
*******************

The motion artifacts present in a movie also come in two flavors, `rigid` and `non-rigid`.
Purely rigid motion is simple, straightforeward movement that applies to each-and-every pixel equally.
The entire 2D image is shifted by a number of pixels in the x direction and y direction.

Non-rigid artifacts are much more complex as one region of the 2D image requires shifts that another region does not.

Motion correction relies on _`NoRMCorre` for piecewise-rigid motion correction resulting in shifts for each patch.

.. thumbnail:: ../_static/_images/patches.png
   :width: 1440

To run motion-correction, call `motionCorrectPlane()`:

.. code-block:: MATLAB

    % recall our directory structure, chaining the output path from the
    % tiff reconstruction step
    mcpath = 'C:\Users\RBO\Documents\data\bi_hemisphere\registration';

    % data_path, save_path, num_cores, start_plane, end_plane
    motionCorrectPlane(extract_path, mcpath, 23, 1, 3);

For input, use the same directory as `save_path` parameter in :func:`convertScanImageTiffToVolume`.

- `data_path`: Path to your extracted dataset.
- `save_path`: Path to save your data.
- `num_cores`: the number of CPU cores to dedicate to motion-correction.
- `start_plane`: The index of the first z-plane to motion-correct.
- `end_plane`: The index of the last z-plane to motion-correct.

.. note::

   Each Z-plane in between start_plane and end_plane will be processed. In the future we may want to provide a way to give an array of indices to correct e.g. if the user wants to throw out Z-planes.

Registration Output
************************

- The output is a 2D column vector [x, y] with shifts that allow you to reconstruct the motion-corrected movie with _`core.utils.translateFrames`.
- shifts(:,1) represent pixel-shifts in *x*
- shifts(:,2) represent pixel-shifts in *y*

Perform both piecewise-rigid motion correction using `NormCORRe`_ to stabilize the imaging data. Each plane is motion corrected sequentially, so
only a single plane is ever loaded into memory due to large LBM filesizes (>35GB). A template of 150-200 frames is used to initialize a "reference image".

.. thumbnail:: ../_static/_images/template1.png
    :title: Template Image
    :download: true

This image is your "ground truth" per-se, it is the image you want to most accurately represent the movement in your video.

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


.. thumbnail:: ../_static/_images/storage_rec.png
    :title: Recommended Data Storage Paradigm
    :download: true

Metrics
*************************

CaImAn provides some useful metrics to determine the effectiveness of registration.
These will be placed in the same directory as your save_path, `metrics/registration_metrics_plane_N`.

.. thumbnail:: ../_static/_images/motion_metrics.png
   :download: true

The top figure shows our shifts for rigid and non-rigid motion correction. This gives an idea what proportion of the movement corrected for can be attributed to rigid or non-rigid motion.
Underneath you see the rigid shifts for X and Y, respectively.

To view the video, use the function :func:`planeToMovie`, which can also zoom in on select areas of your movie::

    Inputs:
      data - 3D matrix of image data.
      filename - Name of the output video file.
      x - Horizontal coordinates.
      y - Vertical coordinates.
      frameRate - Frame rate of the output video.
      avgs - Number of frames to average.
      zoom - Zoom factors. (not implemented)
      decenter - Decentering offsets.
      crf - Constant Rate Factor for video quality.

