Troubleshooting
===============

Memory
***************************************

- Number of Workers/Cores > 100: There a a known bug in MATLAB R2023a for cases when the number of workers is more than 100.
  Refer to the following `bug report <https://www.mathworks.com/support/bugreports/details/2968710.html>`_ for a workaround to resolve the issue. Additionally, steps taken in :ref:`matlab server issues` can help to solve this problem.

- Out of Memory during deserialization

  Sometimes during motion-correction, NormCorre will use more memory than it is supposed to. See <Issue Link>.
  If you're using all of the cores your computing environment has available, that is almost certainly the cause. Decrease
  the number of cores as the third input of :func:`motionCorrectPlane`. If this doesn't correct the issue, it is likely due to
  a single 3D-planar time-series being too large to fit in memory, in which case you can prevent caiman from processing the image patches
  in parallel. Keep in mind this will be noticably slower than the parallel counterpart.


Missing Compiled Binary (Windows)
***************************************

- Typically seen as: `run_CNMF_patches` function errors out on Windows.

**Cause:** Likely caused by missing compiled binary for `graph_conn_comp_mex.mexw64 (win)`/ `graph_conn_comp_mex.mexa64 (unix)`

**Solution:**
1. Compile the binary in MATLAB via the command window:

.. code-block:: MATLAB

   >> mex .\CaImAn_Utilities\CaImAn-MATLAB-master\CaImAn-MATLAB-master\utilities\graph_conn_comp_mex.cpp
   Building with 'MinGW64 Compiler (C++)'.
   MEX completed successfully.

.. note::

   Newest version 0.2.0+ include both precompiled binaries.

Matlab Server Issues
***********************
.. _server_issues:

These come in many flavors and are mostly `windows` issues due to their background serrvice.

Here is the general fix for all of them:

1. Task Manager:
- End all MATLAB-related tasks.
2. Check MATLAB License:
- Run `license checkout Distrib_Computing_Toolbox`.
- If `Ans=1`, the license is valid.
3. Revert Local Profile:
- Create a new profile in the cluster manager, set it as default, and delete 'Processes'.
4. Replace Local Cluster Storage:
- Find `prefdir` using `>> prefdir` (e.g., `C:\Users\%username%\AppData\Roaming\MathWorks\MATLAB\R202x`).
- Delete the `MATLAB\local_cluster_jobs` directory one level up.
5. Check for Potentially Conflicting Files:
- Run `which -all startup.m`. If not found, it's not the issue.
- Run `which -all pathdef.m`. Ensure it's located in `C:\Program Files\MATLAB\R2023b\toolbox\local\pathdef.m`.
- Run `which -all matlabrc.m`. Ensure it's located in `C:\Program Files\MATLAB\R2023b\toolbox\local\matlabrc.m`.


Windows Filepaths
***********************

Sometimes Windows filepaths, with the \ backslash, is taken as an escape character rather than a file-path separator:

.. code-block:: MATLAB

    Warning: Escaped character '\U' is not valid. See 'doc sprintf' for supported special characters.
    Error using h5infoc
    Unable to open 'C:'. File or folder not found.

To resolve this, replace `\` with `/`, or use :code:`fullfile()` to build the path:


.. code-block:: MATLAB

    data_path = fullfile("C:\Users\");

