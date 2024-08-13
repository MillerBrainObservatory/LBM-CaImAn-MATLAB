(registration)=
# Registration

```{note}
The terms motion-correction and registration are often used interchangably.
Similary, non-rigid and peicewise-rigid are often used interchangably.
Here, peicewise-rigid registration is the **method** to correct for non-rigid motion.
```

We use [image registration](https://en.wikipedia.org/wiki/Image_registration) to make sure that our neuron in the first frame is in the same spatial location as in frame N throughout the time-series.

(reg_overview)=
## Overview

Disturbances or movement in our timeseries cause variations in pixel locations between frames called **motion artifacts**.

The motion artifacts present in our sample come in two flavors, `rigid` and `non-rigid`. See {ref}`Types of Registration <tut_types_of_reg>` for more information.

```{thumbnail} ../_images/reg_patches.png
width: 1440
```

-----

First, a template image is created by averaging the first 200 frames. This image is used to align each and every frame in the timeseries. As frames are aligned, the template is updated to more closely match the pixel locations of the previous frames.

A well motion-corrected movie will show that each frame is highly correlated with the mean image.

## Inputs

In addition to the default function inputs described in section {ref}`parameters`, registration has a few important additional parameters.

{code}`start_plane`
: The plane to start registration.

{code}`end_plane`
: The plane to end registration.

{code}`options` 
: NormCorre Params Object

```{note}
All planes in between {code}`start_plane` and {code}`end_plane` will undergo registration [sequentially](https://www.merriam-webster.com/dictionary/sequential).
```

(normcorre_params)=
### NoRMCorre Parameters

The last parameter for this step is a NoRMCorre parameters object.
This is just a [MATLAB structured array](https://www.mathworks.com/help/matlab/ref/struct.html) that expects specific values. 

NoRMCorre provides the algorithm for registration and dictates the values in that struct.

There is an example parameters struct at the root of this project ([Github](https://github.com/MillerBrainObservatory/LBM-CaImAn-MATLAB/blob/master/demo_CNMF_params.m)).

```{warning}
Avoid the {code}`bidir` options as we correct for bi-directional scaling ourselves.
```

The most important NoRMCorre parameters are:

1. {code}`grid_size`
: Determines how many patches your image is split into. The smaller the patch, the **more precise the registration**, with a tradeoff being **increased compute times**.

2. {code}`max_shift`
: Determines the maximum number of pixels that your movie will be translated in X/Y.

3. {code}`fr`
: The frame rate of our movie, which is likely different than the 30Hz default.

4. {code}`correct_bidir`
: Attempts to correct for bi-directional scan offsets, a step that was performed {ref}`in pre-processing <scan_phase>`.

:::{admonition} A note on `max_shift`
:class: dropdown
 
For timeseries where the FOV is sparsely labeled or a frame is corrupted, the registration process of two neighboring patches can produce very different shifts, which can lead to corrupted registered frames.
We limit the largest allowed shift with the {code}`max_shift` parameter.

:::

If you see large single-frame spikes, try decreasing the {code}`max-shift` parameter (Default is $10μm$).

(ug_rigid_registration)=
(rigid_registration)=
## Rigid Registration

Rigid registration is accomplished by giving NoRMCorre **no variable for {code}`grid_size`**,
so it defaults to the size of your image and thus only processing a single patch encompassing the entire field-of-view.

```{note}
The pipeline uses rigid registration internally to first create a `template`. This template downsampled and used to obtain the most accurate mean image for alignment.
```

Ideally, you want registration parameters in units of *real-world values*.

For example, rather than specifying a max_shift in units of pixels, use the {term}`pixel-resolution` metadata to calculate a {code}`max_shift` as ~1/2 the size of the neuron:

```{code-block} MATLAB

plane_name = fullfile("path/to/raw_tif"); 
metadata = read_metadata(plane_name);

% assuming a typical cortical neuron size of $15μm$.
max_shift = 7.5/metadata.pixel_resolution
```

We can then use this value in our own parameters struct with the help of {func}`read_plane()`:

```{code-block}
% default dataset name
% depends on your input for the `ds` parameter in subsequent steps
dataset_name = '/Y'; 
plane_number = 1;

Y = read_plane(plane_name, 'ds', dataset_name, 'plane', plane_number);

% empty grid_size results in rigid-registration
options_rigid = NoRMCorreSetParms(...
   'd1',size(Y, 1),... 
   'd2',size(Y, 2),...
   'bin_width',200,...   % number of frames to initialze the template
   'max_shift', round(7.5/pixel_resolution), ... % still useful in non-rigid
);
```

(nonrigid_registration)=
(ug_nonrigid_registration)=
## Non-rigid Registration

To perform non-rigid registration, you must specify the size of the patches you want to split the FOV into.

Typical patch sizes for $512x512$ movies are $32x32$, which would lead to $512/32=16$ blocks that will be motion-corrected in parallel.

```{code-block} MATLAB

options_rigid = NoRMCorreSetParms(...
   'd1',size(Y, 1),... 
   'd2',size(Y, 2),...
   'bin_width',200,...   % number of frames to initialze the template
   'max_shift', round(20/pixel_resolution), ... % still useful in non-rigid
);

```

(reg_output)=
## Outputs

Just like {ref}`pre-processing outputs <extraction_inputs>`, registration outputs to {code}`.h5` format.

Registration outputs have the following groups:

{code}`/Y`
: Takes the name of the {ref}`ds <dataset_name>` parameter. This group contains the 3D timeseries.

{code}`/Ym`
: The mean image of the motion-corrected movie. Each image is averaged over time to produce the mean pixel intensity.

{code}`/shifts`
: A {code}`2xN` column vector containing the number of pixels in X and Y that each frame was shifted.

````{admonition} Example: Plot X/Y Shifts in MATLAB:
:class: dropdown

```{code-block} MATLAB

x_shifts = shifts(:,1) % represent pixel-shifts in *x*
y_shifts = shifts(:,2) % represent pixel-shifts in *y*
```

````

(validate_outputs)=
## Validate Outputs

Validation metric figures are placed in your `save_path` as `figures/registration_metrics_plane_N`.

```{thumbnail} ../_images/reg_figure_output.png
:title: Registration Output Figures
:align: right
:width: 50%

```

The pipeline saves 4 files / z-plane for you to quickly evaluate registration results in your {code}`save_path/figures/` as {code}`registration_metrics_plane_N`.

Internally, the pipeline first create a "template" using {ref}`rigid registration <tut_rigid>`.

Each frame of the timeseries is aligned to this frame.

The distance needed to shift these pixels to most closely align with the template is computed by locating the maximum of the cross-correlation between the each and every frame and the template.

```{thumbnail} ../_images/reg_correlation.png
:title: Correlation Metrics
```

Pixels that are highly correlated over the timecourse of an experiment are stationary in the image. Proper registration should **increase the correlation between neighboring pixels**.

```{admonition} Validation metrics rely on good signal!
:class: dropdown

The correlation metrics operate on each individual frame of the timeseries.
As such, they depend on the quality of the registration and noise level but also on the level of neural activity.

Be weary of correlation metrics showing good registration on data with lots of noise or little signal.
```

------

```{thumbnail} ../_images/reg_corr_with_mean.svg
```

The above image shows these correlations. Closer to 1 (the top of the graph) indicates high correlation and a more stationary image.

The high degree of overlap between rigid/non-rigid registration indicates our movie did not benefit from non-rigid motion correction.

This could be due to too large of a {code}`grid_size` or a general lack of non-uniform motion.

```{thumbnail} ../_images/reg_correlation_zoom.png
:title: Correlation Metrics
```

```{tip}
A quick way to see if registration was effective is to compare the two mean images,
looking for differences in the "blurryness" between them. 
```

```{thumbnail} ../_images/reg_blurry.svg
:title: Raw vs Registered Movie
```

