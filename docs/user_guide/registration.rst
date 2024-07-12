Piecewise-Rigid Motion-Correction
================================================================

Function for this step: :func:`motionCorrectPlane`

For a quick demo on how to run motion correction, see the demo_registration.m script.

.. note::

   The terms motion-correction and registration are often used interchangably.


The goal of motion correction is to make sure that our neuron in the first frame is in the same spatial location as in frame N throughout the time-series.
Natural movement by the animal during experimental tasks can cause our images spatial potition varying slightly frame by frame. The extent of this movement can also vary widely depending
on the type of task the animal is performing.

For this reason, it is *very* important for the researcher to verify that any motion artifacts in the movie are removed before moving onto any subsequent computations.


Rigid vs Non-Rigid
*******************

The motion artifacts present in a movie also come in two flavors, `rigid` and `non-rigid`.
Purely rigid motion is simple, straightforeward movement that applies to each-and-every pixel equally.
The entire 2D image is shifted by a number of pixels in the x direction and y direction.

Non-rigid artifacts are much more complex as one region of the 2D image requires shifts that another region does not.

Motion correction relies on _`NoRMCorre` for piecewise-rigid motion correction resulting in shifts for each patch.

.. thumbnail:: ../_images/reg_patches.png
   :width: 1440

To run registration, call :func:`motionCorrectPlane()` like so:

.. code-block:: MATLAB

    % recall our directory structure, chaining the output path from the
    % tiff reconstruction step
    mcpath = 'C:\Users\RBO\Documents\data\bi_hemisphere\registration';

    % use 23 CPU cores to process z-planes 1-27
    motionCorrectPlane(extract_path, mcpath, 23, 1, 27);

See the demo pipeline at the root of this repository or the the API for more examples.

.. note::

   Each z-plane in between start_plane and end_plane will be processed.
   In the future we may want to provide a way to give an array of indices to correct e.g. if the user wants to throw out z-planes 16 and 18.


Registration Output
*********************

The output `h5` files are saved to the path entered in the :code:`save_path` :ref:`parameters`. There will be a single file for each z-plane in the volume.

This file has the following groups:

`/Y` or `/<param>`
: This group contains the 3D planar timeseries and the default `'/Y'` name can be changed via the `'ds'` :ref:`parameters` to :func:`convertScanImageTiffToVolume`.

`/Ym`
: The mean image of the motion-corrected movie. Each image is averaged over time to produce the mean pixel intensity. This is your

`/template`
: The mean image used to adjust each frame. Each frame in the 3D planar timeseries is displaced to align with this image, thus you want it to most accurately represent your mean-image.

`/shifts`
: A :code:`2xN` column vector containing X and Y shifts in px.

.. hint::

    To get the shifts and plot them in MATLAB:

    .. code-block:: MATLAB

        x_shifts = shifts(:,1) % represent pixel-shifts in *x*
        y_shifts = shifts(:,2) % represent pixel-shifts in *y*


Registration Metrics
***********************

NormCORRe provides some useful metrics to determine the effectiveness of registration. These will be placed in the same directory as your save_path, `figures/registration_metrics_plane_N`.

First, lets look at the mean-image for our raw, rigid and non-rigid images:

.. thumbnail:: ../_images/reg_metrics.png
   :download: true

We are looking for differences in the "blurryness" differences between the top row of 3 images.
In the above example, our raw image isn't easily distinguished from the corrected images.

.. thumbnail:: ../_images/reg_template.png
    :title: Template Image
    :download: true

This image is your "ground truth" per-se, it is the image you want to most accurately represent the movement in your video.

Compared with the below frame:

.. _storage:

.. thumbnail:: ../_images/reg_quickview_blue.png
   :group: ck
   :align: center

Next, we look at the bottom 3 images showing the correlation betwene pixels. Proper registration should **increase the correlation between neighboring pixels**.
We see in our example session that the last iteration of rigid registration leads to the highest correlation.

Registration Shifts
***********************

Next, we take a look at the transformations that occur between rigid and non-ridid shifts.

.. thumbnail:: ../_images/reg_shifts.png
   :download: true

To view the video, use the function :func:`play_movie()`.

Storage (WIP)
******************

.. thumbnail:: ../_images/gen_storage_rec.png
    :title: Recommended Data Storage Paradigm
    :download: true

We want to minimize the amount of storage space, so rather than saving 2 versions of a video that differ by simply shifting some pixels, we can instead save only the shift vectors
and reconstruct the video afterwards. :func:`translateFrames` will accomplish this:

.. code-block:: MATLAB

   >> help translateFrames

     translateFrames Translate image frames based on provided translation vectors.

      This function applies 2D translations to an image time series based on
      a series of translation vectors, one per frame. Each frame is translated
      independently, and the result is returned as a 3D stack of
      (Height x Width x num_frames) translated frames.

      Inputs:
        Y - A 3D time series of image frames (Height x Width x Number of Frames).
        t_shifts - An Nx2 matrix of translation vectors for each frame (N is the number of frames).

      Output:
        translatedFrames - A 3D array of translated image frames, same size and type as Y.
