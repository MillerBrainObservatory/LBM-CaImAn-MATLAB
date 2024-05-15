.. _getting_started:

###############
Getting Started
###############

Dependencies
============

Before running your first dataset, you should ensure that all dependencies of the pipeline are satisfied.

This pipeline requires the parallel pool, statistics and machine learning, and image processing toolboxes.

.. code-block:: MATLAB

   ver


If the user choses to split frames across multiple `.tiff` files, there will be multiple tiff files in ascending order
of an suffix appended to the filename: `_000N`, where n=number of files chosen by the user.

.. important::

    All output .tiff files for a single imaging session should be placed in the same directory.
    No other .tiff files should be in this directory. If this happens, an error will throw.

There are 2 primary functions for pre-processing,

.. note::

   For detailed documentation in your MATLAB editor, use:

   >> help FunctionName
   >> help convertScanImageTiffToVolume

.. _directory structure:

Directory Structure
===================

The following is an example of the directory hierarchy
used for the demo.

.. code-block:: text

    Parent
    ├── raw
    │   └── basename_00001_0001.tiff
    │   └── basename_00001_0002.tiff
    │   └── basename_00001_00NN.tiff
    ├── extraction
    │   └── basename.h5
    ├── registration
    │   └── shift_vectors_plane_N.h5
    └── segmentation
        └── caiman_output_plane_.h5

where `N` = the number of `[X, Y, T]` planar time-series.

Following the recommendation described in :ref:`recommended-install` all necessary functions should already be on your
MATLAB path. If an error is encountered, such as:

.. code-block:: MATLAB

    Undefined function 'convertScanImageTiffToVolume' for input arguments of type 'char'.


This means the input is not on your MATLAB path. Add this to the top of the script you are running:

 .. code-block:: MATLAB

    [fpath, fname, ~] = fileparts(fullfile(mfilename('fullpath'))); % path to this script
    addpath(genpath(fullfile(fpath, 'core/')));

You can make sure all of the requirements for the package are in the path with the following:

 .. code-block:: MATLAB

    result = validateRequirements(); % make sure we have dependencies in accessible places
    if ischar(result)
        error(result);
    else
        disp('Proceeding with execution...');
    end

First, we set up our inputs/outputs.

You can chain the output of one function to the input of another. Note the path names match :ref:`Directory Structure`.

.. code-block:: MATLAB

    parentpath = 'C:\Users\RBO\Documents\data\bi_hemisphere\';
    raw_path = [ parentpath 'raw\'];
    extract_path = [ parentpath 'extracted2\'];
    mkdir(extract_path); mkdir(raw_path);
