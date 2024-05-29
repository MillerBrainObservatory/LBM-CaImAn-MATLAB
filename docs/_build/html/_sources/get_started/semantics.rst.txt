
Semantics
#########

Throughout the pipeline, image-processing terms will be used such as::

    ROI STRIP FRAME IMAGE PLANE VOLUME TIME-SERIES Z-STACK T-STACK

This section aims to define these terms with respect to the LBM Data Processing Pipeline.

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

*Strip* and ROI are used interchangably in the ScanImage documentation. We will be referring to the individual sections of a ScanImage `.tiff` recording as `strips` and refrain from using `ROI`.


.. note::

    We use the word 'frames' as in video frames, i.e., number of timesteps the scan
    was recorded; ScanImage uses frames to refer to slices/scanning depths in the
    scan.
