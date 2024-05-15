.. _offset_correction:

Axial-Offset Correction
=======================

Before proceeding:

- You will need to be in a GUI environment for this step. Calculate offset will show you two images, click the feature that matches in both images.

- You will need the following calibration files:

    - `pollen_calibration_Z_vs_N.fig`
    - `pllen_calibration_x_y_offsets.fig`

Place these files in the same directory as your `caiman_output_plane_N` files.

.. code-block:: MATLAB

	>> help collatePlanes
  collatePlanes Analyzes and processes imaging data by extracting and correcting features across multiple planes.

  This function analyzes imaging data from a specified directory, applying
  various thresholds and corrections based on metadata. It processes neuron
  activity data, handles z-plane corrections, and outputs figures representing
  neuron distributions along with collated data files.

  The function expects the directory to contain 'caiman_output_plane_*.mat' files
  with variables related to neuronal activity, and uses provided metadata for
  processing parameters. It adjusts parameters dynamically based on the content
  of metadata and filters, merges data across imaging planes, and performs
  z-plane and field curvature corrections.

  Parameters
  ----------
  dataPath : string
      Path to the directory containing the data files for analysis.
  data : string (unused, placeholder for future use)
      Placeholder parameter for passing data directly if needed.
  metadata : struct
      Structure containing metadata for processing. Must include fields:
      r_thr, pixel_resolution, min_snr, frame_rate, fovx, and fovy.
  startDepth : double
      The starting depth (z0) from which processing should begin; if not
      provided, a dialog will prompt for input.

  Returns
  -------
  None

  Outputs
  -------
  - .fig files showing neuron distributions in z and radial directions.
  - A .mat file with collated and processed imaging data.

  Notes
  -----
  - Expects 'three_neuron_mean_offsets.mat' and 'pollen_calibration_Z_vs_N.fig'
    within the dataPath for processing.
  - The function uses parallel processing for some calculations to improve
    performance.

  Examples
  --------
  collatePlanes('C:/data/images/', '', struct('r_thr':0.4, 'pixel_resolution':2, 'min_snr':1.5, 'frame_rate':9.61, 'fovx':1200, 'fovy':1164), 100);
    This example processes data from 'C:/data/images/', starting at a depth of 100 microns,
    with specified metadata parameters.

  See also load, inputdlg, struct, fullfile, exist

The user will be prompted to select the same **feature** / **region-of-interest** / **neuron**:

.. image:: ./_static/_images/compare_planes.png
   :width: 200


After selecting 3 neurons for each plane, you are done with the LBM pipeline.
