What does CNMF do?
===========================

The CNMF output yields "raw" traces.

These raw traces are noisy, jagged, and must be denoised/deconvolved.
- Another term for this is "detrending", removing non-stationary variability from the signal

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

Theory Underlying Component Validation
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
