.. _pre_processing:

Pre-Processing
==============

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
- :ref:

.. note::

   For detailed documentation in your MATLAB editor, use:

   >> help FunctionName
   >> help convertScanImageTiffToVolume

Directory Structure
===================

The following is an example of the directory hierarchy
used for the demo.

.. code-block:: text

    Parent
    ├── raw
    │   ├── scanimage .tiff files live here
    │   └── basename_00001_0001.tiff
    │   └── basename_00001_0002.tiff
    │   └── basename_00001_00NN.tiff
    ├── extraction
    │   └── basename.h5
    ├── registration
    │   └── shift_vectors_plane_N.h5
    └── segmentation
        └── caiman_output_plane_.h5

    .. where N = the number of [X, Y, Z] time-series (planes)

Following the recommendation described in :ref:`installation` all necessary functions should already be on your
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

.. code-block:: MATLAB

    convertScanImageTiffToVolume(raw_path, extract_path, 0, 'fix_scan_phase', false);

Our data are now saved as a single hdf5 file separated by file and by plane. This storage format
makes it easy to motion correct each time-series individually. We will be processing small patches of the total image,
roughly 20um in parallel, so attempting to process multiple time-series will drastically slow down NormCorre.

The key parameter "fix_scan_phase" will use Bi-Directional phase correlations to determine the lateral shift
between each line (row) of each ROI.

2. Motion Correction:

Motion correction can simply take the extract_path as the first input parameter pointing to these newly extracted

.. code-block:: MATLAB

    mdata = get_metadata(fullfile(metapath, metaname));
    mdata.base_filename = "MH184_both_6mm_FOV_150_600um_depth_410mW_9min_no_stimuli_00001";

    mcpath = 'C:\Users\RBO\Documents\data\bi_hemisphere\registration';
    motionCorrectPlane(extract_path, 23, 1, 3);
>>>>>>> 8525d04210bfd98c0baf181202d6df72ce66c118

