
Tips and Tricks
###############

.. _help_functions:

Learn about Functions
============================

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

MATLAB and Python
============================

Transitioning data pipelines between MATLAB and Python can be tricky. The two primary reasons for this are the indexing and row/column major array operations.

Indexing
*************************************

In modern-day computer science, most programming languages such as Python, Ruby, PHP, and Java have array indices starting at zero.
A big reason for this is that it provides a clear distinction that ordinal forms (e.g. first, second, third) has a well-established meaning that the zeroth derivative of a function.

Matlab, like Julia, was created for scientific computing tailored to beginners and thus adopted the more intuitive 1 based indexing.

Row/Column Operations
*************************************

In terms of practically transfering data between programming languages, 0 or 1 based indexing can be managed by single `enumerating <https://stackoverflow.com/a/7233597/12953787>`_ for loops.

Number of Cores/Workers
*************************************

By default, Matlab creates as many workers as logical CPU cores. On Intel CPUs, the OS reports two logical cores per each physical core due to hyper-threading, for a total of 4 workers on a dual-core machine. However, in many situations, hyperthreading does not improve the performance of a program and may even degrade it (I deliberately wish to avoid the heated debate over this: you can find endless discussions about it online and decide for yourself). Coupled with the non-negligible overhead of starting, coordinating and communicating with twice as many Matlab instances (workers are headless [=GUI-less] Matlab processes after all), we reach a conclusion that it may actually be better in many cases to use only as many workers as physical (not logical) cores.
I know the documentation and configuration panel seem to imply that parpool uses the number of physical cores by default, but in my tests I have seen otherwise (namely, logical cores). Maybe this is system-dependent, and maybe there is a switch somewhere that controls this, I don’t know. I just know that in many cases I found it beneficial to reduce the number of workers to the actual number of physical cores:

.. code-block:: MATLAB

    p = parpool;     % NOT RECOMMENDED, CaImAn will very likely run out of resources error
    p = parpool(2);  % use only 2 parallel workers

This can vary greatly across programs and platforms, so you should first ensure the pipeline will run using <1/2 available cores before increasing the compute demands.
It would of course be better to dynamically retrieve the number of physical cores, rather than hard-coding a constant value (number of workers) into our program.

We can get this value in Matlab using the undocumented feature(‘numcores’) function:

.. code-block:: MATLAB

    numCores = feature('numcores');
    p = parpool(numCores);

Running :code:`feature(‘numcores’)` without assigning its output displays some general debugging information:

.. code-block:: MATLAB

    >> feature('numcores')
    MATLAB detected: 24 physical cores.
    MATLAB detected: 32 logical cores.
    MATLAB was assigned: 32 logical cores by the OS.
    MATLAB is using: 24 logical cores.
    MATLAB is not using all logical cores because hyper-threading is enabled.

    ans =

        24

You can use this return value to decide how how much of your computers total processing power should be dedicated toward running this pipeline:

.. code-block:: MATLAB

    >> feature('numcores') - 2 % leave 2 cores open for the rest of the system

    ans =

        23

This is equally valid for parfor/eval loops and spmd blocks, since both of them use the pool of workers started by parpool.

ImageJ
=============

ScanImage stores our light beads as `Channels`, typically in sets of 3 for red, blue and green. Loading the image in ImageJ
you will see a `[1 x 1 x zT]`.

De-Interleave zT
***********************

Open your file:

- File > Open > `select .tiff file`
- Open as Hyperstacks, with `split channels` and `virtual Hyperstacks` options enabled
- Image > Stacks > Tools > Stack Splitter
- Number of Substacks: [enter the number of z-planes, 30 here]

This will give you num_plane separate [Y, X, T] stacks.

.. code-block:: JavaScript

    ImageJ Metadata:

    BitsPerPixel	16
    DimensionOrder	XYCZT
    IsInterleaved	false
    IsRGB	false
    LittleEndian	true
    PixelType	`int16`
    Series 0 Name	MH70_0p6mm_FOV_50_550um_depth_som_stim_199mW_3min_M1_00001_00001.tif
    SizeC	1
    SizeT	51900 (should be 1730)
    SizeX	145
    SizeY	2478
    SizeZ	1     (should be 30)

Concatenate
**************

To turn the vertically concatenated image into a horizontally concatenated image:

1) TODO
