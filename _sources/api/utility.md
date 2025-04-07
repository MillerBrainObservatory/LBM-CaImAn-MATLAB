(utility_api)=
# Utility

Functions used by the pipeline that users can take advantage of to further process LBM datasets.

## Readers

```{eval-rst}

.. currentmodule:: utils

.. autofunction:: read_h5_metadata
.. autofunction:: read_plane
.. autofunction:: get_metadata

```

## Writers

```{eval-rst}

.. autofunction:: write_frames_2d
.. autofunction:: write_frames_3d
.. autofunction:: write_frames_to_avi
.. autofunction:: write_frames_to_gif
.. autofunction:: write_frames_to_h5
.. autofunction:: write_frames_to_tiff
.. autofunction:: write_images_to_gif
.. autofunction:: write_images_to_tile
.. autofunction:: write_mean_images_to_png
.. autofunction:: reorder_h5_files

```

## Visualization

```{eval-rst}

.. autofunction:: play_movie
.. autofunction:: set_caxis
.. autofunction:: calculate_scale
.. autofunction:: get_central_indices
.. autofunction:: get_segmentation_metrics
.. autofunction:: translate_frames

```

## Validation

```{eval-rst}

.. autofunction:: validate_toolboxes
.. autofunction:: display_dataset_names

```
