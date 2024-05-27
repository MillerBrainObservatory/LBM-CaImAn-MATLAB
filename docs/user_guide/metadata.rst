.. _metadata:

ScanImage Metadata
##################

As discussed in :ref:`pre-processing`, reconstructing an image from the ScanImage `.tiff` file is handled internally by the pipeline.
This describes the metadata that hold all of the values used for that process.

The funcion :func:`get_metadata` takes as input a path to any `ScanImage`_ tiff file and returns the metadata.

.. note::

    During aquisition, the user is prompted to split the recorded frames across multiple .tiff files.
    It doesn't matter which .tiff file is used for this function, the metadata used applies to each file.

.. _metadata_code:

.. code-block:: MATLAB

   >> get_metadata(fullfile(extract_path, "MH184_both_6mm_FOV_150_600um_depth_410mW_9min_no_stimuli_00001_00001.tiff"))

    ans =

      struct with fields:

                objective_resolution: 157.5000
                           center_xy: [-15.2381 0]
                             size_xy: [3.8095 38.0952]
                        num_pixel_xy: [144 1200]
                        %%
                        image_length: 11008
                         image_width: 145
        num_lines_between_scanfields: 24
                     lines_per_frame: 144
                     pixels_per_line: 128
                          num_planes: 30
                            num_rois: 9
                    num_frames_total: 1176
                     num_frames_file: 392
                           num_files: 3
                          frame_rate: 2.1797
                                 fov: [600 6000]
                    pixel_resolution: 4.5833
                       sample_format: 'int16'
                       base_filename: "MH184_both_6mm_FOV_150_600um_depth_410mW_9min_no_stimuli_00001_00001"
                       base_filepath: "C:/<username>/Documents/data/raw/"




.. _ScanImage: https://www.mbfbioscience.com/products/scanimage/
.. _BigTiffSpec: _https://docs.scanimage.org/Appendix/ScanImage%2BBigTiff%2BSpecification.html#scanimage-bigtiff-specification
