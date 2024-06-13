# Light Beads Microscopy (LBM) Pipeline

[![Documentation](https://img.shields.io/badge/Documentation-1f425f.svg)](https://millerbrainobservatory.github.io/LBM-CaImAn-MATLAB/)
![Extraction Diagram]( _static/_images/extractin/extraction_diagram.png)
[![Publication](https://zenodo.org/badge/DOI/10.1007/978-3-319-76207-4_15.svg)](https://doi.org/10.1038/s41592-021-01239-8)

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

- [CaImAn](https://github.com/flatironinstitute/CaImAn-MATLAB/)
- [ScanImage](https://www.mbfbioscience.com/products/scanimage/)
- [Publication](https://www.nature.com/articles/s41592-021-01239-8/)
- [MROI](https://docs.scanimage.org/Premium%2BFeatures/Multiple%2BRegion%2Bof%2BInterest%2B%28MROI%29.html#multiple-region-of-interest-mroi-imaging/)
- [DataSheet](https://docs.google.com/spreadsheets/d/13Vfz0NTKGSZjDezEIJYxymiIZtKIE239BtaqeqnaK-0/edit#gid=1933707095/)
- [MBO](https://mbo.rockefeller.edu/)
- [Slides](https://docs.google.com/presentation/d/1A2aytY5kBhnfDHIzNcO6uzFuV0OJFq22b7uCKJG_m0g/edit#slide=id.g2bd33d5af40_1_0/)
- [startup.m](https://www.mathworks.com/help/matlab/matlab_env/matlab-startup-folder.html)
- [BigTiffSpec](https://docs.scanimage.org/Appendix/ScanImage%2BBigTiff%2BSpecification.html#scanimage-bigtiff-specification)


[![Issues](https://img.shields.io/github/issues/Naereen/StrapDown.js.svg)](https://GitHub.com/MillerBrainObservatory/LBM-CaImAn-MATLAB/issues/)

[![Release](https://img.shields.io/github/release/Naereen/StrapDown.js.svg)](https://GitHub.com/MillerBrainObservatory/LBM-CaImAn-MATLAB/releases/)

[![DOI](https://zenodo.org/badge/DOI/10.1007/978-3-319-76207-4_15.svg)](https://doi.org/10.1038/s41592-021-01239-8)
