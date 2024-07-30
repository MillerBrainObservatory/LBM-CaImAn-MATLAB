
Parameters
###################

For the :ref:`Core` functions in this pipeline, the initial parameters are always the same.

.. _params:

.. _argument:

.. _arguments:

.. note::

    The term "parameter" and "argument" throughout this guide refers to the inputs to each function, what goes inside the paranthesis ().
    For example, running "help convertScanImageTiffToVolume" in the command window will
    show to you and describe the parameters of that function. The terms are used interchangably.

    .. thumbnail:: ../_images/gen_param_v_arg.png

Parameter Descriptions
==========================

:code:`data_path`
: A filepath leading to the directory that contains the input files.

:code:`save_path` :
A filepath leading to the directory where any results are saved.

:code:`ds` :
Dataset name/group path, a character or string ('' or "") array beginning with a foreward slash '\'. For example, '/Y', "/mov", '/raw'.

:code:`debug_flag` :
This is how you can skip a step in the pipeline. Set to 1 to print all files / datasets that would be processed, then stop before any processing occurs.

:code:`overwrite` :
Set to 1 to overwrite or delete pre-existing data. Setting to 0 will simply return without processing that file.

:code:`num_cores` :
Set to the number of CPU cores to use for parallel computing.

.. note::

    Though :code:`num_cores` is an option in pre-processing, there is actually no parallel computations during this step so the value will be ignored.

The recommended method for saving data is to save each step in a separate HDF5 file and name the group after the step being executed.
This is demonstrated in the :scpt:`demo_LBM_pipeline` at the root of this repository.

For information about the parameters unique to each function, see the :ref:`Core` API or the help documentation for that individual function.

