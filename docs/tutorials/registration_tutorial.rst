.. _tut_registration:

Explained: Registration
###########################

.. note::

   The terms motion-correction and registration are often used interchangably.
   Similary, non-rigid and peicewise-rigid are often used interchangably.
   Here, peicewise-rigid registration is the **method** to correct for non-rigid motion.

.. _tut_types_of_reg:

Types of Registration
==========================

`Image registration <https://en.wikipedia.org/wiki/Image_registration>`_  can often improve the quality of cellular traces obtained during the later segmentation step. 

The motion artifacts present in a 3D timeseries come in two flavors, `rigid` and `non-rigid`.

.. _tut_rigid:

Rigid
---------------------------

Rigid motion
: The object is moved with its shape and size preserved.

- simple
- applies to each pixel equally
- The entire 2D image is shifted by a number of pixels in the x direction and y direction.

With timeseries that exibit little sub-cellular movement over the course of a timeseries, non-rigid registration is often overkill as rigid-registration will do a good enough job.

Correcting for non-rigid motion occurs via giving NoRMCorre default parameters, leading to patches the same size as the image.

.. _tut_nonrigid:

Non-rigid
---------------------------

Non-Rigid motion
: The object is moved and transforms shape or size.

- complex
- region A requires more shift than region B

Correcting for non-rigid motion requires dividing the field-of-view into patches, and performing *rigid* motion correction on each patch.

Non-rigid registration requires performing rigid registration on small subsections of our image.

.. thumbnail:: ../_images/reg_patches.png
   :width: 1440

