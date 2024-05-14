.. _overview:

Light Beads Microscopy Pipeline
===============================

A pipeline for processing light beads microscopy (LBM) datasets.

LBM is a *scalable*, *spatiotemporally optimal* aquisition approach limited only by flourescence lifetime.
For background, theory and design of LBM technology, see the reference `publication`_.

Currently, this pipeline is optimized to extract data aquired through the `ScanImage`_ software package.

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
  - Using a version pre-2017a may yield innaccurate registration due to `single-precision accuracy <https://github.com/flatironinstitute/NoRMCorre/wiki/Known-Issues>`_.
- Toolboxes:
    - Parallel Computing Toolbox
    - Statistics and Machine Learning Toolbox
    - Image Processing Toolbox

Resources
---------

- Additional information on how to collaborate with the Miller Brain Observatory at the MBO website_.
- For details about algorithmic parameters not covered in this guide, see the  `CaImAn`_ documentation
- For details about LBM data aquisition see `ScanImage`_ documentation

Core Functionality
------------------

There are 4 steps corresponding to 4 core functions (more details in `Usage`_):

1. Convert ScanImage .Tiff to 4D [x, y, z, t] array.
    - convertScanImageTiffToVolume
2. Piecewise rigid motion correction.
    - motionCorrectPlane
3. Plane-by-plane 2D neuronal segmentation and deconvolution.
    - segmentPlane
4. Z Offset Correction.
    - collatePlane


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
