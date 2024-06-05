# MAxiMuM CaImAn pipeline 

BRANCH - original pipeline

This is a copy of the original MAxiMuM processing pipeline (small updates since the paper by Jason), including some older/extra pieces of code. The core software is in: https://github.com/jmmanley/MAxiMuM_processing_tools

### Branches
- master: jasons modified version of jeffs pipeline
- benchmark_minimal: the minimum amount of code changes needed to get the code running. The pipeline still involves several intermittent steps, outlined in the readme for this branch.
- benchmark_full_pipeline: this is the first real change-up, splitting pre-processing into 2 distinct steps with additional ease-of-use improvements


# PROTOCOL FOR RUNNING PRE-PROCESSING AND CAIMAN SOURCE EXTRACTION ON LIGHT BEADS MICROSCOPY DATA

All code/software written by Jeffrey Demas: https://github.com/vazirilab/MAxiMuM_processing_tools

Jeff has a more extensive “in house” version of this code. Jason has a copy on Github: https://github.com/vazirilab/scaling_analysis/tree/main/caiman_pipeline

Jeff traditionally ran this code for his short datasets (~10 minutes) on the virtual machines. Here I will give a guide to processing longer datasets (1 hour) on the HPC cluster’s bigmem node.

1.	Due to the limited storage on the hpc scratch drives, it is important to copy raw data only when needed and remove it after processing. (As of 2023 RUIT has stopped enforcing storage size quotas, but we still need to beware this could happen at any time).
2.	Login to the hpc cluster using: `ssh USERNAME@login04-hpc.rockefeller.edu` (or `login03`). For transferring large amounts of data, there is a dedicated data transfer node: `dtn02-hpc.rockefeller.edu`. (I have found transfer speeds can be slower than the login node).
3.	In order to get back to your session after logging out of the hpc cluster, it is useful to use tmux, a terminal multiplexer tool. To start a new session: `tmux new-session -s NAME`, and to rejoin a session: `tmux attach -t NAME`.
4.	Request an interactive session on the bigmem node (unless processing a small dataset (e.g. <30 min.), in which case replace `bigmem` with `hpc`): `srun -p bigmem --time 0 --pty bash`.
5.	Start MATLAB. You must have a license to run MATLAB on the specific node you are utilizing. (Probably best to see if HPC admins can manage MATLAB licenses on cluster - may make life a lot easier)
6.	Navigate to the software folder.
7.	First, we need to run the pre-processing pipeline, which collates the planes and performs motion correction: `preProcessMAxiMuM(filePath, fileNameRoot, diagnosticFlag, numCores)`. All inputs should be strings. The output of this will be a set of files `filePath/TMP/*_plane_***.mat` containing the pre-processed and motion-corrected videos of each plane.
8.	Next, you can run the neuronal segmentation: `planarSegmentation(path, diagnosticFlag, startPlane, endPlane, numCores)`. This will save a .mat file containing the extracted neuronal traces for each plane individually.
9.	The planes can then be collated to merge duplicate neurons (here you need an interactive MATLAB window). First use `calculate_offset.m`, which requires the pollen calibration data `pollen_sample_xy_calibration.mat` and `pollen_calibration_z_vs_N.fig`. Then you can use `compare_planes_new.m` to perform the final collation (for 15x MAxiMuM, just change the for loop to go through 15 planes instead of 30).

New as of 2022ish: You can run a remote desktop on the cluster at `eureka.rockefeller.edu`. Start a “RU HPC Cluster” interactive session and then you have a standard remote desktop to work in!

