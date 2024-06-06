Parameters
##########

For the :ref:`core` functions** in this pipeline, the initial parameters are always the same.

.. note::

    The term "parameter" throughout this guide refers to the inputs to each function.
    For example, running "help convertScanImageTiffToVolume" in the command window will
    show to you and describe the parameters of that function.

These parameters primarily pertain to saving files, which the primary storage format for this
pipeline is HDF5. Note you can save HDF5 files as `.h5` or `.hdf5`.

You can choose to save your data in a few different ways:

- All in the same file, as different groups '/raw', '/extracted'. !!NOT RECOMMENDED!!
- Each step is saved to a different file.
- Any combination of the two (first two steps in the same file, second step in a separate file).

.. important::

   Deleting or overwriting data with a different size are not operations permitted in the h5 standard. Overwriting a file
   will consist of deleting the entire group and starting fresh.

Definitions
================

:code:`data_path` : A filepath leading to the directory that contains your .tiff files.

:code:`save_path` : A filepath leading to the directory where results are saved.

:code:`data_input_group` : If the input path is h5, this is the group containing the data.

:code:`data_output_group` : If the output file is h5, this is the group name where the data will be saved.

:code:`debug_flag` : Set to 1 to print all files / datasets that would be processed, then stop before any processing occurs.

:code:`overwrite` : Set to 1 to overwrite pre-existing data. Setting to 0 will simply return without processing that file.

:code:`num_cores` : Set to the number of CPU cores to use for parallel computing. Note that even though this is an option in pre-processing, there is actually no parallel computations during this step so the value will be ignored.


The recommended method for saving data is to save each step in a separate HDF5 file and name the group after the step being executed.
This is demonstrated in the :scpt:`demo_LBM_pipeline` at the root of this repository.

For information about the parameters unique to each function, see the :ref:`api` or the help documentation for that individual function.

