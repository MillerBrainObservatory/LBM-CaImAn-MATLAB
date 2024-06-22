add_subdirectory(ScanImageTiffReader-1.3-win64)
add_subdirectory(ScanImageTiffReader-1.3-Darwin)
add_subdirectory(ScanImageTiffReader-1.3-Linux)

#
# UTILITY FUNCTION
#

function(target_add_scanimage_tiff_reader tgt)    
    target_link_libraries(${tgt} ScanImageTiffReaderAPIStatic)
endfunction() 