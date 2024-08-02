.. _registration:

Registration
#####################

.. note::

   The terms motion-correction and registration are often used interchangably.
   Similary, non-rigid and peicewise-rigid are often used interchangably.
   Here, peicewise-rigid registration is the **method** to correct for non-rigid motion.

We use `Image registration <https://en.wikipedia.org/wiki/Image_registration>`_ to make sure that our neuron in the first frame is in the same spatial location as in frame N throughout the time-series.

Disturbances, or movement, causing variations in pixel locations between frames are called motion artifacts.

The motion artifacts present in our sample come in two flavors, `rigid` and `non-rigid`.

.. _r_vs_nr:

Rigid vs Non-Rigid
====================

Rigid motion
: The object is moved with its shape and size preserved.

- simple
- applies to each pixel equally
- The entire 2D image is shifted by a number of pixels in the x direction and y direction.

Non-Rigid motion
: The object is moved and transforms shape or size.

- complex
- region A requires more shift than region B

Correcting for non-rigid motion requires dividing the field-of-view into patches, and performing *rigid* motion correction on each patch.

.. thumbnail:: ../_images/reg_patches.png
   :width: 1440

With movies that exibit little sub-cellular movement over the course of a timeseries, non-rigid registration is often overkill as rigid-registration will do a good enough job.

Rigid Registration
---------------------------

Rigid registration is accomplished by giving NoRMCorre no variable for :code:`grid-size`, so it defaults to the size of your image and thus only processing a single patch encompassing the entire field-of-view.

Ideally, you want registration parameters in units of real-world values.

For example, rather than specifying a max-shift of 5 pixels, use the :ref:`pixel_resolution` metadata to calculate a :code:`max-shift` of ~1/2 size of the neuron:

.. code-block:: MATLAB

   % assuming a typical cortical neuron size of 15 micron
   max_shift = 7.5/metadata.pixel_resolution

Here, we use the :ref:`pixel resolution <pixel_resolution>` (how many microns each pixel represents) to express a **max shift of 20 micron**:

.. code-block:: MATLAB

   plane_name = fullfile("path/to/raw_tif"); 
   metadata = read_metadata(plane_name);

   max_shift = 20/metadata.pixel_resolution

We can then use this value in our own parameters struct with the help of :func:`read_plane()`:

.. code-block:: MATLAB

   % default dataset name
   % depends on your input for the `ds` parameter in subsequent steps
   dataset_name = '/Y'; 
   plane_number = 1;

   Y = read_plane(plane_name, 'ds', dataset_name, 'plane', plane_number);

   % empty grid-size results in rigid-registration
   options_rigid = NoRMCorreSetParms(...
      'd1',size(Y, 1),... 
      'd2',size(Y, 2),...
      'bin_width',200,...   % number of frames to initialze the template
      'max_shift', round(20/pixel_resolution), ... % still useful in non-rigid
   );

Non-rigid Registration
---------------------------

.. code-block:: MATLAB

   options_rigid = NoRMCorreSetParms(...
      'd1',size(Y, 1),... 
      'd2',size(Y, 2),...
      'bin_width',200,...   % number of frames to initialze the template
      'max_shift', round(20/pixel_resolution), ... % still useful in non-rigid
   );

.. _reg_inputs:

Inputs
====================

In addition to the default function inputs described in section :ref:`parameters`, registration has a few important additional parameters.

`start_plane` 
: The plane to start registration.

`end_plane` 
: The plane to end registration.

`options` 
: NormCorre Params Object

.. note::

   All planes in between :code:`start_plane` and :code:`end_plane` will undergo registration `sequentially <https://www.merriam-webster.com/dictionary/sequential>`_.

NoRMCorre Parameters
-----------------------

The last parameter for this step is a NoRMCorre parameters object.
This is just a `MATLAB structured array <https://www.mathworks.com/help/matlab/ref/struct.html>`_ that expects specific values. 
NoRMCorre provides the algorithm for registration and dictates the values in that struct.

There is an example parameters struct at the root of this repository, :scpt:`https://github.com/MillerBrainObservatory/LBM-CaImAn-MATLAB/blob/master/demo_CNMF_params.m`.

.. warning::

   Avoid the :code:`bidir` options as we correct for bi-directional scaling ourselves.

The most important NoRMCorre parameters are:

1. :code:`grid-size`
: Determines how many patches your image is split into. The smaller the patch, the **more precise the registration**, with a tradeoff being **increased compute times**.

2. :code:`max-shift`
: Determines the maximum number of pixels that your movie will be translated in X/Y.

3. :code:`fr`
: The frame rate of our movie, which is likely different than the 30Hz default.

4. :code:`correct_bidir`
: Attempts to correct for bi-directional scan offsets, a step that was performed :ref:`in pre-processing <scan_phase>`.

.. hint:: 

   If you see single frame, large shifts (e.g. > 20% of your neuron size), try decreasing the :code:`max-shift` parameter.


.. _registration_outputs:

Outputs
========================

Just like :ref:`pre-processing <extraction_inputs>`, registration outputs in `.h5` format.

.. _registration_format:

File-Format
-------------

Output data are saved in `.h5` format, with the following characteristics:
- one file per plane
- named "registration_plane_N.h5"
- metadata saved as attributes

You can use :code:`h5info(h5path)` in the MATLAB command window to reveal some helpful information about our data.

This file has the following groups:

:code:`/<param>`
: Takes the name of the :code:`ds` parameter. This group contains the 3D planar timeseries. Default `'/Y'`.
: :code:`h5read()`

:code:`/Ym`
: The mean image of the motion-corrected movie. Each image is averaged over time to produce the mean pixel intensity.

:code:`/template`
: The mean image [X, Y] used to align each frame in the timeseries. This image is calculated to correlate the most with each frame in the image.

:code:`/shifts`
: A :code:`2xN` column vector containing the number of pixels in X and Y that each frame was shifted.

.. hint::

    To get the shifts and plot them in MATLAB:

    .. code-block:: MATLAB

        x_shifts = shifts(:,1) % represent pixel-shifts in *x*
        y_shifts = shifts(:,2) % represent pixel-shifts in *y*

.. _reg_results:

Validate Outputs
-------------------------

.. note::

   Figures of the below validation metrics are placed in your save_path as `figures/registration_metrics_plane_N`.

The primary method to evaluate registration are with correlation images.

Internally, the pipeline first create a "template" using :ref:`rigid registration <tut_rigid>`. Each frame of the timeseries is aligned to this frame.

The distance to shift these pixels is computed by locating the maximum of the cross-correlation between the each and every frame and the template.

.. thumbnail:: ../_images/reg_correlation.png
   :title: Correlation Metrics

The above image shows these correlations.

Pixels that are highly correlated over the timecourse of an experiment are stationary in the image. Proper registration should **increase the correlation between neighboring pixels**.

The above shows the correlation coefficient for the raw image, template image created with rigid registration, and peicewise-rigid registration.

Values closer to 1 indicate a frame that is more correlated with the mean image.

Immediately obvious is the sharp decrease in correlation present in the blue raw data that was corrected in the rigid/non-ridid datapoints.

.. thumbnail:: ../_images/reg_correlation_zoom.png
   :title: Correlation Metrics

.. TODO

There is very little improvement gained by performing non-rigid motion correction, which is a very computationally demanding task.

These metrics are provided for you alongside the mean images and X/Y shifts to help assess the contribution of movement in the X and Y directions.

Particularly helpful is directly comparing pixel correlations between :ref:`3D timeseries <terms>`:

.. thumbnail:: ../_images/reg_corr_solo.svg

.. thumbnail:: ../_images/reg_metrics.png

.. thumbnail:: ../_images/reg_shifts.png

.. tip::

   A quick way to see if registration was effective is to compare the two mean images,
   looking for differences in the "blurryness" between them. 

.. thumbnail:: ../_images/reg_blurry.svg
   :title: Raw vs Registered Movie

