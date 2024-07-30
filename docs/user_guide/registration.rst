Registration
================

Function for this step: :func:`motionCorrectPlane()`

.. note::

   The terms motion-correction and registration are often used interchangably.

Now that we have isolated each z-plane into its own timeseries, we can use `image registration <https://en.wikipedia.org/wiki/Image_registration>`_ to make sure that our neuron in the first frame is in the same spatial location as in frame N throughout the time-series.

Which varient of motion correction you use depends on the amount/degree of motion in your timeseries.

Rigid vs Non-Rigid
*******************

The motion artifacts present in a movie also come in two flavors, `rigid` and `non-rigid`.
Purely rigid motion is simple, straightforeward movement that applies to each-and-every pixel equally.
The entire 2D image is shifted by a number of pixels in the x direction and y direction.

Non-rigid artifacts are much more complex as one region of the 2D image requires shifts that another region does not.


.. thumbnail:: ../_images/reg_patches.png
   :width: 1440

To run registration, call :func:`motionCorrectPlane` like so:

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
: The mean image [X, Y] used to align each frame in the timeseries. This image is calculated to correlate the most with each frame in the image.

`/shifts`
: A :code:`2xN` column vector containing the number of pixels in X and Y that each frame was shifted.

.. hint::

    To get the shifts and plot them in MATLAB:

    .. code-block:: MATLAB

        x_shifts = shifts(:,1) % represent pixel-shifts in *x*
        y_shifts = shifts(:,2) % represent pixel-shifts in *y*

Evaluating Results
***********************

These will be placed in the same directory as your save_path, `figures/registration_metrics_plane_N`.

Pixels that are highly correlated over the timecourse of an experiment are stationary in the image. Proper registration should **increase the correlation between neighboring pixels**.

.. thumbnail:: ../_images/reg_correlation.png
   :title: Correlation Metrics

The above shows the correlation coefficient for raw, rigid and peicewise-rigid (non-rigid) timesieres. Closer to 1 indicates improved motion correction. 

Immediately obvious is the sharp decrease in correlation present in the blue raw data that was corrected in the rigid/non-ridid datapoints.

.. thumbnail:: ../_images/reg_correlation_zoom.png
   :title: Correlation Metrics

If not for the legend however, you'd never know that two separate instances of registration were performed.

.. thumbnail:: ../_images/reg_correlation_rnr.png
   :title: Correlation Metrics

There is very little improvement gained by performing non-rigid motion correction, which is a very computationally demanding task.

These metrics are provided for you alongside the mean images and X/Y shifts to help assess the contribution of movement in the X and Y directions.

.. thumbnail:: ../_images/reg_metrics.png
   :download: true

.. thumbnail:: ../_images/reg_shifts.png
   :download: true

.. tip::

   A quick way to see if registration was effective is to compare the two mean images,
   looking for differences in the "blurryness" between them. 

.. thumbnail:: ../_images/reg_raw_mean.png
   :title: Mean Raw

.. thumbnail:: ../_images/reg_rigid_mean.png
   :title: Mean Rigid Corrected

See :ref:`quick play movies` for an example of viewing two outputs side-by-side.
