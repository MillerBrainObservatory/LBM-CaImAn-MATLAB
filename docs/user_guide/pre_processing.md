
(pre_processing)=
# Pre-Processing

Function for this step: {func}`convertScanImageTiffToVolume()`

```{note}
Before beginning pre-processing, be sure to review {ref}`parameters` as they are the same for each step
in the pipeline and will not be covered in detail here.

..See {ref}`troubleshooting` for common issues you may encounter along the way.

```

(pp_overview)=
## Overview

Pre-processing LBM datasets consists of 2 main processing steps:

1. {ref}`De-interleave <ex_deinterleave>` z-planes and timesteps.
2. {ref}`Correct Scan-Phase <ex_scanphase>` alignment for each ROI.
3. {ref}`Re-tile <ex_retile>` vertically concatenated ROI's horizontally.

```{thumbnail} ../_images/ex_diagram_test2.svg

```

For a more in-depth look at the LBM datasets and accompanying metadata, see the {ref}`LBM metadata <primary_metadata>` section of the MBO user documentation.

```{warning}

All output .tiff files for a single imaging session should be placed in the same directory.
No other .tiff files should be in this directory. If this happens, an error will throw.

```

(extraction_inputs)=
## Inputs

This example follows a directory structure shown in {ref}`the first steps guide <directory_structure>`.

Inputs and outputs can be anywhere you wish so long as you have read/write permissions.

:::{code-block} MATLAB

parent_path = 'C:\Users\<username>\Documents\data\high_res\';

raw_path = [ parent_path 'raw\']; % where our raw .tiffs go
extract_path = [ parent_path 'extracted\']; % where results are saved

:::

:::{note}
Files are saved with the string {code}'_plane_' appended automatically, don't put the characters {code}`_plane_` together in your raw/extracted filenames!
:::

(scan_phase)=
### Scan Phase

In addition to the standard parameters, users should be aware of the implications that bidirectional scan offset correction has on your dataset.

The {code}`fix_scan_phase` parameter attempts to maximize the phase-correlation between each line (row) of each vertically concatenated strip.

This example shows that shifting every *other* row of pixels +2 (to the right) in our 2D reconstructed image will maximize the correlation between adjacent rows.

```{thumbnail} ../_images/ex_phase.png

```

:::{important}
Checking for a scan-phase offset correction is computationally cheap, so it is recommended to keep this to true.
:::

When every other row of our image if shifted by N pixels, adjacent rows that *are not* shifted now have a N number of 0's padded in between the rows that were shifted.

When this shift happens, the pipeline **automatically trims** those pixels because they longer contain valid calcium signal.

```{thumbnail} ../_images/ex_scanphase_gif.gif
---
width: 800
align: center
---
```

You'll see the decreased gap between ROI's for the scan-offset corrected image, showing the 2 pixels removed from each edge accounting for the padded 0's.

:::{caution}
If a scan-offset correction is applied, the ROI edge may contain these shifted pixels. This can be corrected with the trim_roi parameter discussed in the next section.
:::

(trim_roi)=
### Trim ROIs

There are times when the seam between re-tiled ROI's is still present.

This seam may not appear when frames are viewed individually, but are present in the {ref}`mean image <ex_meanimage>`.

The {code}`trim_roi` parameter takes an array of 4 values as input corresponding to the number of pixels to trim on the left, right, top and bottom of each ROI.

:::{code-block} MATLAB

trim_roi = [4,4,8,0]

:::

:::{tip}
If a {ref}`scan-phase correction <scan_phase>` is applied to this plane, there will be dead pixels on the left/right edges.
More than 3 pixel-shift offsets are rare, so we recommend a starting value of {code}`[2 2 x x]` which trims 2 pixels from the left and right edge.
:::

(trim_image)=
### Trim Image

In the same manner as {ref}`trimming ROIs <trim_roi>`, the {code}`trim_image` parameter will trim the edges of the {ref}`retiled-image <ex_retile>`.

(extraction_outputs)=
## Outputs

Output data are saved in {code}`.h5` format, with the following characteristics:
- one file per plane
- named {code}"<step>_plane_N.h5" where step = extraction, registration or segmentation
- data saved to a `h5 group`
- metadata saved as `h5 attributes`

-----

### H5 Groups

[HDF5](https://www.neonscience.org/resources/learning-hub/tutorials/about-hdf5) is the primary file format for this pipeline. HDF5 relied on groups and attributes to save data to disk.

- **Groups**: h5 files can be thought of like directories where a 3D time-series is self contained within its own folder (or group).
- **Attributes**: Attributes are special "tags" attached to a group. This is where we store metadata associated with each group and dataset. The result of calling `get_metadata(raw_path)` (see {ref}`scanimage metadata <primary_metadata>` for more information about the magic behind the scenes here).

For pre-processing, two "groups" are saved: registered timeseries and mean image:

{code}`/Y`
: The 3D final, re-tiled image.

{code}`/Ym`
: The 2D {ref}`mean image <ex_meanimage>`

:::::{admonition} Preview file contents
:class: dropdown

Use MATLAB functions [h5info](https://www.mathworks.com/help/matlab/ref/h5disp.html) and [h5disp](https://www.mathworks.com/help/matlab/ref/h5disp.html) to preview file contents.

h5disp takes the {code}`filename` as the only input parameter, and displays the contents of the file:

:::{code-block} MATLAB

>> h5disp(fullfile(data_path, "extracted/extracted_plane_1.h5"));

    HDF5 extracted_plane_1.h5 

    Group '/' 
        Attributes:
            'num_planes':  28.000000 
            'num_rois':  3.000000 
            'num_frames':  2320.000000 
            'frame_rate':  7.720873 
            'fov':  672.000000 668.000000 
            'pixel_resolution':  1.000000 
            %% Metadata values removed to save space ...
        Dataset 'Y' 
            Size:  668x222x2320
            MaxSize:  668x222xInf
            Datatype:   H5T_STD_I16LE (int16)
            ChunkSize:  668x222x16
            Filters:  none
            FillValue:  0
        Dataset 'Ym' 
            Size:  668x222
            MaxSize:  668x222
            Datatype:   H5T_IEEE_F64LE (double)
            ChunkSize:  []
            Filters:  none
            FillValue:  0.000000

:::

h5info takes the {code}`filename` and the {ref}`group <dataset_name>`, and displays the contents of the file:


:::{code-block} MATLAB
>> h5info(fullfile(data_path, "extracted/extracted_plane_1.h5"))

ans = 

  struct with fields:

      Filename: 'C:\Users\RBO\caiman_data\mk717\1um_72hz\extracted\extracted_plane_1.h5'
          Name: '/'
        Groups: []
      Datasets: [2×1 struct]
     Datatypes: []
         Links: []
    Attributes: [27×1 struct]
:::

::::

Notice our metadata is saved to the root group. This is to allow you to easily retrieve metadata for a step by calling {func}`read_h5_metadata`.

::::::

## Validate Outputs

In your {code}`save_path`, you will see a newly created {code}`figures` folder.

This contains an image for each {code}`[X,Y,T]` plane and checks for proper tiling.

In this folder is a close-up of the brightest image in every plane for a random frame.

Each image shoes the neuron before and after scan-correction.

This lets you compare planes, validate the correct scan-phase offset value (usually 1, 2 or 3 pixels).

We can see that our plane quality changes with depth:

```{thumbnail} ../_images/ex_offset.svg
---
width: 800
align: center
---

```

Additionally, you can use this images to get an idea of values you want to use for registration.

For example, consider the below image:

```{thumbnail} ../_images/ex_brightest_feature.png
---
scale: 50%
align: center
title: Brightest Feature
---

```

Taking the {term}`pixel resolution <pixel-resolution>` of $3μm$ from our metadata, we see this neuron is $~10μm$ wide.

We may then want to limit our {ref}`NoRMCorre Parameters <normcorre_params>` to only allow shifts of this size with {code}`max_shift=10/metadata.pixel_resolution`.

To get a sense of how much motion is present in your timeseries, see {ref}`tips and tricks: exploring datasets in MATLAB <explore_data_matlab>`

