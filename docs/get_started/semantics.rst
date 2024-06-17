
Semantics
#########

Throughout the pipeline, several image-processing terms will be used such as::

    ROI STRIP FRAME IMAGE PLANE VOLUME TIMESERIES Z-STACK T-STACK

ScanImage `multi-ROI`_ .tiff outputs are made up of individual sections called that ScanImage calls `ROIs`. These `ROIs` collectively form a
ScanImage `ScanField`. In :ref:`pre_processing`, the term ROI refers to a "subsection" of the 2D image in which the scanner momentarily stopped acquisition.

- `num_pixel_xy` are the number of pixels in each `ROI`.
- With there being 9 ROIs, we know our image is :math:`144x8=1296` pixels wide.

So that explains why is our `image_length` is so high compared to our `image_width`.

However, you'll notice :math:`1200x9=10800` is significanly less than our `image_height`.

This is because the scanner is actually moving to the next ROI, so we stop collecting data for that period of time.
`num_lines_between_scanfields` is calculated using this amount of time and is stripped during the horizontal concatenation.

.. list-table:: LBM Semantics
   :header-rows: 1

   * - Dimension
     - Description
   * - [X, Y]
     - Image / Plane / Frame / Field / ScanField
   * - [X, Y, Z]
     - Volume, 3D-Stack, Z-Stack, Planar-timeseries
   * - [X, Y, Z, T]
     - Volumetric Timeseries
   * - [X, Y, T]
     - Time-Series of a 2D Plane

<<<<<<< HEAD
=======
Within an image, we are dealing with ScanImage `multi-ROI`_ scans.

During aquisition, the user choses the "number of pixels in X/Y (see :ref:`image size` in :ref:`metadata`)

Each ROI can be trimmed and smoothed to blend with adjacent ROI's.

.. note::

    We use the word 'frames' as in video frames, i.e., number of timesteps the scan
    was recorded; ScanImage uses frames to refer to slices/scanning depths in the
    scan.

.. _multi-ROI: https://docs.scanimage.org/Premium%2BFeatures/Multiple%2BRegion%2Bof%2BInterest%2B%28MROI%29.html#multiple-region-of-interest-mroi-imaging/
