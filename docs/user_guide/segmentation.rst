.. _segmentation:

Segmentation
============

Segment the motion-corrected data and extract neuronal signals.

Currently, this function makes the following assumptions:

- 2nd order flourescence dynamics
- Imaging in mouse cortex (9.2e4 neurons/mm^3)

.. code-block:: MATLAB

   >> help segmentPlane

      segmentPlane Segment imaging data using CaImAn for motion-corrected data.

      This function applies the CaImAn algorithm to segment neurons from
      motion-corrected, pre-processed and ROI re-assembled MAxiMuM data.
      The processing is conducted for specified planes, and the results
      are saved to disk.

      Parameters
      ----------
      path : char
          The path to the local folder containing the motion-corrected data.
      diagnosticFlag : char
          When set to '1', the function reports all .mat files in the directory
          specified by 'path'. Otherwise, it processes files for neuron segmentation.
      startPlane : char
          The starting plane index for processing. A non-numeric input or '0' sets
          it to default (1).
      endPlane : char
          The ending plane index for processing. A non-numeric input or '0' sets
          it to default (maximum available planes).
      numCores : char
          The number of cores to use for parallel processing. A non-numeric input
          or '0' sets it to the default value (12).

      Outputs
      -------
        - T_keep: neuronal time series [Km, T] (single)
        - Ac_keep: neuronal footprints [2*tau+1, 2*tau+1, Km] (single)
        - C_keep: denoised time series [Km, T] (single)
        - Km: number of neurons found (single)
        - Cn: correlation image [x, y] (single)
        - b: background spatial components [x*y, 3] (single)
        - f: background temporal components [3, T] (single)
        - acx: centroid in x direction for each neuron [1, Km] (single)
        - acy: centroid in y direction for each neuron [1, Km] (single)
        - acm: sum of component pixels for each neuron [1, Km] (single)

      Notes
      -----
        - The function handles large datasets by processing each plane serially.
        - Ensure your RAM capacity exceeds the size of a single plane.
        - The segmentation settings are based on the assumption of 9.2e4 neurons/mm^3
            density in the imaged volume as seen in the mouse cortex.

      See also addpath, fullfile, dir, load, savefast

Segmentation has the largest computational and time requirements.

**Output**

The output of _`segmentPlane` is a series of .mat files named caiman_output_plane_N.mat, where N=number of planes.

.. code-block:: MATLAB

    merge_thresh = 0.8;
    min_SNR = 1.4;
    space_thresh = 0.2; % threhsold for spatial comps
    time_thresh = 0.0;
    sz = 0.1; % IF FOOTPRINTS ARE TOO SMALL, CONSIDER sz = 0.1
    mx = ceil(pi.*(1.33.*tau).^2);
    mn = floor(pi.*(tau.*0.5).^2); % SHRINK IF FOOTPRINTS ARE TOO SMALL
    p = 2; % order of dynamics
    sizY = size(data);
    patch_size = round(650/pixel_resolution).*[1,1];
    overlap = [1,1].*ceil(50./pixel_resolution);
    % number of components based on assumption of 9.2e4 neurons/mm^3
    K = ceil(9.2e4.*20e-9.*(pixel_resolution.*patch_size(1)).^M2);
