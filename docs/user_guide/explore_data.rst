Exploring Datasets
######################

There are several helper functions located in ``core/utils``.

Reading Data
=============

:func:`read_plane` is helper function that lets you quickly load a HDF5 plane without dealing with matlabs `h5read <https://www.mathworks.com/help/matlab/ref/h5read.html>`_ function.

You can use it using prompts:

.. code-block:: MATLAB

     Use dialog and prompts only:
         Y_out = read_plane();

.. warning::

   Make you you include the semi-colon ; after you call read_plane(), otherwise your command window will print every value in the dataset to the command window.

You can give it a folder containing H5 files, and you will be prompted for the plane and frames:

.. code-block:: MATLAB

    >> Y_out = read_plane('path/to/h5');

    Which plane do you want to read? Enter a number (e.g. 4)

    >> 4

    Which frames do you want to read? enter a slice, vector with start/stop or 'all':

    >> [1 15]

If you already know which plane you want to load, use that as a `key-value pair` (hence why you need to include `plane` before the value):

.. code-block:: MATLAB

     Y_out = read_plane('C:/data/extracted_files', 'plane', 4);

Or just give a path to the fully qualified filename of the plane you wish to read (so you no longer need the 'plane':

.. code-block:: MATLAB

    Y_out = read_plane('C:/data/extracted_files/data.h5');

Pick how many frames you want to load in a similar manner:

.. code-block:: MATLAB

     Y_out = read_plane('data.h5', 'frames', 1:10);

Or :code:`all` for everything:

.. code-block:: MATLAB

     Y_out = read_plane('data.h5', 4, 'all');

Mean Images
=============

Mean images are a good way to see small artifacts that may appear in sparse areas.

Quickly view a grid of mean images with :func:`write_mean_images_to_png`:

.. thumbnail:: ../_images/gen_mean_images.png
   :align: center

Making Gifs
==============

:func:`write_frames_to_gif` lets you visualize your movie quickly at any stage.

.. code-block:: MATLAB

    array = rand(100, 100, 500)
    write_frames_to_gif(array, 'output.gif', 45)

You want your input array to have dimensions :code:`height x width x frames`. For very large movies, use the :code:`size_mb` parameter to limit the resulting gif to that many megabytes.

Quick-play Movies
=========================

:func:`play_movie()`: Quickly view a movie of any plane.

.. code-block:: MATLAB

    % read in a motion-corrected plane
    y_extracted = read_plane('C:/data/extraction/', 'plane', 4);
    y_corrected = read_plane('C:/data/registration/', 'plane', 4);
    play_movie({y_extracted, y_corrected}, {'Raw', 'Corrected'}, 0, 255)

.. thumbnail:: ../_images/plane_1.gif
   :align: center

