.. _LBM Overview:

Light Beads Microscopy (LBM) Pipeline
=====================================

Full analysis pipeline for LBM recordings. For a theoretical background of the LBM technology, `see the reference paper`_LBM

Algorithms
----------

- `CaImAn-MATLAB`_ segmentation and neuronal source extraction.
- `NoRMCorre`_ for piecewise rigid motion correction.
- `constrained-foopsi`_ constrained deconvolution spike inference.


Pipeline Setup
--------------
**Software Requirements:**

- MATLAB (Tested on 2023a, 2023b, 2024b)
- Required Toolboxes:
  - Parallel Computing Toolbox
  - Statistics and Machine Learning Toolbox
  - Image Processing Toolbox


Quickstart
----------

.. code-block:: bash

    git clone https://github.com/ru-rbo/caiman_matlab.git
    cd caiman_matlab

Usage
-----

1. Pre-processing:

   Convert raw ScanImage .tif files into a 4D format for further processing::

.. code-block:: MATLAB

       datapath = 'C:\\Users\\LBM_User\\Data\\Session1\\';  # Directory containing raw .tif files
       savepath = 'C:\\Users\\LBM_User\\Data\\Session1\\extracted_volumes\\';  # Output directory for 4D volumes
       convertScanImageTiffToVolume(datapath, savepath, 0);

2. Motion Correction:

   Perform both rigid and non-rigid motion correction using the Normcorre algorithm to stabilize the imaging data::

.. code-block:: MATLAB

       filePath = 'C:\\Data\\';  # Path to the directory containing .mat files for processing
       fileNameRoot = 'session1_';  # Base filename to match for processing
       motionCorrectPlane(filePath, fileNameRoot, 24, 1, 10);  # Process from plane 1 to 10 using 24 cores

3. Segmentation and Deconvolution:

   Segment the motion-corrected data and extract neuronal signals::

.. code-block:: MATLAB

       path = 'C:\\Users\\LBM_User\\Data\\Session1\\motion_corrected\\';
       planarSegmentation(path, 0, 1, 10, 24);  # Segment data from planes 1 to 10 using 24 cores

4. Calibration and Alignment:

   Ensure correct alignment of the imaging planes and calibrate the system using provided utilities::

.. code-block:: MATLAB
       calculate_offset('C:\\Data\\calibration\\');  # Path to calibration data
       compare_planes_new('C:\\Data\\session1\\aligned\\');  # Path to data for final alignment


`ScanImage`_
`LBM`_
`MROI`_
`DataSheet`_
`MBO`_
`Slides`_

.. _CaImAn: https://github.com/flatironinstitute/CaImAn-MATLAB/
.. _ScanImage: https://www.mbfbioscience.com/products/scanimage/
.. _LBM: https://www.nature.com/articles/s41592-021-01239-8/
.. _MROI: https://docs.scanimage.org/Premium%2BFeatures/Multiple%2BRegion%2Bof%2BInterest%2B%28MROI%29.html#multiple-region-of-interest-mroi-imaging/
.. _DataSheet: https://docs.google.com/spreadsheets/d/13Vfz0NTKGSZjDezEIJYxymiIZtKIE239BtaqeqnaK-0/edit#gid=1933707095/
.. _MBO: https://mbo.rockefeller.edu/
.. _Slides: https://docs.google.com/presentation/d/1A2aytY5kBhnfDHIzNcO6uzFuV0OJFq22b7uCKJG_m0g/edit#slide=id.g2bd33d5af40_1_0/
.. _NoRMCorre: https://github.com/flatironinstitute/NoRMCorre
.. _Deconvolution: https://github.com/epnev/constrained-foopsi/

References
----------

Manuel Guizar (2024).
    Efficient subpixel image registration by cross-correlation (https://www.mathworks.com/matlabcentral/fileexchange/18401-efficient-subpixel-image-registration-by-cross-correlation),
    MATLAB Central File Exchange. Retrieved April 23, 2024.

@article{pnevmatikakis2017normcorre,
    title={NoRMCorre: An online algorithm for piecewise rigid motion correction of calcium imaging data},
    author={Pnevmatikakis, Eftychios A and Giovannucci, Andrea},
    journal={Journal of neuroscience methods},
    volume={291},
    pages={83--94},
    year={2017},
    publisher={Elsevier}
}

