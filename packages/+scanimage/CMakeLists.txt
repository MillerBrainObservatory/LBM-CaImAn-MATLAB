cmake_minimum_required(VERSION 3.7)
project(scanimagetiffreader-matlab)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED TRUE)

include(cmake/git-versioning.cmake)
include(cmake/install-prefix.cmake)
include(cmake/static-runtime.cmake)
include(cmake/hide-symbols.cmake)

add_subdirectory(external)
add_subdirectory(src)

include(CPack) # enable packaging
