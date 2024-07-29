
ScanImage Metadata
##################

As discussed in :ref:`pre-processing`, reconstructing an image from the ScanImage `.tiff` file is handled internally by the pipeline.
This describes the metadata that hold all of the values used for that process.


The funcion :func:`get_metadata` takes as input a path to any `ScanImage`_ tiff file and extracts all of the critical information used for calculations,
returning to you a set of `key-value pairs <https://stackoverflow.com/questions/25955749/what-is-a-key-value-pair>`_ containing the metadata name and the value.


.. code-block:: MATLAB

   >> get_metadata(fullfile(extract_path, "MH184_both_6mm_FOV_150_600um_depth_410mW_9min_no_stimuli_00001_00001.tiff"))

    ans =

      metadata contents:
             tiff_length = 2478
             tiff_width = 145
             roi_width_px = 144
             roi_height_px = 600
             num_rois = 4
             num_frames = 1730
             num_planes = 30A  % stored as scanimage channels
             num_files = 1
             frame_rate = 9.60806
             fov = [600;600]
             pixel_resolution = 1.02083
             sample_format = int16
             raw_filename = high_res
             raw_filepath = C:\Users\RBO\caiman_data
             raw_fullfile = C:\Users\RBO\caiman_data\high_res.tif
             dataset_name = /Y
             trim_pixels = [6;6;17;0]
             % below used internally
             num_pixel_xy = [144;600]
             center_xy = [-1.428571429;0]
             line_period = 4.15652e-05
             scan_frame_period = 0.104079
             size_xy = [0.9523809524;3.80952381]
             objective_resolution = 157.5
             num_lines_between_scanfields = 24

Image Size
************

ScanImage multi-ROI .tiff outputs are made up of individual sections called that ScanImage calls `ROIs`. These `ROIs` collectively form a
ScanImage `ScanField`. 

Image Frames
***************

During aquisition, the user is prompted to split the recorded frames across multiple .tiff files.
It doesn't matter which .tiff file is used for this function, the metadata used applies to each file.

.. thumbnail:: ../_images/si-data-log-gui.png
    :width: 800
    :title: ScanImage Frame Log
    :align: center

.. _ScanImage: https://www.mbfbioscience.com/products/scanimage/
.. _BigTiffSpec: _https://docs.scanimage.org/Appendix/ScanImage%2BBigTiff%2BSpecification.html#scanimage-bigtiff-specification
.. _MROI: https://docs.scanimage.org/Premium%2BFeatures/Multiple%2BRegion%2Bof%2BInterest%2B%28MROI%29.html#multiple-region-of-interest-mroi-imaging/
