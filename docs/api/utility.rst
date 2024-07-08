Utility
==========

.. currentmodule:: utils

Readers
*********
.. autofunction:: read_h5_metadata
.. autofunction:: read_plane

Writers
*********

.. autofunction:: write_frames_to_h5
.. autofunction:: write_frames_to_gif
.. autofunction:: write_frames_to_tiff
.. autofunction:: write_tiled_figure

Visualization
****************

.. autofunction:: get_central_indices
.. autofunction:: get_segmentation_metrics
.. autofunction:: translate_frames

Validation
***********

.. autofunction:: reorder_h5_files
.. autofunction:: get_metadata
.. autofunction:: validate_toolboxes
.. autofunction:: display_dataset_names

Internals
***********

.. currentmodule:: internal

Functions that are meant for use within the pipeline, not for public use.

.. autofunction:: is_valid_group
.. autofunction:: is_valid_dataset
.. autofunction:: log_struct
.. autofunction:: set_caxis
.. autofunction:: calculate_scale
