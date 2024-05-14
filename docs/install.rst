.. _installation:

Installation
============

.. _recommended-install:

Recommendation
--------------

The most reliable installation method is to clone/download the repository and add the path
                to a `startup.m`_ file located in `~/Documents/MATLAB/startup.m`.

.. code-block:: MATLAB

   % <HOME>/Documents/MATLAB/startum.m
   % note "fullfile" isnt needed, but helpfully provides directory autocompletion
   addpath(genpath(fullfile("path/to/this/caiman_matlab")))

Modern versions of matlab (2017+) solve most Linux/Windows filesystem conflicts. Installation is
similar independent of OS.

.. note::

    If you have MATLAB installed on Windows, you won't be able to run commands from within WSL (i.e. //wsl.localhost/)
    due to the separate filesystems. Pay attention to which environment you install.

.. _windows:

Windows
-------

The easiest method to download this repository with git is via `mysys <https://gitforwindows.org/>`_
Or just download the code from code/Download.zip above and unzip to a directory of your choosing.

.. _wsl:

WSL2 (Windows Subsystem for Linux)
----------------------------------

If you have MATLAB installed on Windows and wish to use this repository from a WSL instance, see `this`_ discussion.
WSL2 is helpful for access to unix tools, in such cases you should keep the repository on the Windows `C:// drive`, and access via:

.. code-block:: bash

   $ cd /mnt/c/Users/<Username>/<project-install-path>

This pipeline has been tested on WSL2, Ubuntu 22.04. Though any debian-based distribution should work.

For unix environments:

.. code-block:: bash

    $ cd ~/Documents/MATLAB
    $ git clone https://github.com/ru-rbo/caiman_matlab.git
    $ cd caiman_matlab
    $ matlab

.. _unix:

Unix (Linux/Mac)
----------------

The location of the installation is often in `~/Documents/MATLAB/`.
If you put the root directory elsewhere, you will need to navigate to that directory within the matlab GUI.

