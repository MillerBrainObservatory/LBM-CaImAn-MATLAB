
################################
LBM-CaImAn-MATLAB Documentation
################################

|Repository| |Release| |Issues|

.. image:: https://upload.wikimedia.org/wikipedia/commons/thumb/2/21/Matlab_Logo.png/858px-Matlab_Logo.png

A pipeline for processing light beads microscopy (LBM) datasets.

Currently, inputs to this pipeline are limited to `ScanImage`_ `tiff` files. However, only the
first step of this pipeline which converts the multi-ROI .tiff into a 4D volumetric time-series
requires scanimage `.tiff` files.

For background, theory and design of LBM technology, see the reference `publication`_.

|Publication|

=============
Quickstart
=============

The easiest way to get started with the pipeline is to follow the demo_LBM_pipeline script, which contains sections
for the pipeline setup, each step in the pipeline, and intermediate analysis along the way.

Pipeline Steps
*****************

There are 4 core steps in this pipeline:

1. `convertScanImageTiffToVolume()`
2. `motionCorrectPlane()`
3. `segmentPlane()`
4. `collatePlane()`

.. thumbnail:: _static/_images/extraction/extraction_diagram.png
   :width: 800

Requirements
=============

- MATLAB (Tested on 2023a, 2023b, 2024b)
- Toolboxes:
    - Parallel Computing Toolbox
    - Statistics and Machine Learning Toolbox
    - Image Processing Toolbox
    - Signal Processing Toolbox

Algorithms
=============

The following algorithms perform the main computations and are included by default in the pipeline:

- `CNMF`_ segmentation and neuronal source extraction.
- `NoRMCorre`_ piecewise rigid motion correction.
- `constrained-foopsi`_ constrained deconvolution spike inference.

.. _CNMF: https://github.com/simonsfoundation/NoRMCorre
.. _CaImAn: https://github.com/flatironinstitute/CaImAn-MATLAB/
.. _ScanImage: https://www.mbfbioscience.com/products/scanimage/
.. _publication: https://www.nature.com/articles/s41592-021-01239-8/
.. _MROI: https://docs.scanimage.org/Premium%2BFeatures/Multiple%2BRegion%2Bof%2BInterest%2B%28MROI%29.html#multiple-region-of-interest-mroi-imaging/
.. _DataSheet: https://docs.google.com/spreadsheets/d/13Vfz0NTKGSZjDezEIJYxymiIZtKIE239BtaqeqnaK-0/edit#gid=1933707095/
.. _MBO: https://mbo.rockefeller.edu/
.. _Slides: https://docs.google.com/presentation/d/1A2aytY5kBhnfDHIzNcO6uzFuV0OJFq22b7uCKJG_m0g/edit#slide=id.g2bd33d5af40_1_0/
.. _NoRMCorre: https://github.com/flatironinstitute/NoRMCorre/
.. _constrained-foopsi: https://github.com/epnev/constrained-foopsi/
.. _startup.m: https://www.mathworks.com/help/matlab/matlab_env/matlab-startup-folder.html
.. _startup: https://www.mathworks.com/help/matlab/matlab_env/matlab-startup-folder.html
.. _BigTiffSpec: _https://docs.scanimage.org/Appendix/ScanImage%2BBigTiff%2BSpecification.html#scanimage-bigtiff-specification

.. |Publication| image:: https://zenodo.org/badge/DOI/10.1007/978-3-319-76207-4_15.svg
    :alt: Publication Link
    :target: https://doi.org/10.1038/s41592-021-01239-8

.. |issues| image:: https://img.shields.io/github/issues/Naereen/StrapDown.js.svg
    :alt: Issues badge
    :target: https://GitHub.com/MillerBrainObservatory/LBM-CaImAn-MATLAB/issues/

.. |release| image:: https://img.shields.io/github/release/Naereen/StrapDown.js.svg
    :alt: Release badge
    :target: https://GitHub.com/MillerBrainObservatory/LBM-CaImAn-MATLAB/releases/

.. |Docs| image:: https://img.shields.io/badge/Documentation-black?style=for-the-badge&logo=readthedocs&logoColor=white&link=https%3A%2F%2Fmillerbrainobservatory.github.io%2FLBM-CaImAn-MATLAB%2F
    :alt: Docs badge
    :target: https://millerbrainobservatory.github.io/LBM-CaImAn-MATLAB/index.html#

.. |DOI| image:: https://zenodo.org/badge/DOI/10.1007/978-3-319-76207-4_15.svg
    :alt: Doi badge
    :target: https://doi.org/10.1038/s41592-021-01239-8

.. |Repository| image:: https://img.shields.io/badge/Repository-black?style=flat-square&logo=github&logoColor=white&link=https%3A%2F%2Fmillerbrainobservatory.github.io%2FLBM-CaImAn-MATLAB%2F
    :alt: Repo Link
    :target: https://github.com/MillerBrainObservatory/LBM-CaImAn-MATLAB

Contents
=================

.. toctree::
    :maxdepth: 2

    get_started/index

.. toctree::
    :maxdepth: 2
    :caption: User Guide

    user_guide/index

.. toctree::
    :maxdepth: 2
    :caption: API:

    api/index

Indices and tables
=====================================

* :ref:`genindex`
* :ref:`modindex`
* :ref:`search`

.. _CNMF: https://github.com/simonsfoundation/NoRMCorre
.. _CaImAn: https://github.com/flatironinstitute/CaImAn-MATLAB/
.. _ScanImage: https://www.mbfbioscience.com/products/scanimage/
.. _publication: https://www.nature.com/articles/s41592-021-01239-8/
.. _MROI: https://docs.scanimage.org/Premium%2BFeatures/Multiple%2BRegion%2Bof%2BInterest%2B%28MROI%29.html#multiple-region-of-interest-mroi-imaging/
.. _DataSheet: https://docs.google.com/spreadsheets/d/13Vfz0NTKGSZjDezEIJYxymiIZtKIE239BtaqeqnaK-0/edit#gid=1933707095/
.. _MBO: https://mbo.rockefeller.edu/
.. _Slides: https://docs.google.com/presentation/d/1A2aytY5kBhnfDHIzNcO6uzFuV0OJFq22b7uCKJG_m0g/edit#slide=id.g2bd33d5af40_1_0/
.. _NoRMCorre: https://github.com/flatironinstitute/NoRMCorre/
.. _constrained-foopsi: https://github.com/epnev/constrained-foopsi/
.. _startup.m: https://www.mathworks.com/help/matlab/matlab_env/matlab-startup-folder.html
.. _startup: https://www.mathworks.com/help/matlab/matlab_env/matlab-startup-folder.html
.. _BigTiffSpec: _https://docs.scanimage.org/Appendix/ScanImage%2BBigTiff%2BSpecification.html#scanimage-bigtiff-specification
