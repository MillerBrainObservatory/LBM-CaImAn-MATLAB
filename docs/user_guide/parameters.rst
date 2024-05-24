.. _parameters:

Parametersh
##########

For the core functions you will be using in this pipeline, the initial parameters are always the same:

data_path: A filepath leading to the directory that contains your .tiff files.

The primary storage method for results obtained in this pipeline is HDF5. This means that you can choose to save your data in a few different ways:

- All in the same file, as different groups '/raw', '/extracted'. !!NOT RECOMMENDED!!
- Each step is saved to a different file.
- Any combination of the two (first two steps in the same file, second step in a separate file).

.. note::

   Deleting or overwriting data with a different size are not operations permitted in the h5 standard. Overwriting a file
   will consist of deleting the entire group and starting fresh.

The recommended method for saving data is to save each step in a separate HDF5 file and name the group after the step being executed. This is demonstrated in the
LBM_pipeline_demo.m file.

.. code-block:: MATLAB

   >> correctAssembledROITiff

