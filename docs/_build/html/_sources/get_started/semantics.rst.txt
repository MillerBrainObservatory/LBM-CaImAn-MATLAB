
Semantics
#########

Throughout the pipeline, image-processing terms will be used such as::

    ROI STRIP FRAME IMAGE PLANE VOLUME TIME-SERIES Z-STACK T-STACK

.. list-table:: LBM Semantics
   :header-rows: 1

   * - Dimension
     - Description
   * - [X, Y]
     - Image / Plane / Frame (short for "picture frame")
   * - [X, Y, Z]
     - Volume, 3D-Stack, Z-Stack
   * - [X, Y, Z, T]
     - Volumetric Timeseries
   * - [X, Y, T]
     - Time-Series of a 2D Plane

Within an image, we are dealing with ScanImage `multi-ROI`_ scans. During aquisition, the user choses the "number of pixels in X/Y (see :ref:`image size` in :ref:`metadata`)

Each ROI can be trimmed and smoothed to blend with adjacent ROI's.

.. note::

    We use the word 'frames' as in video frames, i.e., number of timesteps the scan
    was recorded; ScanImage uses frames to refer to slices/scanning depths in the
    scan.

.. _multi-ROI: https://docs.scanimage.org/Premium%2BFeatures/Multiple%2BRegion%2Bof%2BInterest%2B%28MROI%29.html#multiple-region-of-interest-mroi-imaging/
