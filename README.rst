.. _overview:

Light Beads Microscopy Pipeline
===============================

.. image:: docs/_static/overlays.png
   :width: 40pt

A pipeline for processing light beads microscopy (LBM) datasets.

LBM is a *scalable*, *spatiotemporally optimal* aquisition approach limited only by flourescence lifetime.
For background, theory and design of LBM technology, see the reference `publication`_.

Currently, this pipeline is optimized to extract data aquired through the `ScanImage`_ software package.


Resources
---------

- DataSheet_: benchmarks, parameters and filesizes.

- `google slides`_ : images and descriptions of the inner workings of this pipeline.

- Additional information on how to collaborate with the Miller Brain Observatory at the MBO website_.

Steps
-----

There are 4 steps corresponding to 4 core functions (more details in `Usage`_):

1. Convert ScanImage .Tiff to 4D [x, y, z, t] array.
    - convertScanImageTiffToVolume

2. Piecewise rigid motion correction.
    - motionCorrectPlane

3. Plane-by-plane 2D neuronal segmentation and deconvolution.
    - segmentPlane

4. Z Offset Correction.
    - segmentPlane

.. _algorithms:

Algorithms
----------

- `CNMF`_ segmentation and neuronal source extraction.
- `NoRMCorre`_ piecewise rigid motion correction.
- `constrained-foopsi`_ constrained deconvolution spike inference.

.. _requirements:

Requirements
------------

- MATLAB (Tested on 2023a, 2023b, 2024b)
- Toolboxes:
    - Parallel Computing Toolbox
    - Statistics and Machine Learning Toolbox
    - Image Processing Toolbox

.. _installation:

Installation
============

Modern versions of MATLAB (2017+) solve most Linux/Windows filesystem conflicts. Installation is similar independent of OS.


**Find matlab install location**::

    By default, MATLAB is installed in the following locations:
    Windows (64-bit):
        - C:\Program Files\MATLAB\R20XXx (64-bit MATLAB)
        - C:\Program Files (x86)\MATLAB\R20XXx (32-bit MATLAB)
    Windows (32-bit):
        - C:\Program Files\MATLAB\R20XXx
    Linux:
        - /usr/local/MATLAB/R20XXx
    Mac:
        - /Applications/MATLAB_R20XXx.app

To find your install location:

.. code-block:: MATLAB

    >> matlabroot
        ans =
            'C:\Program Files\MATLAB\R2023b'

The location of the installation is often desirably placed in `~/Documents/MATLAB/`, as this is on the MATLAB path.
If you put the root directory elsewhere, you will need to navigate to that directory within the matlab GUI or:

.. code-block:: MATLAB

   >> addpath(genpath("path/to/caiman_matlab"))

Windows/WSL2
------------

If you have MATLAB installed on Windows, you won't be able to run commands from within WSL (i.e. //wsl.localhost/)
due to the separate filesystems. Pay attention to which environment you install (see `this`_ discussion).

The easiest installation method is one of the following:

- install with git is via `mysys <https://gitforwindows.org/>`_

- download the code from code/Download.zip button on github and unzip to a directory of your choosing **on the windows C:// path** and access via:


.. code-block:: bash

   $ cd /mnt/c/Users/<Username>/<project-install-path>


In Linux, Mac, WSL or mysys, clone with the pre-installed git client:

.. code-block:: bash

    $ cd ~/Documents/MATLAB
    $ git clone https://github.com/ru-rbo/caiman_matlab.git
    $ cd caiman_matlab
    $ matlab

.. _usage:

Usage
=====

Pre-processing
--------------

The raw output of an ScanImage MROI acquisition is a `tiff` (or series of tiffs) with metadata attached to the `artist` tag where:

- Each ROI’s image is stacked one on top of the other vertically.

- Each plane is written before moving onto the next frame, e.g.:

- plane 1 timepoint 1, plane 2 timepoint 1, plane 3 timepoint 1, etc.

- Frames may be split across multiple files if this option is specified the ScanImage configuration.

If the user choses to split frames across multiple `.tiff` files, there will be multiple tiff files in ascending order of an suffix appended to the filename: `_000N`, where n=number of files chosen by the user:

Single File:
- sessionX_00001.tiff

Multi File (<10):
- sessionX_00001_00001.tiff
- sessionX_00001_00002.tiff

Multi File (>=10):
- sessionX_00001_00001.tiff
- sessionX_00001_00002.tiff
- ...
- sessionX_00001_00010.tiff

Be careful to make sure that:

- Each session (series of .tiff files) should be in same directory.

- No other .tiff files should be in this directory. If this happens, an error will throw.

De-interleaving planes/frames is done via :code:`convertScanImageTiffToVolume`

| Run 'help <function>' in the command window for a detailed overview on function parameters, outputs and examples.

.. _convertScanImageTiffToVolume:

.. code-block:: MATLAB

   >> help convertScanImageTiffToVolume
     convertScanImageTiffToVolume Convert ScanImage .tif files into a 4D volume.

      Convert raw `ScanImage`_ multi-roi .tif files from a single session
      into a single 4D volume (x, y, z, t). It's designed to process files for the
      ScanImage Version: 2016 software.

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
      .. code-block:: MATLAB

            % Path to data, path to save data, diagnostic flag
            convertScanImageTiffToVolume('C:/data/session1/', 'C:/processed/', 0);
            convertScanImageTiffToVolume('C:/data/session1/', 'C:/processed/', 1); % just display files

      See also fileparts, addpath, genpath, isfolder, dir, fullfile, error, regexp, savefast

**Output**

- After successfully running `convertScanImageTiffToVolume`, there will be a series of `.mat` files matching the number of raw `.tiff` files.
- Each `.mat` contains the following fields:
    - Y: 4D (x,y,z,t) volume
    - metadata: struct of metadata retrieved through `get_metadata`

See `notebooks/Strip_Exploration` for a walkthrough on how ScanImage trims pixels and concatenates adjacent strips into a single image.

Motion-correction
-----------------

Perform both piecewise-rigid motion correction using `NormCORRe`_ to stabilize the imaging data.

For input, use the same directory as `savePath` parameter in `convertScanImageTiffToVolume`_.

.. code-block:: MATLAB

    >> help motionCorrectPlane
      motionCorrectPlane Perform rigid and non-rigid motion correction on imaging data.

      This function processes imaging data by sequentially loading individual
      processed planes, applying rigid motion correction to generate a template,
      followed by patched non-rigid motion correction. Each motion-corrected plane
      is saved separately with relevant shifts and metadata.

      Parameters
      ----------
      filePath : char
          Path to the directory containing the raw .tif files.
      numCores : double, integer, positive
          Number of cores to use for computation. The value is limited to a maximum
          of 24 cores. If more than 24, it defaults to 23.
      startPlane : double, integer, positive
          The starting plane index for processing.
      endPlane : double, integer, positive
          The ending plane index for processing. Must be greater than or equal to
          startPlane.

      Returns
      -------
      Each motion-corrected plane is saved as a .mat file containing the following:
      shifts : array
          2D motion vectors as single precision.
      metadata : struct
          Struct containing all relevant metadata for the session.

      Notes
      -----
      - Only .mat files containing processed volumes should be in the filePath.
      - Any .mat files with "plane" in the filename will be skipped to avoid
        re-processing a previously motion-corrected plane.

      See also addpath, gcp, dir, error, fullfile, fopen, regexp, contains, matfile, savefast

This function uses NoRMCorre for piecewise-rigid motion correction resulting in shifts for each patch. The output is a 2D column vector [x, y]
with shifts that allow you to reconstruct the motion-corrected movie with `core.utils.translateFrames`.

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

See `notebooks/MC_Exploration` for a walkthrough on analyzing motion-corrected videos.

Segmentation and Deconvolution
------------------------------

Segment the motion-corrected data and extract neuronal signals.

.. code-block:: MATLAB

   >> help segmentPlane

      segmentPlane Segment imaging data using CaImAn for motion-corrected data.

      This function applies the CaImAn algorithm to segment neurons from
      motion-corrected, pre-processed and ROI re-assembled MAxiMuM data.
      The processing is conducted for specified planes, and the results
      are saved to disk.

      Parameters
      ----------
      path : char
          The path to the local folder containing the motion-corrected data.
      diagnosticFlag : char
          When set to '1', the function reports all .mat files in the directory
          specified by 'path'. Otherwise, it processes files for neuron segmentation.
      startPlane : char
          The starting plane index for processing. A non-numeric input or '0' sets
          it to default (1).
      endPlane : char
          The ending plane index for processing. A non-numeric input or '0' sets
          it to default (maximum available planes).
      numCores : char
          The number of cores to use for parallel processing. A non-numeric input
          or '0' sets it to the default value (12).

      Outputs
      -------
        - T_keep: neuronal time series [Km, T] (single)
        - Ac_keep: neuronal footprints [2*tau+1, 2*tau+1, Km] (single)
        - C_keep: denoised time series [Km, T] (single)
        - Km: number of neurons found (single)
        - Cn: correlation image [x, y] (single)
        - b: background spatial components [x*y, 3] (single)
        - f: background temporal components [3, T] (single)
        - acx: centroid in x direction for each neuron [1, Km] (single)
        - acy: centroid in y direction for each neuron [1, Km] (single)
        - acm: sum of component pixels for each neuron [1, Km] (single)

      Notes
      -----
        - The function handles large datasets by processing each plane serially.
        - Ensure your RAM capacity exceeds the size of a single plane.
        - The segmentation settings are based on the assumption of 9.2e4 neurons/mm^3
            density in the imaged volume as seen in the mouse cortex.

      See also addpath, fullfile, dir, load, savefast

Segmentation has the largest computational and time requirements.

**Output**

The output of :code:`segmentPlane` is a series of .mat files named caiman_output_plane_N.mat, where N=number of planes.

Z Calibration and Alignment
---------------------------

    You will need to be in a GUI environment for this step. Calculate offset will show you two
    images, click the feature that matches in both images.

.. code-block:: MATLAB

   calculate_offset('C:\\Data\\calibration\\');  # Path to calibration data
   compare_planes_new('C:\\Data\\session1\\aligned\\');  # Path to data for final alignment

Copyright\ |copy| 2024 Elizabeth. R. Miller Brain Observatory | The Rockefeller University. All rights reserved.

.. _CaImAn: https://github.com/flatironinstitute/CaImAn-MATLAB/
.. _ScanImage: https://www.mbfbioscience.com/products/scanimage/
.. _publication: https://www.nature.com/articles/s41592-021-01239-8/
.. _MROI: https://docs.scanimage.org/Premium%2BFeatures/Multiple%2BRegion%2Bof%2BInterest%2B%28MROI%29.html#multiple-region-of-interest-mroi-imaging/
.. _DataSheet: https://docs.google.com/spreadsheets/d/13Vfz0NTKGSZjDezEIJYxymiIZtKIE239BtaqeqnaK-0/edit#gid=1933707095/
.. _website: https://mbo.rockefeller.edu/
.. _google slides: https://docs.google.com/presentation/d/1A2aytY5kBhnfDHIzNcO6uzFuV0OJFq22b7uCKJG_m0g/edit#slide=id.g2bd33d5af40_1_0/
.. _NoRMCorre: https://github.com/flatironinstitute/NoRMCorre/
.. _constrained-foopsi: https://github.com/epnev/constrained-foopsi/
.. _startup: https://www.mathworks.com/help/matlab/matlab_env/matlab-startup-folder.html
.. _mroi_function: https://docs.scanimage.org/Appendix/ScanImage%2BUtility%2BFunctions.html#generate-multi-roi-data-from-tiff
.. _BigTiffSpec: _https://docs.scanimage.org/Appendix/ScanImage%2BBigTiff%2BSpecification.html#scanimage-bigtiff-specification

.. |copy|   unicode:: U+000A9 .. COPYRIGHT SIGN
