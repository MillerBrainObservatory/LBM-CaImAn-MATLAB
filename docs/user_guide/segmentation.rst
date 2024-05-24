.. _segmentation_deconvolution:

Segmentation and Deconvolution
###########################################

.. thumbnail:: ../_static/_images/neuron_to_neuron_correlations.png
   :width: 600

Overview
==================

The flourescence of the proteins in our neurons is **correlated** with how active the neuron is.
Turning this flourescence into "spikes" relies on several mathmatical operations to:

- isolate neuronal activity from background activity (:ref:`source extraction`).
- infer the times of action potentials from the fluorescence traces (:ref:`deconvolution`).

Before calling , make sure you:

- Understand the parameters and how they effect the output.
- Confirmed no stitching artifacts or bad frames.
- Validate your movie is accurately motion corrected.

Source Extraction
==================

:ref:`segmentPlane` contains the bulk of the computational complexity in this pipeline and will take significantly longer than the previous steps.

Inputs are covered in :ref:`parameters`, with a few additional parameters. To understand these parameters, you have to understand a bit about what CNMF is trying to do.
Much of work is about separating "good activity", the flourescence changes that we can attribute to a single cell, vs "noise, which is everything else (including signal from other neurons).
To do this, we take advantage of the fact that the slow calcium signal is typically very similar between adjacent frames. See `this blog post` for a nice discussion on shot noise calculations and poissson processes.

The *speed of transients*, or the time it takes for the neuron to fully glow (rise time) and unglow (decay time), is a very important metric used to calculate several of the parameters for CNMF.

In particular, speed of transients relative to the frame rate can be thought of in terms of "how many frames does it take my calcium indicator to undergo a complete transients cycle".

`cnmf_options`
************************************

This is a structured array containing key:value pairs of all of your CNMF parameters.
See the example parameters in the LBM_demo_pipeline.

- If this parameter is not included, they will be calculated for you based on the pixel resolution, frame rate and image size in the metadata.
- For example, `Tau` is a widely talked about parameter being the half-size of your neuron. This is calculated by default as (7.5/pixel_resolution, 7.5/pixelresolution).

There are several different thresholds, indicating correlation coefficients as barriers for whether to perform a process or not.

merge_thresh
************************************

A correlation corefficient determining the amount of correlation between pixels in time needed to consider two neurons the same neuron.
- The lower your resolution, the more "difficult" it is for CNMF to distinguish between two tight neurons, thus use a lower merge threshold.
- This parameter heavily effects the number of neurons processed. It's always better to have to many neurons vs too few, as you can never get a lost neuron back, but you can invalidate neurons in post-processing.

min_SNR
************************************

 The minimum "shot noise" to calcium activity to accept a neurons initialization.

- Tau is the `half-size` of a neuron. If a neuron is 10 micron, tau will be a 5 micon.
- In general, round up.
- The kernel is fixed to have this decay and is not fit to the data.

P
************************************

The term autoregression indicates that it is a regression of the variable against itself. Thus, an autoregressive model of order p can be written as yt=c+ϕ1yt−1+ϕ2yt−2+⋯+ϕpyt−p+εt,

- I dont know what that means, but that's wikipedia. P = 1 is used when you have a fast indicator, for the reasons mentioned above regarding decay time. Use p=2 for slow indicators where you only expect 1-3 frames.

.. code-block:: MATLAB

    options = CNMFSetParms(...
        'd1',d1,'d2',d2,...                         % dimensionality of the FOV
        'deconv_method','constrained_foopsi',...    % neural activity deconvolution method
        'temporal_iter',3,...                       % number of block-coordinate descent steps
        'maxIter',15,...                            % number of NMF iterations during initialization
        'spatial_method','regularized',...          % method for updating spatial components
        'df_prctile',20,...                         % take the median of background fluorescence to compute baseline fluorescence
        'p',p,...                                   % order of AR dynamics
        'gSig',tau,...                              % half size of neuron
        'merge_thr',merge_thresh,...                % merging threshold
        'nb',1,...                                  % number of background components
        'gnb',3,...
        'min_SNR',min_SNR,...                       % minimum SNR threshold
        'space_thresh',space_thresh ,...            % space correlation threshold
        'decay_time',0.5,...                        % decay time of transients, GCaMP6s
        'size_thr', sz, ...
        'search_method','ellipse',...
        'min_size', round(tau), ...                 % minimum size of ellipse axis (default: 3)
        'max_size', 2*round(tau), ...               % maximum size of ellipse axis (default: 8)
        'dist', dist, ...                           % expansion factor of ellipse (default: 3)
        'max_size_thr',mx,...                       % maximum size of each component in pixels (default: 300)
        'time_thresh',time_thresh,...
        'min_size_thr',mn,...                       % minimum size of each component in pixels (default: 9)
        'refine_flag',0,...
        'rolling_length',ceil(FrameRate*5),...
        'fr', FrameRate ...
    );

When running :ref:`segmentPlane`, check the command window for reports that match the number of files you expect to be processed:

.. code-block:: MATLAB

    Processing 30 files found in directory C:\Users\<username>\Documents\data\bi_hemisphere\registration\...  %% our data_path
    Beginning calculations for plane 1 of 30...  %% check this matches the number of Z-Planes you expect
    Data loaded in. This process takes 0.024489 minutes.
    Beginning patched, volumetric CNMF...


AtoAc
====================================

Turn the CaImAn output A (sparse, spatial footprints for entire FOV) into Ac (sparse, spatial footprints localized around each neuron).
- Standardizes the size of each neuron's footprint to a uniform (4*tau+1, 4*tau+1) matrix, centered on the neuron's centroid [acx x acy].

.. thumbnail:: ../_static/_images/sparse_rep.png
   :width: 600

Component Validation
====================================

The key idea for validating our neurons is that **we know how long the
brightness indicating neurons activity should stay bright** as a function
of the *number of frames*.

That is, our calcium indicator (in this example: GCaMP-6s), with a rise-time of 250ms and a decay-time of 500ms = 750ms, while we
record at 4.7 frames/second = “Samples per transient\=round(4.7Hz×(0.2s+0.55s))\=3”

- Use the decay time (0.5s) multiplied by the number of frames to estimate the number of samples expected in the movie.
- Calculate the likelihood of an unexpected event (e.g., a spike) and return a value metric for the quality of the components.
 - Normal Cumulative Distribution function, input = -min_SNR.
- Evaluate the likelihood of observing traces given the distribution of noise.

Output
************************************
- Factorization via CNMF yields "raw" traces ("y"). These raw traces are noisy and jagged.
- Each raw trace is deconvolved via "constrained foopsi," which yields the decay (and for p=2, rise) coefficients ("g") and the vector of "spiking" activity ("S") that best explain the raw trace. S should ideally be ~90% zeros.
- S and g are then used to produce C, which (hopefully) looks like the raw trace Y, but much cleaner and smoother. The optional output YrA is equal to Y-C, representing the original raw trace.

Deconvolution
============================

TODO: put this foopsi trickyness information in "For Developers" section

FOOPSI (Fast OOPSI) is originally from "Fast Nonnegative Deconvolution for Spike Train Inference From Population Calcium Imaging" by Vogelstein et al. (2010).
- OASIS was introduced in "Fast Active Set Methods for Online Spike Inference from Calcium Imaging" by Friedrich & Paninski (2016).
- Most of the CAIMAN-MATLAB code uses OASIS, not FOOPSI, despite some functions being named "foopsi_oasis."

Branches from the main "deconvolveCa" function in MATLAB_CAIMAN:

**oasis** branches: Despite some being named "foopsi_oasis," they use OASIS math.
- foopsi_oasisAR1
- foopsi_oasisAR2
- constrained_oasisAR1
- thresholded_oasisAR1
- thresholded_oasisAR2
**constrained_foopsi** branch: Used if method="constrained" and model type is not "ar1" (e.g., ar2).
- Optimization methods: CVX (external), SPGL1 (external), LARS, dual.
**onnls** branch: Used if method="foopsi" or "thresholded" with model type="exp2" or "kernel." Based on OASIS.

.. _NoRMCorre: https://github.com/flatironinstitute/NoRMCorre/
.. _constrained-foopsi: https://github.com/epnev/constrained-foopsi/
