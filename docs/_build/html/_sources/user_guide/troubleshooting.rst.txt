
Troubleshooting Common Problems
===============================

MATLAB Path Issues
------------------

**Problem:** The `run_CNMF_patches` function errors out.

**Cause:** The CaImAn parent folder containing `run_CNMF_patches` is not on the MATLAB path.

**Solution:**
1. Check the MATLAB path configuration in the `planarSegmentation` script, around line 150:

   ```matlab
   % give access to CaImAn files
   addpath(genpath(fullfile('CaImAn-MATLAB-master','CaImAn-MATLAB-master')))
   addpath(genpath(fullfile('motion_correction/')))
   ```

   This code adds paths relative to the current directory, which may fail if the `CaImAn-MATLAB-master` folder is not in the same directory as your MATLAB interpreter.

2. Move the `CaImAn-MATLAB-master` folder to your userpath, typically `~/Documents/MATLAB/`. You can find this path by typing `userpath` in the MATLAB command window and placing the `CaImAn` folder there.

3. Alternatively, you can modify the `planarSegmentation` script to use an absolute path:

   ```matlab
   % give access to CaImAn files
   [currpath, ~, ~] = fileparts(fullfile(mfilename('fullpath'))); % grabs absolute path to this script
   addpath(genpath(fullfile(currpath, '../CaImAn-MATLAB-master/CaImAn-MATLAB-master')));
   ```

Missing Compiled Binary (Windows)
---------------------------------

**Problem:** The `run_CNMF_patches` function errors out on Windows.

**Cause:** Missing compiled binary for `graph_conn_comp_mex.mexw64`.

**Solution:**
1. Compile the binary in MATLAB via the command window:

   ```matlab
   >> mex .\CaImAn_Utilities\CaImAn-MATLAB-master\CaImAn-MATLAB-master\utilities\graph_conn_comp_mex.cpp
   Building with 'MinGW64 Compiler (C++)'.
   MEX completed successfully.
   ```

Less-Likely Issues
------------------

**Problem:** The `run_CNMF_patches` function still fails after addressing the common issues.

**Solution:** 
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

If these solutions do not resolve the issue, please reach out for further assistance or schedule a Zoom call for additional troubleshooting.
