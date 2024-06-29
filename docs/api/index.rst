
###
API
###

To keep code and documentation as *in-sync* as possible, many (if not most) of the most helpful comments are in the functions docstring (directly under where the function is defined).

.. currentmodule:: .

Core
=======

.. autofunction:: convertScanImageTiffToVolume
.. autofunction:: motionCorrectPlane
.. autofunction:: segmentPlane
.. autofunction:: collatePlanes
.. autofunction:: calculateZOffset


Utilities
==============

.. currentmodule:: io

.. autofunction:: read_plane
.. autofunction:: read_h5_metadata
.. autofunction:: rename_planes
.. autofunction:: log_metadata
.. autofunction:: make_zoomed_movie
.. autofunction:: display_dataset_names

.. currentmodule:: utils

Utilities
=============

.. toctree::
    :maxdepth: 1

.. autofunction:: get_metadata
.. autofunction:: get_segmentation_metrics
.. autofunction:: get_central_indices
.. autofunction:: make_tiled_figure
.. autofunction:: translate_frames
.. autofunction:: validate_toolboxes
