Exploring Datasets
======================

There are several helper functions located in ``core/utils``

Making Gifs
==============

:func:`write_frames_to_gif` lets you visualize your movie quickly at any stage.

.. code-block:: MATLAB

    array = rand(100, 100, 500)
    write_frames_to_gif(array, 'output.gif', 45)

You want your input array to have dimensions :code:`height x width x frames`. For very large movies, use the :code:`size_mb` parameter to limit the resulting gif to that many megabytes.



