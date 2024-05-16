.. _troubleshooting:

Troubleshooting
===============================

- Out of Memory during deserialization

  Sometimes during motion-correction, NormCorre will use more memory than it is supposed to. See <Issue Link>.
  If you're using all of the cores your computing environment has available, that is almost certainly the cause. Decrease
  the number of cores as the third input of :func:`motionCorrectPlane`. If this doesn't correct the issue, it is likely due to
  a single 3D-planar time-series being too large to fit in memory, in which case you can prevent caiman from processing the image patches
  in parallel. Keep in mind this will be noticably slower than the parallel counterpart.


Missing Compiled Binary (Windows)
---------------------------------

**Problem:** The `run_CNMF_patches` function errors out on Windows.

**Cause:** Missing compiled binary for `graph_conn_comp_mex.mexw64`.

**Solution:**
1. Compile the binary in MATLAB via the command window:

.. code-block:: MATLAB

   >> mex .\CaImAn_Utilities\CaImAn-MATLAB-master\CaImAn-MATLAB-master\utilities\graph_conn_comp_mex.cpp
   Building with 'MinGW64 Compiler (C++)'.
   MEX completed successfully.

Matlab Server Issues
--------------------

These come in many flavors and are mostly `windows` issues due to their backgroundn serrvice.

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

