if(EXISTS "$ENV{Matlab_ROOT_DIR}")
    # explicitly setting the root dir via environment variable
    # Since I'm forcing the root here, don't worry about version checks.
    message(STATUS "Using Matlab_ROOT_DIR environment variable")
    set(Matlab_ROOT_DIR $ENV{Matlab_ROOT_DIR} CACHE FILEPATH "Set by environment variable" FORCE)
    find_package(Matlab COMPONENTS MX_LIBRARY)
else()
    # Force a particular version of matlab to build against.
    # This will determine our backward compatibility profile.
    # Build agent should set MATLAB_ROOT_DIR to make sure a particular MCR is found.
    find_package(Matlab 9.1 REQUIRED COMPONENTS MX_LIBRARY)
endif()
if(NOT MATLAB_FOUND)
    message(STATUS "Matlab not found.  The Matlab interface will not be built.")
    return()
endif()

foreach(tgt
    mexScanImageTiffOpen
    mexScanImageTiffClose
    mexScanImageTiffData
    mexScanImageTiffImageDescriptions
    mexScanImageTiffMetadata
    mexScanImageTiffReaderAPIVersion)

    matlab_add_mex(NAME ${tgt} MODULE SRC "${CMAKE_CURRENT_LISTS_DIR}${tgt}.c")
    target_add_scanimage_tiff_reader(${tgt})
    set_target_properties(${tgt} PROPERTIES LINKER_LANGUAGE CXX)
    install(TARGETS ${tgt}
            DESTINATION +ScanImageTiffReader/private
            COMPONENT matlab
          )
endforeach()

install(FILES
        ScanImageTiffReader.m
        ScanImageTiffReaderTests.m
        Contents.m
        index.m # This needs to be here so publish will work properly
        DESTINATION +ScanImageTiffReader
        COMPONENT matlab
      )
