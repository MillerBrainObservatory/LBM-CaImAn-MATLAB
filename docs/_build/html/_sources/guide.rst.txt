.. _overview:

Light Beads Microscopy Pipeline
===============================

A pipeline for processing light beads microscopy (LBM) datasets.

LBM is a *scalable*, *spatiotemporally optimal* aquisition approach limited only by flourescence lifetime.
For background, theory and design of LBM technology, see the reference `publication`_.

Currently, this pipeline is optimized to extract data aquired through the `ScanImage`_ software package.

Steps
_____

There are 4 steps corresponding to 4 core functions (more details in `Usage`_:

1. Convert ScanImage .Tiff to 4D [x, y, z, t] array.
    - convertScanImageTiffToVolume

2. Piecewise rigid motion correction.
    - motionCorrectPlane

3. Plane-by-plane 2D neuronal segmentation and deconvolution.
    - segmentPlane

4. Z Offset Correction.
    - segmentPlane

.. _extraction:

Data Extraction
---------------

The output of an ScanImage MROI acquisition is a `tiff` (or series of tiffs, see caveat_)
with metadata attached to the `artist` tag.
In the resulting `tiff`, each ROI’s image is stacked one on top of the other vertically.

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

Modern versions of matlab (2017+) solve most Linux/Windows filesystem conflicts. Installation is
similar independent of OS.

.. note::

    If you have MATLAB installed on Windows, you won't be able to run commands from within WSL (i.e. //wsl.localhost/)
    due to the separate filesystems. Pay attention to which environment you install.

Windows
-------

The easiest method to download this repository with git is via `mysys <https://gitforwindows.org/>`_
Or just download the code from code/Download.zip above and unzip to a directory of your choosing.

Unix (Linux/Mac)
----------------

The location of the installation is often in `~/Documents/MATLAB/`.
If you put the root directory elsewhere, you will need to navigate to that directory within the matlab GUI.

WSL2 (Windows Subsystem for Linux)
----------------------------------

If you have MATLAB installed on Windows and wish to use this repository from a WSL instance, see `this`_ discussion.
WSL2 is helpful for access to unix tools, in such cases you should keep the repository on the Windows `C:// drive`, and access via:

.. code-block:: bash

   $ cd /mnt/c/Users/<Username>/<project-install-path>

This pipeline has been tested on WSL2, Ubuntu 22.04. Though any debian-based distribution should work.

For unix environments:

.. code-block:: bash

    $ cd ~/Documents/MATLAB
    $ git clone https://github.com/ru-rbo/caiman_matlab.git
    $ cd caiman_matlab
    $ matlab

.. _usage:

Usage
-----

If the user choses to split frames across multiple `.tiff` files, there will be multiple tiff files in ascending order
of an suffix appended to the filename: `_000N`, where n=number of files chosen by the user.

- Each session (series of .tiff files) should be in same directory.
- No other .tiff files should be in this directory. If this happens, an error will throw.

.. important::

   For detailed documentation in your MATLAB editor, use:

   >> help FunctionName
   >> help convertScanImageTiffToVolume

   .. code-block::

        TODO: render the matlab output, link to wiki


1. Pre-processing:

Convert raw ScanImage .tif files into a 4D format for further processing

.. code-block:: MATLAB

    datapath = 'C:\\Users\\LBM_User\\Data\\Session1\\';  # Directory containing raw .tif files
    savepath = 'C:\\Users\\LBM_User\\Data\\Session1\\extracted_volumes\\';  # Output directory for 4D volumes
    convertScanImageTiffToVolume(datapath, savepath, 0);

2. Motion Correction:

Perform both piecewise-rigid motion correction using `NormCORRe`_ to stabilize the imaging data

.. code-block:: MATLAB

    filePath = 'C:\\Data\\';  # Path to the directory containing .mat files for processing
    fileNameRoot = 'session1_';  # Base filename to match for processing
    motionCorrectPlane(filePath, fileNameRoot, 24, 1, 10);  # Process from plane 1 to 10 using 24 cores

3. Segmentation and Deconvolution:

Segment the motion-corrected data and extract neuronal signals::

.. code-block:: MATLAB

    path = 'C:\\Users\\LBM_User\\Data\\Session1\\motion_corrected\\';
    segmentPlane(path, 0, 1, 10, 24);  # Segment data from planes 1 to 10 using 24 cores

4. Calibration and Alignment:

.. code-block:: MATLAB

   calculate_offset('C:\\Data\\calibration\\');  # Path to calibration data
   compare_planes_new('C:\\Data\\session1\\aligned\\');  # Path to data for final alignment


Additional Resources
--------------------

`ScanImage`_
`LBM`_
`MROI`_
`DataSheet`_
`MBO`_
`Slides`_

Copyright (C) 2024 Elizabeth. R. Miller Brain Observatory | The Rockefeller University. All rights reserved.

.. _CaImAn: https://github.com/flatironinstitute/CaImAn-MATLAB/
.. _ScanImage: https://www.mbfbioscience.com/products/scanimage/
.. _publication: https://www.nature.com/articles/s41592-021-01239-8/
.. _MROI: https://docs.scanimage.org/Premium%2BFeatures/Multiple%2BRegion%2Bof%2BInterest%2B%28MROI%29.html#multiple-region-of-interest-mroi-imaging/
.. _DataSheet: https://docs.google.com/spreadsheets/d/13Vfz0NTKGSZjDezEIJYxymiIZtKIE239BtaqeqnaK-0/edit#gid=1933707095/
.. _MBO: https://mbo.rockefeller.edu/
.. _Slides: https://docs.google.com/presentation/d/1A2aytY5kBhnfDHIzNcO6uzFuV0OJFq22b7uCKJG_m0g/edit#slide=id.g2bd33d5af40_1_0/
.. _NoRMCorre: https://github.com/flatironinstitute/NoRMCorre/
.. _constrained-foopsi: https://github.com/epnev/constrained-foopsi/
.. _startup: https://www.mathworks.com/help/matlab/matlab_env/matlab-startup-folder.html
.. _mroi_function: https://docs.scanimage.org/Appendix/ScanImage%2BUtility%2BFunctions.html#generate-multi-roi-data-from-tiff
.. _BigTiffSpec: _https://docs.scanimage.org/Appendix/ScanImage%2BBigTiff%2BSpecification.html#scanimage-bigtiff-specification
