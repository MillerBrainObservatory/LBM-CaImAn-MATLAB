
# About
This folder contains pre-build static libraries for different supported 
platforms.  The code for the mex functions depends on these libraries.

The `CMakeLists.txt` file in this directory is used as a registry for the
specific builds.  It just consists of (`add_subdirectory()`)[1] calls.

Inside the folder for each build is another `CMakeLists.txt` that defines
an (imported target)[2].  This may need to be customized for different builds.
Each is responsible for detecting the platform where it should be used.

# Updating

When adding or upgrading a build, use the following recipe:

    1. Copy in the new build folder.
    2. Copy the most relevant `CMakeLists.txt` to that new folder.
    3. Modify it as necessary.
    4. Modify `external/CMakeLists.txt` to refer to the new folder and remove
       references to outdated builds.
    5. Clean the `external` folder of any outdated builds.


[1]: https://cmake.org/cmake/help/latest/command/add_subdirectory.html
[2]: https://cmake.org/cmake/help/latest/manual/cmake-buildsystem.7.html?highlight=imported#imported-targets
