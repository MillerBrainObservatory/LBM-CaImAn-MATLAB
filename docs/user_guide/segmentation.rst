.. _source_extraction:

Source Extraction
################################

Overview
============

Function for this step: :func:`segmentPlane`

.. warning::

   :func:`segmentPlane` will take significantly longer than the previous steps.

    Much of work is about separating "good activity", the flourescence changes that we can attribute to a single cell, vs "noise, which is everything else (including signal from other neurons).
    To do this, we take advantage of the fact that the slow calcium signal is typically very similar between adjacent frames.
    See `this blog post <https://gcamp6f.com/2024/04/24/why-your-two-photon-images-are-noisier-than-you-expect/>`_ for a nice discussion on shot noise calculations and poisson processes.

The *speed of transients*, or the time it takes for the neuron to fully glow (rise time) and unglow (decay time), is a very important metric used to calculate several of the parameters for CNMF.

In particular, speed of transients relative to the frame rate can be thought of in terms of "how many frames does it take my calcium indicator to undergo a complete transients cycle".

The flourescence of the proteins in our neurons is **correlated** with how active the neuron is.
Turning this flourescence into "spikes" relies on several mathmatical operations to:

- isolate neuronal activity from background activity (:ref:`source extraction`).
- infer the times of action potentials from the fluorescence traces (:ref:`deconvolution`).

The CNMF algorithm works by:

1. breaking the full FOV into **patches** of :code:`patch_size` with a set :code:`overlap` in each direction
2. looking for K components in each patch
3. Filter false positives
4. Combine resulting neuron coordinates **(spatial components)** for each patch into a single structure: :code:`A_keep` and :code:`C_keep`
5. The time traces **(temporal components)** in the original resolution are computed from :code:`A_keep` and :code:`C_keep`
6. Detrended DF/F values are computed.
7. These detrended values are deconvolved.

Inputs (covered in :ref:`parameters`) are consistent with registration, however with only a single :code:`options` input struct.


.. hint::

    See the demo parameters script at the root of this repository.

Definitions
============

`segmentation`

    simply refers to dividing an image based on the contents of that image, in our case, based on neuron location.

`source-extraction`

    is more an umbrella term for all of the individual processes that produce a segmented image.

`deconvolution`

    The process performed after segmentation to the resulting traces to infer spike times from flourescence values.

`CNMF`

    The name for a set of algorithms within the flatironinstitute's `CaImAn Pipeline <https://github.com/flatironinstitute/CaImAn-MATLAB>`_ that
    initialize parameters and run source extraction.

Before running segmentation, make sure you:

- Understand the parameters and how they effect the output.
- Confirmed no stitching artifacts or bad frames.
- Validate your movie is accurately motion corrected.


Tuning CNMF
====================

.. note::

   There is an example file describing CNMF parameters at the root of this project. :scpt:`demo_CNMF_params`.

All of the parameters and options fed into the `CNMF` pipeline are contained within a single `MATLAB struct <https://www.mathworks.com/help/matlab/ref/struct.html>`_

To get an idea of the default parameters (what happens if you use :code:`CNMFSetParams()` with no arguments),
you can run the following code to see the defaults:

.. code-block:: MATLAB

   >> opts = CNMFSetParams()

- If this parameter is not included, they will be calculated for you based on the pixel resolution, frame rate and image size in the metadata.
- For example, `Tau` is a widely talked about parameter being the half-size of your neuron.

This is calculated by default as :math:`(7.5/pixel_resolution, 7.5/pixelresolution)`. This only makes sense if we assume an ~neuron size of `14um`.

There are several different thresholds, indicating correlation coefficients as barriers for whether to perform a process or not, discussed in the following sections.

merge_thresh
************************************

A correlation coefficient determining the amount of correlation between pixels in time needed to consider two neurons the same neuron.

- The lower your resolution, the more "difficult" it is for CNMF to distinguish between two tight neurons, thus use a lower merge threshold.
- This parameter heavily effects the number of neurons processed. It's always better to have to many neurons vs too few, as you can never get a lost neuron back, but you can invalidate neurons in post-processing.

min_SNR
************************************

The minimum "shot noise" to calcium activity to accept a neurons initialization (accept it as valid).

This value is used for an event exceptionality test, which tests the probabilty if some "exceptional events" (like a spike).

.. hint::

    **If this value is low, even a very slight deviation in signal will be considered exceptional and many background-neurons will be accepted**.

- The likeihood of observing the actual trace value over N samples given an estimated noise distribution.

- The function first estimates the noise distribution by considering the dispersion around the mode.

- This is done only using values lower than the mode. The estimation of the noise std is made robust by using the approximation std=iqr/1.349.

- Then, the probavility of having N consecutive eventsis estimated.

This probability is used to order the components according to "most likely to be exceptional".

:func:`compareZPlanes()` is primarily used to tune this value.

Tau
************************************

Half-size of your neurons.

- Tau is the `half-size` of a neuron. If a neuron is 10 micron, tau will be a 5 micron.
- In general, round up.

P
************************************

This is the autoregressive order of the system. It is a measure of how the signal changes with respect to time. This value will always be 1 or 2, depending on the frame rate of the video and the dynamics of the calcium indicator.



AtoAc
====================================

Turn the CaImAn output A (sparse, spatial footprints for entire FOV) into Ac (sparse, spatial footprints localized around each neuron).
- Standardizes the size of each neuron's footprint to a uniform (4*tau+1, 4*tau+1) matrix, centered on the neuron's centroid [acx x acy].

.. thumbnail:: ../_images/seg_sparse_rep.png
   :width: 600

Component Validation
====================================

.. note::

   Although it is important to understand the process governing validating neurons, this process is
   fully performed for you with no extra steps needed.

The key idea for validating our neurons is that **we know how long the
brightness indicating neurons activity should stay bright** as a function
of the *number of frames*.

That is, our calcium indicator (in this example: GCaMP-6s):
- rise-time of 250ms
- decay-time of 500ms
- total transient time = 750ms
- Frame rate = 4.7 frames/second

4.7hz * (0.2+0.55) = 3 frames per transient.

And thus the general process of validating neuronal components is as follows:

- Use the decay time (0.5s) multiplied by the number of frames to estimate the number of samples expected in the movie.
- Calculate the likelihood of an unexpected event (e.g., a spike) and return a value metric for the quality of the components.
- Normal Cumulative Distribution function, input = -min_SNR.
- Evaluate the likelihood of observing traces given the distribution of noise.

Output
==============

- The CNMF output yields "raw" traces ("y"). These raw traces are noisy and jagged and must be denoised/deconvolved.
- Another term for this is "detrending", removing non-stationary variability from the signal
- Each raw trace is deconvolved via "constrained foopsi," which yields the decay (and for p=2, rise) coefficients ("g") and the vector of "spiking" activity ("S") that best explain the raw trace. S should ideally be ~90% zeros.
- :code:`S` and :code:`g` are then used to produce :code:`C` (deconvolved traces), which looks like the raw trace :code:`Y`, but much cleaner and smoother.

.. important::

   The optional output YrA is equal to Y-C, representing the original raw trace.

Results
===========================

The output of the analysis includes several key variables that describe the segmented neuronal components and their corresponding activities. Below is a description of each output variable, along with an example of how to use them and what they represent.

Segmentation Outputs
*************************

1. :code:`T_all`: Neuronal time-series
    - The fluorescence time-series data for each detected neuronal component. Each row corresponds to a different neuron, and each column corresponds to a different time point.
    - This data can be used to analyze the temporal dynamics of neuronal activity, such as identifying patterns of activation over time.

    .. code-block:: matlab

        plot(T_all(1, :)); % Plot the time-series for the first neuron
        xlabel('Time (frames)');
        ylabel('Fluorescence (dF/F)');

2. :code:`C_all`: Deconvolved neuronal activity
    - The deconvolved activity traces, which represent the estimated underlying neuronal firing rates. This data is derived from `T_all` through a deconvolution process that attempts to remove the effects of calcium dynamics.
    - This data can be used to study the inferred spiking activity of neurons, which is often more directly related to neuronal communication than raw fluorescence data.

    .. code-block:: matlab

        plot(C_all(1, :)); % Plot the deconvolved activity for the first neuron
        xlabel('Time (frames)');
        ylabel('Deconvolved activity');

3. :code:`N_all`: Neuronal spatial coordinates mapped to X/Y coordinates
    - A matrix where each row represents a neuron, and the columns contain properties such as the neuron's integrated fluorescence (`acm`), x-coordinate (`acx`), y-coordinate (`acy`), and z-coordinate (plane index).
    - This data can be used to analyze the spatial distribution of neurons within the imaging field and correlate spatial properties with functional data.

    .. code-block:: matlab

        scatter(N_all(:, 2), N_all(:, 3)); % Plot the spatial distribution of neurons in the xy-plane
        xlabel('x-coordinate');
        ylabel('y-coordinate');

4. :code:`Ac_keep`: Neuronal footprints
    - The spatial footprints of the detected neurons. Each neuron is represented by a 2D matrix showing its spatial extent and intensity within the imaging field.
    - This data can be used to visualize the spatial arrangement and morphology of neuronal components.

.. code-block:: MATLAB

    >> figure; imagesc(Ac_keep(:,:,1)); axis image; axis tight; axis off; colormap gray; title("Single Spatial Component");
    >> size(Ac_keep)

    ans =

        33    33   447

.. thumbnail:: ../_images/seg_ac_keep.png
   :width: 800

5. :code:`Cn`: Correlation image
    - A 2D image showing the correlation of each pixel's time-series with its neighboring pixels, highlighting areas of correlated activity.
    - This image can be used to identify regions of interest and assess the overall quality of the motion correction and segmentation process.

.. code-block:: matlab

    >> figure; imagesc(Cn); axis image; axis tight; axis off; colormap gray; title("Single Spatial Component");
    >> size(Cn) % [Y, X]

    ans =

        583 528

.. thumbnail:: ../_images/seg_cn.png
   :width: 800

.. _deconvolution:

Note on Deconvolution
==============================

.. note::

   This section is more of a developer note into the code used for deconvolution. General users can skip this section. TODO: Refactor to devs/.

FOOPSI (Fast OOPSI) is originally from “Fast Nonnegative Deconvolution for Spike Train Inference From Population Calcium Imaging” by Vogelstein et al. (2010). OASIS was introduced in “Fast Active Set Methods for Online Spike Inference from Calcium Imaging” by Friedrich & Paninski (2016). Most of the CAIMAN-MATLAB code uses OASIS, not FOOPSI, despite some functions being named “foopsi_oasis.”

Branches
****************

1. **oasis branches**: Despite some being named “foopsi_oasis,” they use OASIS math.

- foopsi_oasisAR1
- foopsi_oasisAR2
- constrained_oasisAR1
- thresholded_oasisAR1
- thresholded_oasisAR2

2. **constrained_foopsi branch**: Used if ``method="constrained"`` and model type is not “ar1” (e.g., ar2).

- Optimization methods: CVX (external), SPGL1 (external), LARS, dual.

3. **onnls branch**: Used if ``method="foopsi"`` or ``method="thresholded"`` with model type=”exp2” or “kernel.” Based on OASIS.

.. _NoRMCorre: https://github.com/flatironinstitute/NoRMCorre/
.. _constrained-foopsi: https://github.com/epnev/constrained-foopsi/
