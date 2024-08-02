.. _pre_processing:

Pre-Processing
#############################

Function for this step: :func:`convertScanImageTiffToVolume()`

.. hint::

    Before beginning pre-processing, be sure to review :ref:`parameters` as they are the same for each step
    in the pipeline and will not be covered in detail here.

    ..See :ref:`troubleshooting` for common issues you may encounter along the way.

.. _pp_overview:

Overview
===================

Pre-processing LBM datasets consists of 2 main processing steps:

1. :ref:`De-interleave <ex_deinterleave>` z-planes and timesteps.
2. :ref:`Correct Scan-Phase <ex_scanphase>` alignment for each ROI.
3. :ref:`Re-tile <ex_retile>` vertically concatenated ROI's horizontally.

.. thumbnail:: ../_images/ex_diagram.png
   :title:  Step 1: Image Extraction and Assembly

For a more in-depth look at the LBM datasets and accompanying metadata, see the :ref:`LBM metadata` guide on the MBO user documentation.

The output :ref:`volumetric time-series <terms>` has dimensions `[Y,X,Z,T]`.

.. important::

    All output .tiff files for a single imaging session should be placed in the same directory.
    No other .tiff files should be in this directory. If this happens, an error will throw.

.. _extraction_inputs:

Inputs
=====================

This example follows a directory structure shown in :ref:`the first steps guide <directory_structure>`.

Inputs and outputs can be (almost) anywhere you wish.

.. code-block:: MATLAB

    parent_path = 'C:\Users\<username>\Documents\data\high_res\';

    raw_path = [ parent_path 'raw\']; % where our raw .tiffs go
    extract_path = [ parent_path 'extracted\']; % where results are saved

:code:`data_path`
: This is where your raw `.tiff` files are located.

:code:`save_path`
: is where our processed timeseries will be saved.

.. note::

    - Files are saved with the string '_plane_' appended automatically, don't put the characters `_plane_` together in your raw/extracted filenames!

.. _scan_phase:

Scan Phase
-------------

In addition to the standard parameters, users should be aware of the implications that bidirectional scan offset correction has on your dataset.

The :code:`fix_scan_phase` parameter attempts to maximize the phase-correlation between each line (row) of each vertically concatenated strip.

This example shows that shifting every *other* row of pixels +2 (to the right) in our 2D reconstructed image will maximize the correlation between adjacent rows.

.. thumbnail:: ../_images/ex_phase.png

.. important::

    Checking for a scan-phase offset correction is computationally cheap, so it is recommended to keep this to true.

When every other row of our image if shifted by N pixels, adjacent rows that *are not* shifted now have a N number of 0's padded in between the rows that were shifted.

When this shift happens, the pipeline **automatically trims** those pixels because they longer contain valid calcium signal.

.. thumbnail:: ../_images/ex_scanphase_gif.gif
    :width: 800
    :align: center

You'll see the decreased gap between ROI's for the scan-offset corrected image, showing the 2 pixels removed from each edge accounting for the padded 0's.

.. _trim_pixels:

Trim Pixels off ROI's
-------------------------

There are times when the seam between re-tiled ROI's is still present.

Sometimes, this seam may not appear when frames are viewed individually, but are present in the :ref:`mean image <ex_meanimage>`.

The :code:`trim_pixels` parameter takes an array of 4 values as input corresponding to the number of pixels to trim on the left, right, top and bottom of each ROI.

.. code-block:: MATLAB

    trim_pixels = [4,4,8,0]

.. _extraction_outputs:

Outputs
=====================

.. _extraction_format:

Output data are saved in :code:`.h5` format, with the following characteristics:

- one file-per-plane

- named "extraction_plane_N.h5"

- metadata saved as attributes


H5 Groups
----------------

You can use :code:`h5info(h5path)` in the MATLAB command window to reveal some helpful information about our data.

For example, the following is an example structure of the :code:`.h5` file at the outermost level:

.. code-block:: MATLAB

    h5info(extract_path, '/extraction')

    Filename: 'C:\Users\<username>\high_res_dataset.h5'
    Name: '/extraction'
    Groups:
        /plane_1
        /plane_2
        /plane_3
        /plane_N
    Datasets: []
    Datatypes: []
    Links: []
    Attributes: []

We see here that our "parent" group has 3 subgroups corresponding to the number of raw .tiff files. Lets explore one of these "plane" subgroups:

We see that there are 30 datasets corresponding to each of our Z-planes, but no groups or attributes. That information is stored within each plane:

.. code-block:: MATLAB

    h5info(extract_path, '/plane_1')

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
- **Attributes**: Attributes are special "tags" attached to a group. This is where we store metadata associated with each group and dataset. The result of calling `get_metadata(raw_path)` (see :ref:`scanimage metadata <advanced_metadata>` for more information about the magic behind the scenes here).

.. _eval_outputs:

Validate Outputs
-------------------

In your :code:`save_path`, you will see a newly created :code:`figures` folder. This contains an image for each [X,Y,T] plane and checks for proper tiling.

In this folder is a close-up of the brightest image in every plane for a random frame.

Each image shoes the neuron before and after scan-correction.

This lets you compare planes, validate the correct scan-phase offset value (usually 1, 2 or 3 pixels).

We can see that our plane quality changes with depth:

.. thumbnail:: ../_images/ex_offset.svg
    :width: 800
    :title: Phase-Offset
    :align: center

Additionally, you can use this images to get an idea of values you want to use for registration.

For example, consider the below image:

.. thumbnail:: ../_images/ex_brightest_feature.png
    :width: 800
    :title: Brightest Feature
    :align: center

Taking the :ref:`pixel resolution <pixel_resolution>` of 

3μm from our metadata, we see this neuron is ~10μm wide.

We may then want to limit our :ref:`NoRMCorre Parameters <normcorre_params>` to only allow shifts of this size with :code:`max_shift=10/metadata.pixel_resolution`.

To get a sense of how much motion is present in your timeseries, see :ref:`tips and tricks: exploring datasets in MATLAB <explore_data_matlab>`

