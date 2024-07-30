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

Registration Inutputs
**********************

In addition to those referenced in :ref:`parameters`, registration has a few important additional parameters.

`start_plane` 
: The plane to start registration.

`end_plane` 
: The plane to end registration.

`options` 
: NormCorre Params Object

.. note::

   All planes in between :code:`start_plane` and `end_plane` will undergo registration `sequentially <https://www.merriam-webster.com/dictionary/sequential>`_.

NoRMCorre Parameters
-----------------------

The last parameter for this step is a NoRMCorre parameters object.
This is just a `MATLAB structured array <https://www.mathworks.com/help/matlab/ref/struct.html>`_ that expects specific values. 
`NoRMCorre <https://github.com/flatironinstitute/NoRMCorre>`_ provides the algorithm for registration and dictates the values in that struct.

To see all possible values possible for registration, see `here <https://github.com/flatironinstitute/NoRMCorre/blob/master/NoRMCorreSetParms.m`>_.
Additionally, there is an example parameters struct at the root of this repository, :scpt:`here`_.

.. warning::

   Avoid the :code:`bidir` options as we correct for bi-directional scaling ourselves.

The most important values to keep in mind:

1. grid-size
2. max-shift
3. fr (frame rate)

`grid-size` determines how many patches your image is split into. The smaller the patch, the **more precise the registration**, with a tradeoff being **increased compute times**.
`max-shift` determines the maximum number of pixels that your movie will be translated in X/Y. 
`fr` expects the frame rate of our movie, which is likely different than the 30hz default.

.. hint:: 

   If you see single frame, large shifts (e.g. > 20% of your neuron size), try decreasing the :code:`max-shift` parameter.

Rigid-Only Registration
---------------------------

With movies that exibit little sub-cellular movement over the course of a timeseries, non-rigid registration is often overkill as rigid-registration will do a good enough job.
Rigid registration is accomplished by giving NoRMCorre no variable for grid-size, so it defaults to the size of your image and thus only processing a single patch encompassing the entire field-of-view.

You can use :ref:`ScanImage <metadata>` to physically interpretable values. 

Here, we use the pixel-resolution (how many microns each pixel represents) to express a **max shift of 20 micron**:

.. code-block:: MATLAB

   plane_name = fullfile("path/to/raw_tif"); 
   metadata = read_metadata(plane_name);

   max_shift = 20/metadata.pixel_resolution


We can then use this value in our own parameters struct with the help of :ref:`read_plane()`:

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

Registration Outputs
*********************

Format
-------------

Output data are saved in `.h5` format, with the following characteristics:
- one file per plane
- named "registration_plane_N.h5"
- metadata saved as attributes

You can use :code:`h5info(h5path)` in the MATLAB command window to reveal some helpful information about our data.

This file has the following groups:

`/<param>`
: Takes the name of the :ref:`ds` :ref:`parameter <parameters>`_. This group contains the 3D planar timeseries. Default `'/Y'`.

`/Ym`
: The mean image of the motion-corrected movie. Each image is averaged over time to produce the mean pixel intensity.

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

See the previous section for an examples of viewing two outputs side-by-side.
