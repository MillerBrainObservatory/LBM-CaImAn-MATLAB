.. _troubleshooting:

###############
Troubleshooting
###############

This document goes over some common errors one may encounter through the various pipeline steps.

Errors
======

| Error in function run_CNMF_patches() at line 123. Error Message: The function evaluation completed with an error.

Errors that occur when a parpool object is instantiated, as is the case here due to run_CNMF_patches processing each
patch in parallel, obfuscate the error message as "something bad happened". Not ideal. We can first address the easy fixes.

This typically occurs when the CaImAn function :code:`run_CNMF_patches()` calls a function not on the MATLAB path, but can also occur if you don't have the correct MEX binary installed.

Fix 1) Ensure the `CaImAn_Utilites` folder, or generally the entire `packages/` folder, is on the MATLAB path.
Fix 2) Turn off any parallel processing and call run_CNMF_patches on a bare array object so that you get a more descriptive error message.

