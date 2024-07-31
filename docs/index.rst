
################################
LBM-CaImAn-MATLAB Documentation
################################

|Repository| |Release| |Issues|

Currently, inputs to this pipeline are limited to `ScanImage`_ `tiff` files. However, only the
first step of this pipeline which converts the multi-ROI .tiff into a 4D volumetric time-series
requires scanimage `.tiff` files.

Pipeline Steps
*****************

There are 4 core steps in this pipeline:

1. :func:`convertScanImageTiffToVolume()`
2. :func:`motionCorrectPlane()`
3. :func:`segmentPlane()`
4. :func:`calculateZOffset()`

.. note::

    The core functions used to initiate this pipeline are `camelCase` (lowerUpperCase).
    Every **non-core** function you may use, such as :func:`play_movie`, is `snake_case`.

.. thumbnail:: _images/ex_diagram.png
   :width: 800
   :align: center

----------------

For up-to-date pipeline requirements and algorithms, see the github `repository readme <https://github.com/MillerBrainObservatory/LBM-CaImAn-MATLAB>`_


Documentation Contents
========================

.. toctree::
    :maxdepth: 3

    first_steps/index

.. toctree::
    :maxdepth: 3

    user_guide/index

.. toctree::
    :maxdepth: 2

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
