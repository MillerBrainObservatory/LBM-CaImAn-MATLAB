(offset_correction)=
# Axial-Offset Correction

Use pollen calibration data to spatially align each z-plane.

Core function(s): {func}`calculateZOffset()`

:::{note}
Before the session being processed, you should have collected a cailbration file (i.e. {code}`pollen_calibration_00001.tif`}).
:::

## Inputs

:::{topic} **Before proceeding**

You will need access to the following calibration files:

{code}`pollen_calibration_Z_vs_N.mat`
{code}`pollen_calibration_x_y_offsets.fig`

:::

:::{important}
These files hold data used to align each z-plane depth around the same [Y, X] coordinates.
Place these files in the same directory as your `segmentation_plane_N` files.
:::

First, the [Y, X] offsets (in microns) are used for an initial, dirty axial alignment:

:::{thumbnail} ../_images/pollen/pollen_shifts.png
---
width: 300
---
:::

This alignment should improve the spatial consistency between z-planes, but there is a further refinement step which prompts a graphical interface for $z-plane(n)$ and $z-plane(n+1)$.

You will be prompted to select the same **feature** / **region-of-interest** / **neuron**.

After selecting 3 neurons for each plane, you are done with this LBM pipeline.

Depending on your axial field-of-view, there is likely neuronal contamination between z-planes.
We can use this to select $feature(z)$ in the left box and $feature(z+1) on the right box.

:::{thumbnail} ../_images/corr_left.jpg
---
width: 600
---
:::

The image you should be clicking on will be highighted red.
Once the selection is made, the right image will now zoom into the corresponding region in the next z-plane.
Now, you can select the same feature in this plane:

:::{thumbnail} ../_images/corr_right.jpg
---
width: 600
---
:::

This makes a few assumptions about the axial distance between z-planes.
First, each z-plane should be close enough in distance (for example, ~16um) that neuronal features will be similar and can be used for alignment.

## Outputs

- {code}`.fig` files showing neuron distributions in z and radial directions.
- A {code}`.mat` file: {code}`caiman_collated_output_plane_N` with collated and processed imaging data.

This output file mirrors the registration output but with all z-planes collated into a single dataset.

:::{hint}
In the filename, you'll see _min_snr_ followed by a number.
This is also stored in the metadata and is the primary variable dictating the threshold of detection.
:::
In the resulting filename you will see the collated {code}`minSNR` value. This new file
holds a concatenated, centered and thresholded master copy of all neurons, footprints and traces.
