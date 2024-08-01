.. _params:

.. _parameters:

.. _parameter:

.. _argument:

.. _arguments:

0.2. Pipeline Usage
#######################

The bare-minimum to use this pipeline involves calling four functions which have sensible default values for LBM recordings.

The only _required_ input to the pipeline functions are a path where your data lives.

This common interface is described here with the goal of avoiding redundancy through the rest of the documentation.

0.2.1 Core Parameters
==========================

For the :ref:`Core <core_api>` functions in this pipeline, the initial parameters are always the same.

.. note::

    The term "parameter" and "argument" used throughout this guide refer to the inputs to each function, what goes inside the paranthesis ().
    Running "help convertScanImageTiffToVolume" in the command window will show to you and describe the parameters of that function.

    .. thumbnail:: ../_images/gen_param_v_arg.png


Required
----------------

The only required parameter is the data-path:

:code:`data_path`
: A filepath leading to the directory that contains the input files.

This can be given as an argument without specifying the 'name':

.. code-block:: MATLAB

    convertScanImageTiffToVolume("C:/Users/MBO/MATLAB/data/");

Optional
------------

The remaining parameters are optional:

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

Optional parameters must be given a name for the function to parse:

.. code-block:: MATLAB

    data_path = "C:/Users/MBO/MATLAB/data/";
    save_path = fullfile(data_path, "results"); % data_path/results

    convertScanImageTiffToVolume( ...
        data_path, ...  % required, parameter alone
        'save_path', save_path, ... % optional, include the name
        'ds','/Y', ... 
        'debug_flag', 1, ...
        'trim_pixels', [0 0 0 0], ... 
        'overwrite', 1, ...
        'fix_scan_phase', 0 ...
    );

See the included script :scpt:`demo_LBM_pipeline` at the root of this repository for a working example.

