selector_to_html = {"a[href=\"#is_valid_dataset\"]": "<dt class=\"sig sig-object mat\" id=\"is_valid_dataset\">\n<span class=\"sig-name descname\"><span class=\"pre\">is_valid_dataset</span></span><span class=\"sig-paren\">(</span><em class=\"sig-param\"><span class=\"pre\">filename</span></em>, <em class=\"sig-param\"><span class=\"pre\">location</span></em>, <em class=\"sig-param\"><span class=\"pre\">num_samples</span></em><span class=\"sig-paren\">)</span></dt><dd><p>Check if the HDF5 dataset contains valid data.</p><p>Query random indexes of dataset to ensure it contains valid data.</p><p class=\"rubric\">Notes</p><p>The function checks if the dataset has at least 2 rows and 2 columns.\nIt then randomly samples data from the dataset to check for non-zero values.\nIf any sample contains a non-zero value, the dataset is considered valid.\nCatches any errors during the process and returns false if an error occurs.</p></dd>", "a[href=\"#is_valid_group\"]": "<dt class=\"sig sig-object mat\" id=\"is_valid_group\">\n<span class=\"sig-name descname\"><span class=\"pre\">is_valid_group</span></span><span class=\"sig-paren\">(</span><em class=\"sig-param\"><span class=\"pre\">x</span></em><span class=\"sig-paren\">)</span></dt><dd></dd>", "a[href=\"#log_struct\"]": "<dt class=\"sig sig-object mat\" id=\"log_struct\">\n<span class=\"sig-name descname\"><span class=\"pre\">log_struct</span></span><span class=\"sig-paren\">(</span><em class=\"sig-param\"><span class=\"pre\">fid</span></em>, <em class=\"sig-param\"><span class=\"pre\">in_struct</span></em>, <em class=\"sig-param\"><span class=\"pre\">struct_name</span></em>, <em class=\"sig-param\"><span class=\"pre\">log_full_path</span></em><span class=\"sig-paren\">)</span></dt><dd><p>log_struct Log the contents of a structure to a log file and the command window.</p></dd>", "a[href=\"#log_message\"]": "<dt class=\"sig sig-object mat\" id=\"log_message\">\n<span class=\"sig-name descname\"><span class=\"pre\">log_message</span></span><span class=\"sig-paren\">(</span><em class=\"sig-param\"><span class=\"pre\">fid</span></em>, <em class=\"sig-param\"><span class=\"pre\">msg</span></em>, <em class=\"sig-param\"><span class=\"pre\">varargin</span></em><span class=\"sig-paren\">)</span></dt><dd><p>log_message Log a message to both a file and the command window.</p></dd>", "a[href=\"#write_metadata_h5\"]": "<dt class=\"sig sig-object mat\" id=\"write_metadata_h5\">\n<span class=\"sig-name descname\"><span class=\"pre\">write_metadata_h5</span></span><span class=\"sig-paren\">(</span><em class=\"sig-param\"><span class=\"pre\">metadata</span></em>, <em class=\"sig-param\"><span class=\"pre\">h5_fullfile</span></em>, <em class=\"sig-param\"><span class=\"pre\">loc</span></em><span class=\"sig-paren\">)</span></dt><dd><p>Write scanimage metadata fields to HDF5\nattributes, taking care of flattening structured arrays to their\nkey:value pairs.</p><p class=\"rubric\">Notes</p><p>This function handles nested structures by flattening the fields and\nconverting them into a format that is compatible with HDF5 attributes.</p><p class=\"rubric\">Examples</p><p>metadata = struct(\u2018name\u2019, \u2018LBM_guru\u2019, \u2018age\u2019, \u2018young_enough\u2019);\nh5_fullfile = \u2018guru.h5\u2019;\nloc = \u2018/young_guru\u2019;\nwrite_metadata_h5(metadata, h5_fullfile, loc);</p></dd>", "a[href=\"#internals\"]": "<h1 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">3. </span>Internals<a class=\"headerlink\" href=\"#internals\" title=\"Permalink to this heading\">#</a></h1><p>Functions that are meant for use within the pipeline, not for public use.</p>"}
skip_classes = ["headerlink", "sd-stretched-link"]

window.onload = function () {
    for (const [select, tip_html] of Object.entries(selector_to_html)) {
        const links = document.querySelectorAll(` ${select}`);
        for (const link of links) {
            if (skip_classes.some(c => link.classList.contains(c))) {
                continue;
            }

            tippy(link, {
                content: tip_html,
                allowHTML: true,
                arrow: true,
                placement: 'auto-start', maxWidth: 500, interactive: false,

            });
        };
    };
    console.log("tippy tips loaded!");
};
