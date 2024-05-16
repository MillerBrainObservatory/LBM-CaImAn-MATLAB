
###############
Tips and Tricks
###############

.. _help_functions:

Learn about Functions
---------------------

| Run 'help <function>' in the command window for a detailed overview on function parameters, outputs and examples.

.. code-block:: MATLAB

   >> help convertScanImageTiffToVolume
     convertScanImageTiffToVolume Convert ScanImage .tif files into a 4D volume.

      Convert raw `ScanImage`_ multi-roi .tif files from a single session
      into a single 4D volume (x, y, z, t). It's designed to process files for the
      ScanImage Version: 2016 software.

      Parameters
      ----------
      filePath : char
          The directory containing the raw .tif files. Only raw .tif files from one
          session should be in the directory.
      saveDirPath : char, optional
          The directory where processed files will be saved. It is created if it does
          not exist. Defaults to the filePath if not provided.
      diagnosticFlag : double, logical, optional
          If set to 1, the function displays the files in the command window and does
          not continue processing. Defaults to 0.

      Notes
      -----
      The function adds necessary paths for ScanImage utilities and processes each .tif
      file found in the specified directory. It checks if the directory exists, handles
      multiple or single file scenarios, and can optionally report the directory's contents
      based on the diagnosticFlag.

      Each file processed is logged, assembled into a 4D volume, and saved in a specified
      directory as a .mat file with accompanying metadata. The function also manages errors
      by cleaning up and providing detailed error messages if something goes wrong during
      processing.

      Examples
      --------
      .. code-block:: MATLAB

            % Path to data, path to save data, diagnostic flag
            convertScanImageTiffToVolume('C:/data/session1/', 'C:/processed/', 0);
            convertScanImageTiffToVolume('C:/data/session1/', 'C:/processed/', 1); % just display files

      See also fileparts, addpath, genpath, isfolder, dir, fullfile, error, regexp, savefast


