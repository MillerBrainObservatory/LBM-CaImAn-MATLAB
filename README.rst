Microscopy (LBM) Pipeline
=====================================

This README provides a comprehensive guide to the MATLAB implementation of the LBM Pipeline, which incorporates the CaImAn toolkit for advanced neuronal data segmentation and deconvolution.

Abstract
--------
Light Beads Microscopy (LBM) offers a novel approach for high-resolution, volumetric recording of neuron populations using two-photon microscopy.
This pipeline is optimized for analyzing volumetric data across various fields of view and pixel resolutions, significantly enhancing mesoscale imaging capabilities in scattering brain tissue.

Setup
-----
**Software Requirements**:

- **MATLAB Versions**: Successfully tested on MATLAB 2023a, 2023b, and 2024b.
  - **Required Toolboxes**:
    - Parallel Computing Toolbox
      - Statistics and Machine Learning Toolbox
        - Image Processing Toolbox (Enhances ``imtranslate`` performance)

        **Installation**:

        Clone the repository and set up the environment::

        git clone https://github.com/ru-rbo/caiman_matlab.git
        cd caiman_matlab

        **Usage Instructions**:

        The pipeline comprises several key processing stages outlined below. Ensure all raw data (.tif files) and processed files (.mat files) are appropriately placed as required for each stage.

        1. Pre-processing:

        Convert raw ScanImage .tif files into a 4D volume format for further processing::

        datapath = 'C:\Users\LBM_User\Data\Session1\';  # Directory containing raw .tif files
        savepath = 'C:\Users\LBM_User\Data\Session1\extracted_volumes\';  # Output directory for 4D volumes
        convertScanImageTiffToVolume(datapath, savepath, 0);

        2. Motion Correction:

        Perform both rigid and non-rigid motion correction using the Normcorre algorithm to stabilize the imaging data::

        filePath = 'C:\Data\';  # Path to the directory containing .mat files for processing
        fileNameRoot = 'session1_';  # Base filename to match for processing
        motionCorrectPlane(filePath, fileNameRoot, 24, 1, 10);  # Process from plane 1 to 10 using 24 cores

        3. Segmentation and Deconvolution:

        Segment the motion-corrected data and extract neuronal signals::

        path = 'C:\Users\LBM_User\Data\Session1\motion_corrected\';
        planarSegmentation(path, 0, 1, 10, 24);  # Segment data from planes 1 to 10 using 24 cores

        4. Calibration and Alignment:

        Ensure correct alignment of the imaging planes and calibrate the system using provided utilities::

        calculate_offset('C:\Data\calibration\');  # Path to calibration data
        compare_planes_new('C:\Data\session1\aligned\');  # Path to data for final alignment

        Notes on Data Management:
        -------------------------
        - Ensure that there is sufficient storage available, ideally at least 150% of the total raw data size, to accommodate intermediate data files and outputs.
          - Regularly back up processed data to prevent any loss due to unexpected system failures.

