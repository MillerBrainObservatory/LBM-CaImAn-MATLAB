Functions
===========

There are core functions used to run the pipeline and several helper functions for tasks such as loading data,

.. currentmodule:: .

Core
===========

.. autofunction:: convertScanImageTiffToVolume
.. autofunction:: motionCorrectPlane
.. autofunction:: segmentPlane
.. autofunction:: collatePlanes
.. autofunction:: calculateZOffset


Utilities
==============

Utilities for reading, writing, inspecting and visualizing data.

.. currentmodule:: utils

.. autofunction:: display_dataset_names
.. autofunction:: get_central_indices
.. autofunction:: get_metadata
.. autofunction:: get_segmentation_metrics
.. autofunction:: translate_frames
.. autofunction:: read_h5_metadata
.. autofunction:: read_plane
.. autofunction:: reorder_h5_files
.. autofunction:: validate_toolboxes
.. autofunction:: write_frames_to_h5
.. autofunction:: write_frames_to_gif
.. autofunction:: write_frames_to_tiff
.. autofunction:: write_tiled_figure

Internal
=============

.. currentmodule:: internal

Functions that are meant for use within the pipeline, not for public use.

.. autofunction:: is_valid_group
.. autofunction:: is_valid_dataset
   .. .. autofunction:: log_struct
   .. .. autofunction:: set_caxis
   .. .. autofunction:: calculate_scale
