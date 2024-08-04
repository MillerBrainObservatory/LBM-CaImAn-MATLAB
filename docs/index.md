# LBM-CaImAn-MATLAB Documentation

Currently, inputs to this pipeline are limited to {ref}`ScanImage` {code}`.tiff` files.
However, only the first step of this pipeline which converts the multi-ROI .tiff into a 4D volumetric time-series requires scanimage `.tiff` files.

## Pipeline Overview

There are 4 core steps in this pipeline:

1. {func}`convertScanImageTiffToVolume()`
2. {func}`motionCorrectPlane()`
3. {func}`segmentPlane()`
4. {func}`calculateZOffset()`

```{note}
The core functions used to initiate this pipeline are `camelCase` (lowerUpperCase).
Every **non-core (helper/utility)** function you may use, such as {func}`play_movie()`, is `snake_case`.

```

```{thumbnail} _images/ex_diagram.png
---
width: 800
align: center
---

```

----------------

For up-to-date pipeline requirements and algorithms, see the github [repository readme](https://github.com/MillerBrainObservatory/LBM-CaImAn-MATLAB)

## Documentation Contents

```{toctree}
---
maxdepth: 3
---
first_steps/index
user_guide/index
tutorials/index
api/index
image_gallery
glossary

```
