
Semantics
#########

Throughout the pipeline, image-processing terms will be used such as::

    ROI STRIP FRAME IMAGE PLANE VOLUME TIME-SERIES Z-STACK T-STACK

ScanImage `multi-ROI`_ .tiff outputs are made up of individual sections called that ScanImage calls `ROIs`. These `ROIs` collectively form a
ScanImage `ScanField`. In :ref:`pre_processing`, the term ROI refers to a "subsection" of the 2D image in which the scanner momentarily stopped acquisition.

- `num_pixel_xy` are the number of pixels in each `ROI`.
- With there being 9 ROIs, we know our image is :math:`144x8=1296` pixels wide.

So that explains why is our `image_length` is so high compared to our `image_width`.

However, you'll notice :math:`1200x9=10800` is significanly less than our `image_height`.

This is because the scanner is actually moving to the next ROI, so we stop collecting data for that period of time.
`num_lines_between_scanfields` is calculated using this amount of time and is stripped during the horizontal concatenation.

.. note::

    We use the term 'frames' as in video frames, i.e., number of timesteps the scan
    accumulated during acquisition.

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

.. _multi-ROI: https://docs.scanimage.org/Premium%2BFeatures/Multiple%2BRegion%2Bof%2BInterest%2B%28MROI%29.html#multiple-region-of-interest-mroi-imaging/
