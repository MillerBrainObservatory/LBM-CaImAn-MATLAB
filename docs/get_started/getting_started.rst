
###############
Getting Started
###############

Dependencies
============

Before running your first dataset, you should ensure that all dependencies of the pipeline are satisfied.

This pipeline requires the parallel pool, statistics and machine learning, and image processing toolboxes.

To see what toolboxes you have installed, use :code:`ver` in the MATLAB command window:

.. code-block:: MATLAB

   >> ver
    ----------------------------------------------------------------------------------------------------------------
    MATLAB Version: 24.1.0.2537033 (R2024a)
    MATLAB License Number: 41007384
    Operating System: Linux 6.2.0-36-generic #37~22.04.1-Ubuntu SMP PREEMPT_DYNAMIC Mon Oct  9 15:34:04 UTC 2 x86_64
    Java Version: Java 1.8.0_202-b08 with Oracle Corporation Java HotSpot(TM) 64-Bit Server VM mixed mode
    ----------------------------------------------------------------------------------------------------------------
    MATLAB                                                Version 24.1        (R2024a)
    Computer Vision Toolbox                               Version 24.1        (R2024a)
    Curve Fitting Toolbox                                 Version 24.1        (R2024a)
    Global Optimization Toolbox                           Version 24.1        (R2024a)
    Image Processing Toolbox                              Version 24.1        (R2024a)
    Optimization Toolbox                                  Version 24.1        (R2024a)
    Parallel Computing Toolbox                            Version 24.1        (R2024a)
    Signal Processing Toolbox                             Version 24.1        (R2024a)
    Statistics and Machine Learning Toolbox               Version 24.1        (R2024a)
    Wavelet Toolbox                                       Version 24.1        (R2024a)


If the user choses to split frames across multiple `.tiff` files, there will be multiple tiff files in ascending order
of an suffix appended to the filename: `_000N`, where n=number of files chosen by the user.

.. important::

    All output .tiff files for a single imaging session should be placed in the same directory.
    No other .tiff files should be in this directory. If this happens, an error will throw.

Directory Structure
===================

The following is an example of the directory hierarchy
used for the demo.

.. code-block:: text

    Parent
    ├── raw/
    │   └── basename_00001_0001.tiff
    │   └── basename_00001_0002.tiff
    │   └── basename_00001_00NN.tiff
    ├── extraction/
    │   └── basename_plane_1.h5
    │   └── basename_plane_2.h5
    │   └── basename_plane_NN.h5
    │   └── figures/
    │       └── scan_offset_validation.png
    │       └── roi_1_offset_validation.png
    │       └── roi_2_offset_validation.png
    │       └── roi_N_offset_validation.png
    ├── registration/
    │   └── motion_corrected_plane_1.h5
    │   └── motion_corrected_plane_2.h5
    │   └── motion_corrected_plane_NN.h5
    │   └── figures/
    │       └── motion_corrected_metrics_plane_1.png
    │       └── motion_corrected_metrics_plane_2.png
    │       └── motion_corrected_metrics_plane_RR.png
    └── segmentation/
    │   └── segmented_plane_1.h5
    │   └── segmented_plane_2.h5
    │   └── segmented_plane_NN.h5
    └── axial_correction/
    │   └── segmented_plane_1.h5
    │   └── segmented_plane_2.h5
    │   └── segmented_plane_NN.h5
    └── figures/
        └── WIP/

- `N` = the number of `[Y, X, T]` planar time-series.
- `R` = the number of `[Y, X, T]` ROI's per scanfield.

Following the recommendation described in :ref:`install recommendation` all necessary functions should already be on your
MATLAB path. If an error is encountered, such as:

.. code-block:: MATLAB

    Undefined function 'convertScanImageTiffToVolume' for input arguments of type 'char'.


This means the input is not on your MATLAB path. Add this to the top of the script you are running:

 .. code-block:: MATLAB

    [fpath, fname, ~] = fileparts(fullfile(mfilename('fullpath'))); % path to this script
    addpath(genpath(fullfile(fpath, 'core/')));

You can make sure all of the requirements for the package are in the path with the following:

 .. code-block:: MATLAB

    result = validate_toolboxes(); % make sure we have dependencies in accessible places
    if ischar(result)
        error(result);
    else
        disp('Proceeding with execution...');
    end

It is helpful to first set-up directories where youd like your results to go. Each core function in this pipeline takes a "data" path and a "save" path as arguments. Following the :ref:`Directory Structure`:

.. thumbnail:: ../_static/_images/output_paths.png
   :download: true
   :align: center

