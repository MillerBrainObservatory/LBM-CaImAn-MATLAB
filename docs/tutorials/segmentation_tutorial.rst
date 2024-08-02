.. _tut_source_extraction:

Explained: Source Extraction
################################

This section details background information helpful with :ref:`Step 3: Segmentation <source_extraction>`

Source extraction is the umbrella term for a sequence of steps designed to distinguish neurons from background signal calculate the properties and characteristics of these neurons relative to the background.

The first step to source extraction is often the most computationally expensive step of calcium imaging pipelines: Segmentation.

Segmentation is the process of distinguishing between two spatially or temporally correlated neurons using object boundries and regions.

Subsequent processing would then involve cell identification, classification (assign labels), and extraction.

This pipeline centers around the segmentation algorithm **`Constrained Non-Negative Matrix Factorization (CNMF)`**

Overview
===================

Definitions
-------------------

`segmentation`
: The general process of dividing an image based on the contents of that image, in our case, based on neuron location.

`source-extraction`
: Umbrella term for all of the individual processes that produce a segmented image.

`deconvolution`
: The process performed after segmentation to the resulting traces to infer spike times from flourescence values.

`CNMF`
: The name for a set of algorithms within the flatironinstitute's `CaImAn Pipeline <https://github.com/flatironinstitute/CaImAn-MATLAB>`_ that initialize parameters and run source extraction.

Constrained Non-Negative Matrix Factorization (CNMF)
-------------------------------------------------------------

At a high-level, the CNMF algorithm works by:

1. Breaking the full FOV into **patches** of :code:`grid_size` with a set :code:`overlap` in each direction.
2. Looking for K components in each patch.
3. Filter false positives.
4. Combine resulting neuron coordinates **(spatial components)** for each patch into a single structure: :code:`A_keep` and :code:`C_keep`.
5. The time traces **(temporal components)** in the original resolution are computed from :code:`A_keep` and :code:`C_keep`.
6. Detrended DF/F values are computed.
7. These detrended values are deconvolved.

-----

Deconvolution
-------------------

The CNMF output yields "raw" traces, we need to deconvolve these to convert these raw traces to interpritable neuronal traces.

These raw traces are noisy, jagged, and must be denoised, detrended and deconvolved.

.. note::

   Deconvolution and correlation metrics are closely related (see `here <https://dsp.stackexchange.com/questions/736/how-do-i-implement-cross-correlation-to-prove-two-audio-files-are-similar>`_ for a helpful discussion).

- Each raw trace is deconvolved via "constrained foopsi", which yields:

:code:`g`
: The decay (and for p=2, rise) coefficients

:code:`S`
: The vector of "spiking" activity that best explain the raw trace.

.. note::

    S should ideally be ~90% zeros, also known as "sparse"

:code:`S` and :code:`g` are then used to produce :code:`C` (deconvolved traces), which looks like the raw trace :code:`Y`, but much cleaner and smoother.

.. important::

   The optional output YrA is equal to Y-C, representing the original raw trace.

.. thumbnail:: ../_images/seg_sparse_rep.png
   :width: 600

Validating Neurons and Traces
===========================================

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
- Frame rate = 4.7Hz

:math:`4.7Hz * (0.2+0.55) = 3` frames per transient.

And thus the general process of validating neuronal components is as follows:

- Use the decay time (0.5s) multiplied by the number of frames to estimate the number of samples expected in the movie.
- Calculate the likelihood of an unexpected event (e.g., a spike) and return a value metric for the quality of the components.
- Normal Cumulative Distribution function, input = -min_SNR.
- Evaluate the likelihood of observing traces given the distribution of noise.
