.. _overview:

Light Beads Microscopy Pipeline
===============================

A pipeline for processing light beads microscopy (LBM) datasets.

LBM is a *scalable*, *spatiotemporally optimal* aquisition approach limited only by flourescence lifetime.
For background, theory and design of LBM technology, see the reference `publication`_.

Currently, inputs to this pipeline are limited to `ScanImage`_ tiff files.

.. _requirements:

Requirements
------------

- MATLAB (Tested on 2023a, 2023b, 2024b)
- Toolboxes:
    - Parallel Computing Toolbox
    - Statistics and Machine Learning Toolbox
    - Image Processing Toolbox

Algorithms
----------

- `CNMF`_ segmentation and neuronal source extraction.
- `NoRMCorre`_ piecewise rigid motion correction.
- `constrained-foopsi`_ constrained deconvolution spike inference.


Steps
-----

There are 4 steps corresponding to 4 core functions (more details in `Usage`_:

1. Convert ScanImage .Tiff to 4D [x, y, z, t] array.
    - convertScanImageTiffToVolume

2. Piecewise rigid motion correction.
    - motionCorrectPlane

3. Plane-by-plane 2D neuronal segmentation and deconvolution.
    - segmentPlane

4. Z Offset Correction.
    - segmentPlane


Data Extraction
---------------

The output of an ScanImage MROI acquisition is a `tiff` (or series of tiffs, see caveat_)
with metadata attached to the `artist` tag.
In the resulting `tiff`, each ROI’s image is stacked one on top of the other vertically.

.. _algorithms:



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



Additional Resources
--------------------

`ScanImage`_
`LBM`_
`MROI`_
`DataSheet`_
`MBO`_
`Slides`_

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

Copyright (C) 2024 Elizabeth. R. Miller Brain Observatory | The Rockefeller University. All rights reserved.
