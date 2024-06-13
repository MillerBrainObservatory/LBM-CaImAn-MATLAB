## Light Beads Microscopy (LBM) Pipeline: CaImAn-MATLAB

[![Documentation](https://img.shields.io/badge/Documentation-black?style=for-the-badge&logo=readthedocs&logoColor=white)](https://millerbrainobservatory.github.io/LBM-CaImAn-MATLAB/)

A pipeline for processing light beads microscopy (LBM) datasets using the [matlab implementation of CaImAn](https://github.com/flatironinstitute/CaImAn-MATLAB/).

For a python implementation, see [LBM-CaImAn-Python](https://github.com/MillerBrainObservatory/LBM-CaImAn-Python)

[![Issues](https://img.shields.io/github/issues/Naereen/StrapDown.js.svg)](https://GitHub.com/MillerBrainObservatory/LBM-CaImAn-MATLAB/issues/)
[![Release](https://img.shields.io/github/release/Naereen/StrapDown.js.svg)](https://GitHub.com/MillerBrainObservatory/LBM-CaImAn-MATLAB/releases/)
[![DOI](https://zenodo.org/badge/DOI/10.1007/978-3-319-76207-4_15.svg)](https://doi.org/10.1038/s41592-021-01239-8)

This pipeline is unique only in the routines to extract raw data from [ScanImage BigTiff files](https://docs.scanimage.org/Appendix/ScanImage%2BBigTiff%2BSpecification.html#scanimage-bigtiff-specification).

![Extraction Diagram]( docs/_static/_images/extraction/extraction_diagram.png)

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

## References

- [Nature Publication](https://www.nature.com/articles/s41592-021-01239-8/)
- [ScanImage-MROI Docs](https://docs.scanimage.org/Premium%2BFeatures/Multiple%2BRegion%2Bof%2BInterest%2B%28MROI%29.html#multiple-region-of-interest-mroi-imaging/)
- [MBO Homepage](https://mbo.rockefeller.edu/)
- [startup matlab files](https://www.mathworks.com/help/matlab/matlab_env/matlab-startup-folder.html)
- [![Publication](https://zenodo.org/badge/DOI/10.1007/978-3-319-76207-4_15.svg)](https://doi.org/10.1038/s41592-021-01239-8)
