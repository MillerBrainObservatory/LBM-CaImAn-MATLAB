---
myst:
  substitutions:
    key1: "I'm a **substitution**"
    key2: |
      ```{note}
      {{ key1 }}
      ```
    key3: |
      ```{image} https://github.com/MillerBrainObservatory/static-assets/blob/master/_images/MillerBrainObservatory_logo.svg
      :alt: mbo
      :width: 200px
      ```
    key4: example
---
# LBM-CaImAn-MATLAB Documentation

Currently, inputs to this pipeline are limited to ScanImage {code}`.tiff` files.

```{note} 
Only the first step of this pipeline which converts the multi-ROI {code}`.tiff` into a {code}`.h5` files separate volumetric time-series requires scanimage {code}`.tiff` files.
```

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

For up-to-date pipeline requirements and algorithms, see the github [repository readme](https://github.com/MillerBrainObservatory/LBM-CaImAn-MATLAB/tree/master?tab=readme-ov-file#light-beads-microscopy-lbm-pipeline-caiman-matlab).

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
links

```