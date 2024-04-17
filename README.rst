Light Beads Microscopy (LBM) Pipeline
=====================================

This is the MATLAB implementation of the LBM Pipeline, utilizing the CaImAn toolkit for neuronal data segmentation and deconvolution.

Abstract
--------
Two-photon microscopy allows high-resolution imaging deep within scattering brain tissue but struggles with the speed and sampling necessary for mesoscale volumetric recording at cellular resolution.
Light Beads Microscopy (LBM) is introduced as a scalable method achieving near-simultaneous volumetric recording across significant neuron populations.
This document outlines the setup and usage of the LBM data processing pipeline designed for high performance analysis across different fields of view and pixel resolutions.

Pipeline Setup
--------------
**Software Requirements:**

- MATLAB (Tested on 2023a, 2023b, 2024b)
- Required Toolboxes:
  - Parallel Computing Toolbox
  - Statistics and Machine Learning Toolbox

**Installation and Usage**

 ``` bash
 git clone https://github.com/ru-rbo/caiman_matlab
 ```

 Navigate to the installation folder in matlab, and perform each step outlined below.

**Steps:**

1. **Pre-processing:**
   - Setup raw data path and filename in ``run_pre_processing.m``.

2. **Motion Correction:**
   - Setup raw data path and filename in ``run_pre_processing.m``.
   - Adjust paths for data storage and ensure at least 150% of the total raw file size is available for processing.

3. **Segmentation and Deconvolution:**
   - Run ``run_segment_fo.m`` script after setting the correct path to the motion-corrected files.
   - Specify the number of workers for MATLAB to use during processing.

4. **Calibration and Alignment:**
   - Use ``calculate_offset.m`` to adjust for any plane-to-plane offsets using calibration data.
   - Run ``compare_planes_new.m`` to finalize the alignment and setup for analysis, ensuring paths and parameters are correctly set.

