.. _pre_processing:

Pre-Processing
#############################

Function for this step: :func:`convertScanImageTiffToVolume()`

Before beginning pre-processing, follow setup steps in :ref:`first steps` started` to make sure the pipeline and dependencies are installed properly.
After that, review :ref:`parameters` to understand the general usage of each function going forward.

See :ref:`troubleshooting` for common issues you may encounter along the way.

Extraction Overview
*********************************

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

Extraction Inputs
****************************************

This example follows a directory structure shown in :ref:`Directory Structure`. Inputs and outputs can be anywhere the user wishes.

.. code-block:: MATLAB

    parent_path = 'C:\Users\<username>\Documents\data\bi_hemisphere\'; %
    raw_path = [ parent_path 'raw\']; % where our raw .tiffs go
    extract_path = [ parent_path 'extracted\'];
    mkdir(extract_path); mkdir(raw_path);

:func:`convertScanImageTiffToVolume()` takes the standard :ref:`parameters <params>` inputs. The most useful of which are:

`raw_path`
: This is where your raw `.tiff` files will be stored and is the first argument of :func:`convertScanImageTiffToVolume`.

`extract_path`
: is where our processed timeseries will be saved.

.. note::

    - Your raw and extract path can be in any folder you wish without worry of file-name conflicts.
    - All future pipeline steps will automatically exclude these files as they will not have the characters `_plane_` in the filename.
    - Don't put the characters `_plane_` together in your raw/extracted filenames!

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

.. _extraction_outputs:

Extraction Outputs
****************************************************************

.. _extraction_format:

Format
-------------

Output data are saved in `.h5` format, with the following characteristics:
- one file per plane
- named "extraction_plane_N.h5"
- metadata saved as attributes

You can use :code:`h5info(h5path)` in the MATLAB command window to reveal some helpful information about our data.

H5 Groups
----------------

The following is an example structure of the HDF5 file at the outermost level:

.. code-block:: MATLAB

    h5info(extract_path, '/extraction')

    Filename: 'C:\Users\<username>\MH184_both_6mm_FOV_150_600um_depth_410mW_9min_no_stimuli_00001_00001.h5'
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
- **Attributes**: Attributes are special "tags" attached to a group. This is where we store metadata associated with each group and dataset. The result of calling `get_metadata(raw_path)` (see :ref:`scanimage metadata` for more information about the magic behind the scenes here).

.. _eval_outputs:

Evaluate outputs
*************************

For more examples of loading and manipulating data, see :ref:`exploring datasets`

In your `save_path`, you will see a newly created `figures` folder. This contains an image for each [X,Y,T] plane and checks for proper tiling.

Offset and Z Plane Quality
-----------------------------

In this folder is a close-up of the brightest image in every plane for a random frame. Each
image shoes the neuron before and after scan-correction. This lets you compare planes, validate the correct
scan-phase offset value (usually 1, 2 or 3 pixels).

We can see that our plane quality changes with depth:

.. thumbnail:: ../_images/ex_offset.svg
    :width: 800
    :title: Phase-Offset
    :align: center
    :group: finish

