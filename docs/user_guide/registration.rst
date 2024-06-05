Piecewise-Rigid Motion-Correction
================================================================

Function for this step: :func:`motionCorrectPlane`

For a quick demo on how to run motion correction, see the demo_registration.m script.

.. note::

   The terms motion-correction and registration are often used interchangably.


The goal of motion correction is to make sure that our neuron in the first frame is in the same spatial location as in frame N throughout the time-series.
Natural movement by the animal during experimental tasks can cause our images spatial potition varying slightly frame by frame. The extent of this movement can also vary widely depending
on the type of task the animal is performing.

For this reason, it is *very* important for the researcher to verify that any motion artifacts in the movie are removed before moving onto any subsequent computations.


Rigid vs Non-Rigid
*******************

The motion artifacts present in a movie also come in two flavors, `rigid` and `non-rigid`.
Purely rigid motion is simple, straightforeward movement that applies to each-and-every pixel equally.
The entire 2D image is shifted by a number of pixels in the x direction and y direction.

Non-rigid artifacts are much more complex as one region of the 2D image requires shifts that another region does not.

Motion correction relies on _`NoRMCorre` for piecewise-rigid motion correction resulting in shifts for each patch.

.. thumbnail:: ../_static/_images/patches.png
   :width: 1440

To run motion-correction, call `motionCorrectPlane()`:

.. code-block:: MATLAB

    % recall our directory structure, chaining the output path from the
    % tiff reconstruction step
    mcpath = 'C:\Users\RBO\Documents\data\bi_hemisphere\registration';

    % data_path, save_path, num_cores, start_plane, end_plane
    motionCorrectPlane(extract_path, mcpath, 23, 1, 3);

For input, use the same directory as `save_path` parameter in :func:`convertScanImageTiffToVolume`.

- `data_path`: Path to your extracted dataset.
- `save_path`: Path to save your data.
- `num_cores`: the number of CPU cores to dedicate to motion-correction.
- `start_plane`: The index of the first z-plane to motion-correct.
- `end_plane`: The index of the last z-plane to motion-correct.

.. note::

   Each Z-plane in between start_plane and end_plane will be processed. In the future we may want to provide a way to give an array of indices to correct e.g. if the user wants to throw out Z-planes.

Registration Output
************************

- The output is a 2D column vector [x, y] with shifts that allow you to reconstruct the motion-corrected movie with _`core.utils.translateFrames`.
- shifts(:,1) represent pixel-shifts in *x*
- shifts(:,2) represent pixel-shifts in *y*

Perform both piecewise-rigid motion correction using `NormCORRe`_ to stabilize the imaging data. Each plane is motion corrected sequentially, so
only a single plane is ever loaded into memory due to large LBM filesizes (>35GB). A template of 150-200 frames is used to initialize a "reference image".

.. thumbnail:: ../_static/_images/template1.png
    :title: Template Image
    :download: true

This image is your "ground truth" per-se, it is the image you want to most accurately represent the movement in your video.

Compared with the below frame:

.. _storage:

.. thumbnail:: ../_static/_images/quickview_blue.png
   :group: ck
   :align: center

Storage
******************

.. thumbnail:: ../_static/_images/storage_rec.png
    :title: Recommended Data Storage Paradigm
    :download: true

We want to minimize the amount of storage space, so rather than saving 2 versions of a video that differ by simply shifting some pixels, we can instead save only the shift vectors
and reconstruct the video afterwards. :func:`translateFrames` will accomplish this:

.. code-block:: MATLAB

   >> help translateFrames

     translateFrames Translate image frames based on provided translation vectors.

      This function applies 2D translations to an image time series based on
      a series of translation vectors, one per frame. Each frame is translated
      independently, and the result is returned as a 3D stack of
      (Height x Width x num_frames) translated frames.

      Inputs:
        Y - A 3D time series of image frames (Height x Width x Number of Frames).
        t_shifts - An Nx2 matrix of translation vectors for each frame (N is the number of frames).

      Output:
        translatedFrames - A 3D array of translated image frames, same size and type as Y.


Metrics
*************************

CaImAn provides some useful metrics to determine the effectiveness of registration.
These will be placed in the same directory as your save_path, `metrics/registration_metrics_plane_N`.

.. thumbnail:: ../_static/_images/motion_metrics.png
   :download: true

The top figure shows our shifts for rigid and non-rigid motion correction. This gives an idea what proportion of the movement corrected for can be attributed to rigid or non-rigid motion.
Underneath you see the rigid shifts for X and Y, respectively.

To view the video, use the function :func:`planeToMovie`, which can also zoom in on select areas of your movie::

    Inputs:
      data - 3D matrix of image data.
      filename - Name of the output video file.
      x - Horizontal coordinates.
      y - Vertical coordinates.
      frameRate - Frame rate of the output video.
      avgs - Number of frames to average.
      zoom - Zoom factors. (not implemented)
      decenter - Decentering offsets.
      crf - Constant Rate Factor for video quality.

