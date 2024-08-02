.. _registration:

Registration
#####################

Function for this step: :func:`motionCorrectPlane()`

.. note::

   The terms motion-correction and registration are often used interchangably.
   Similary, non-rigid and peicewise-rigid are often used interchangably.
   Here, peicewise-rigid registration is the **method** to correct for non-rigid motion.

.. _reg_overview:

Overview
====================

`Image registration <https://en.wikipedia.org/wiki/Image_registration>`_  can often improve the quality of cellular traces obtained during the later segmentation step. 

The motion artifacts present in a 3D timeseries come in two flavors, `rigid` and `non-rigid`.

.. _tut_rigid:

Rigid Registration
---------------------------

Rigid motion
: The object is moved with its shape and size preserved.

- simple
- applies to each pixel equally
- The entire 2D image is shifted by a number of pixels in the x direction and y direction.

With timeseries that exibit little sub-cellular movement over the course of a timeseries, non-rigid registration is often overkill as rigid-registration will do a good enough job.

Rigid registration is accomplished by giving NoRMCorre no variable for grid-size, so it defaults to the size of your image and thus only processing a single patch encompassing the entire field-of-view.

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

.. _tut_nonrigid:

Non-rigid Registration
---------------------------

Non-rigid registration requires performing rigid registration on small subsections of our image.

.. thumbnail:: ../_images/reg_patches.png
   :width: 1440

.. code-block:: MATLAB

   options_rigid = NoRMCorreSetParms(...
      'd1',size(Y, 1),... 
      'd2',size(Y, 2),...
      'bin_width',200,...   % number of frames to initialze the template
      'max_shift', round(20/pixel_resolution), ... % still useful in non-rigid
   );

Non-Rigid motion
: The object is moved and transforms shape or size.

- complex
- region A requires more shift than region B

Correcting for non-rigid motion requires dividing the field-of-view into patches, and performing *rigid* motion correction on each patch.

