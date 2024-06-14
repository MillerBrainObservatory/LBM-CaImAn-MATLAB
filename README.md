## Light Beads Microscopy (LBM) Pipeline: CaImAn-MATLAB

[![Documentation](https://img.shields.io/badge/Documentation-black?style=for-the-badge&logo=readthedocs&logoColor=white)](https://millerbrainobservatory.github.io/LBM-CaImAn-MATLAB/)

A pipeline for processing light beads microscopy (LBM) datasets using the [flatironinstitute/CaImAn-MATLAB](https://github.com/flatironinstitute/CaImAn-MATLAB/) pipeline.

For a python implementation, see [here](https://github.com/MillerBrainObservatory/LBM-CaImAn-Python)

[![Issues](https://img.shields.io/github/issues/Naereen/StrapDown.js.svg)](https://GitHub.com/MillerBrainObservatory/LBM-CaImAn-MATLAB/issues/)
[![DOI](https://zenodo.org/badge/DOI/10.1007/978-3-319-76207-4_15.svg)](https://doi.org/10.1038/s41592-021-01239-8)

## Overview

This pipeline is unique only in the routines to extract raw data from [ScanImage BigTiff files](https://docs.scanimage.org/Appendix/ScanImage%2BBigTiff%2BSpecification.html#scanimage-bigtiff-specification), as is outlined below:

![Extraction Diagram]( docs/_static/_images/extraction/extraction_diagram.png)

Once data is extracted to an intermediate filetype `h5`, `.tiff`, `.memmap`, registration, segmentation and deconvolution can all be performed as described in the corresponding pipelines documentation.

The the [documentation] for usage, tutorials, tips and tricks. Follow the root `demo_LBM_pipeline.m` file for an example pipeline, or the root `/notebooks` folder for more in-depth exploration of individual pipeline steps.

## Requirements

- MATLAB (Tested on 2023a, 2023b, 2024b)
- Toolboxes:
  - Parallel Computing Toolbox
  - Statistics and Machine Learning Toolbox
  - Image Processing Toolbox
  - Signal Processing Toolbox

## Algorithms

The following algorithms perform the main computations and are included by default in the pipeline:

- [CNMF](https://github.com/simonsfoundation/NoRMCorre) segmentation and neuronal source extraction.
- [NoRMCorre](https://github.com/flatironinstitute/NoRMCorre) piecewise rigid motion correction.
- [constrained-foopsi](https://github.com/epnev/constrained-foopsi) constrained deconvolution spike inference.

