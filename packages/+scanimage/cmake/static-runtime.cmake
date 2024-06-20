# Copyright (c) 2017 Vidrio Technologies, All Rights Reserved
# Author: Nathan Clack <nathan@vidriotech.com>

# from: https://stackoverflow.com/questions/14172856/cmake-compile-with-mt-instead-of-md
set(CompilerFlags
    CMAKE_CXX_FLAGS
    CMAKE_CXX_FLAGS_DEBUG
    CMAKE_CXX_FLAGS_RELEASE
    CMAKE_CXX_FLAGS_MINSIZEREL
    CMAKE_CXX_FLAGS_RELWITHDEBINFO
    CMAKE_C_FLAGS
    CMAKE_C_FLAGS_DEBUG
    CMAKE_C_FLAGS_RELEASE
    CMAKE_C_FLAGS_MINSIZEREL
    CMAKE_C_FLAGS_RELWITHDEBINFO
)

# Reliably finding a dynamic runtime seems to only be a problem
# on windows.  So we statically link it.  It is a very simple
# problem to solve on windows.
if(WIN32)
    foreach(CompilerFlag ${CompilerFlags})
        string(REPLACE "/MD" "/MT" ${CompilerFlag} ${${CompilerFlag}})
        set(${CompilerFlag} "${${CompilerFlag}}" CACHE STRING "" FORCE)
    endforeach()
else()
    set(CMAKE_MODULE_LINKER_FLAGS -static-libstdc++ CACHE STRING "" FORCE)
endif()
