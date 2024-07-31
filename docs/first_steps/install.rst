0.1 Installation
################################

0.1.1. Download from Github
===============================

userpath
--------------

The easiest way to download the source code is to visit the `github repository <https://github.com/MillerBrainObservatory/LBM-CaImAn-MATLAB>`_, download the source code via the  <> Code button.

.. thumbnail:: ../_images/gh_download.png

and simply move/extract it into a folder on your :code:`userpath`.

.. note::

   To find your userpath, open matlab, and in the command window: :code:`userpath`

        ans =
            '/home/<username>/Documents/MATLAB'

This will automatically add all necessary files for this pipeline to your MATLAB path to be fully accessable.
You can tell if the pipeline is added successfully to the path by looking at the file window.

.. sidebar::

    .. image:: ../_images/gen_matlab_path_explorer.png
       :width: 200

Here, `/core` and `/packages` are both bright in the files window, this indicates those folders are properly in the MATLAB path.
These two folders contain all of the code the pipeline needs to run and are the only two folders that **must** be on the path.
If either of these folders is not bright, right-click on the folder and "Add to path -> Selected Folders and Subfolders"

Startup
--------------

You can create a `startup.m`_ file located in this same `userpath` directory: `~/Documents/MATLAB/startup.m` and add the following code snippet:

.. code-block:: MATLAB

   % <HOME>/Documents/MATLAB/startum.m
   % note "fullfile" isnt needed, but helpfully provides directory autocompletion
   addpath(genpath(fullfile("path/to/caiman_matlab")))

0.1.2. Install with git
==========================

Modern versions of matlab (2017+) solve most Linux/Windows filesystem conflicts. Installation is similar independent of OS.

Windows
--------------------------------------

The easiest method to download this repository with git is via `mysys <https://gitforwindows.org/>`_

.. note::

    If you have MATLAB installed on Windows, you won't be able to run commands from within WSL (i.e. //wsl.localhost/)
    due to the separate filesystems. Pay attention to which environment you install.

WSL2 (Windows Subsystem for Linux)
--------------------------------------

Windows subsystem for Linux (WSL/WSL2) is a local environment on your windows machine that is capable of running linux commands using a separate filesystem. As of 2024, Mathworks does not officially support and is not planning support for MATLAB on WSL or WSL2.
If you have MATLAB installed on Windows and wish to use this repository from a WSL instance, see `this discussion on how to accomplish this <https://ww2.mathworks.cn/matlabcentral/answers/1597219-can-microsoft-s-wslg-windows-subsystem-for-linux-gui-support-running-matlab>`_.
This means you will not be able to run matlab from the WSL filesystem (i.e. `//wsl.localhost/`), but you can use a mounted `C://` drive path like so:

.. code-block:: bash

   $ cd /mnt/c/Users/<Username>/<project-install-path>

This pipeline has been tested on WSL2, Ubuntu 22.04. Though any debian-based distribution should work.

Linux
-----------

In Linux, WSL or mysys, clone this repository with the pre-installed git client:

.. code-block:: bash

    $ cd ~/Documents/MATLAB
    $ git clone https://github.com/ru-rbo/caiman_matlab.git
    $ cd caiman_matlab
    $ matlab

.. _startup.m: https://www.mathworks.com/help/matlab/matlab_env/matlab-startup-folder.html
.. _GITHUB_: https://github.com/ru-rbo/rbo-lbm'_

