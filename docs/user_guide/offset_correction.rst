.. _offset_correction:

Axial-Offset Correction
=======================

Core function(s): :func:`calculateZOffset()`

Before the session being processed, you should have aquired a cailbration file named something like `pollen_calibration_00001.tif`.

Background
---------------

Light beads traveling to our sample need to be temporally distinct relative to our sensor
so that the aquisition system knows the origin and subsequent depth of each bead.

The current LBM design incoorperates 2 cavities, hereby named `Cavity A` and `Cavity B`.
These two cavities are non-overlapping areas where light beads travel. If we plot
a sample pollen grain through each z-depth, we can see these cavities manifest:

.. thumbnail:: ../_images/pollen/pollen_depth.svg
   :width: 600

We see a bi-modal distribution of Signal (Y) vs z-depth.

This pollen grain is sampled just like a brain would be sampled. We can
preview the time-series resulting from this pollen to get a preliminary
look at our recording quality:

.. thumbnail:: ../_images/pollen/pollen_frame.png
   :width: 600

Axial Correction Inputs
---------------------------

Before proceeding:

- You will need to be in a GUI environment for this step. Calculate offset will show you two images, click the feature that matches in both images.
- You will need access to the following calibration files:

:code:`pollen_calibration_Z_vs_N.mat`
:code:`pollen_calibration_x_y_offsets.fig`

.. important::

    These files hold data used to align each z-plane depth around the same [Y, X] coordinates.
    Place these files in the same directory as your `segmentation_plane_N` files.

First, the [Y, X] offsets (in microns) are used for an initial, dirty axial alignment:

.. thumbnail:: ../_images/pollen/pollen_shifts.png
   :width: 600

This alignment should improve the spatial consistency between z-planes, but there is a
further refinement step which prompts a graphical interface for z-plane(n) and z-plane(n+1).

The user will be prompted to select the same **feature** / **region-of-interest** / **neuron**.
After selecting 3 neurons for each plane, you are done with the LBM pipeline.

Depending on your axial field-of-view, there is likely neuronal contamination between z-planes.
We can use this to select a feature, and the same feature in n+1.

.. thumbnail:: ../_images/corr_left.jpg
   :width: 600

The image you should be clicking on will be highighted red.
Once the selection is made, the right image will now zoom into the corresponding region in the next z-plane.
Now, you can select the same feature in this plane:

.. thumbnail:: ../_images/corr_right.jpg
   :width: 600

This makes a few assumptions about the axial distance between z-planes.
First, each z-plane should be close enough in distance (for example, ~16um) that neuronal features will be similar and can be used for alignment.

Axial Correction Outputs
----------------------------

- .fig files showing neuron distributions in z and radial directions.
- A :code:`.mat` file: `caiman_collated_output_plane_N` with collated and processed imaging data.

This final ``caiman_collated_output_plane_N.m`` file is the same as was discussed in :ref:`segmentation outputs`.
The difference being now, all of our z-planes are collated into a single file.

.. hint::

    In the filename, you'll see _min_snr_ followed by a number. This is also stored in the metadata and is the primary variable dictating the threshold of detection.

In the resulting filename you will see the collated :code:`minSNR` value. This new file
holds a concatenated, centered and thresholded master copy of all neurons, footprints and traces.
