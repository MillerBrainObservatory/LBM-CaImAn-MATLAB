selector_to_html = {"a[href=\"tips_tricks.html#explore-data-matlab\"]": "<h2 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">5.1. </span>Exploring Datasets in MATLAB<a class=\"headerlink\" href=\"#exploring-datasets-in-matlab\" title=\"Permalink to this heading\">#</a></h2><p>There are several helper functions located in <code class=\"docutils literal notranslate\"><span class=\"pre\">core/utils</span></code>.</p>", "a[href=\"../first_steps/overview.html#parameters\"]": "<h2 class=\"tippy-header\" style=\"margin-top: 0;\">Core Parameters<a class=\"headerlink\" href=\"#core-parameters\" title=\"Permalink to this heading\">#</a></h2><p>For the <a class=\"reference internal\" href=\"../api/core.html#core-api\"><span class=\"std std-ref\">Core</span></a> functions in this pipeline, the initial parameters are always the same.</p>", "a[href=\"#assembly\"]": "<h1 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">1. </span>Assembly<a class=\"headerlink\" href=\"#assembly\" title=\"Permalink to this heading\">#</a></h1><p>Function for this step: <a class=\"reference internal\" href=\"../api/core.html#convertScanImageTiffToVolume\" title=\"convertScanImageTiffToVolume\"><code class=\"xref mat mat-func docutils literal notranslate\"><span class=\"pre\">convertScanImageTiffToVolume()</span></code></a></p>", "a[href=\"troubleshooting.html#troubleshooting\"]": "<h1 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">6. </span>Troubleshooting<a class=\"headerlink\" href=\"#troubleshooting\" title=\"Permalink to this heading\">#</a></h1><h2><span class=\"section-number\">6.1. </span>Memory<a class=\"headerlink\" href=\"#memory\" title=\"Permalink to this heading\">#</a></h2>", "a[href=\"../glossary.html#term-pixel-resolution\"]": "<dt id=\"term-pixel-resolution\">pixel-resolution</dt><dd><p>The length of each pixel, in micron (px/um).</p></dd>", "a[href=\"#trim-rois\"]": "<h3 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">1.2.2. </span>Trim ROIs<a class=\"headerlink\" href=\"#trim-rois\" title=\"Permalink to this heading\">#</a></h3><p>There are times when the seam between re-tiled ROI\u2019s is still present.</p><p>This seam may not appear when frames are viewed individually, but are present in the <a class=\"reference internal\" href=\"../image_gallery.html#ex-meanimage\"><span class=\"std std-ref\">mean image</span></a>.</p>", "a[href=\"#scan-phase\"]": "<h3 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">1.2.1. </span>Scan Phase<a class=\"headerlink\" href=\"#scan-phase\" title=\"Permalink to this heading\">#</a></h3><p>In addition to the standard parameters, users should be aware of the implications that bidirectional scan offset correction has on your dataset.</p><p>The <code class=\"code docutils literal notranslate\"><span class=\"pre\">fix_scan_phase</span></code> parameter attempts to maximize the phase-correlation between each line (row) of each vertically concatenated strip.</p>", "a[href=\"../first_steps/setup.html#directory-structure\"]": "<h2 class=\"tippy-header\" style=\"margin-top: 0;\">Directory Structure<a class=\"headerlink\" href=\"#directory-structure\" title=\"Permalink to this heading\">#</a></h2><p>The following is an example of the directory hierarchy\nused for the demo.</p>", "a[href=\"../image_gallery.html#ex-deinterleave\"]": "<figure class=\"align-default\" id=\"ex-deinterleave\">\n<img alt=\"ex_deinterleave\" src=\"../_images/ex_deinterleave.svg\"/></figure>", "a[href=\"../image_gallery.html#ex-retile\"]": "<figure class=\"align-default\" id=\"ex-retile\">\n<img alt=\"ex_retile\" src=\"../_images/ex_retile.svg\"/></figure>", "a[href=\"#overview\"]": "<h2 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">1.1. </span>Overview<a class=\"headerlink\" href=\"#overview\" title=\"Permalink to this heading\">#</a></h2><p>Assembling reconstructed images from raw LBM datasets consists of 3 main processing steps:</p>", "a[href=\"#validate-outputs\"]": "<h2 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">1.4. </span>Validate Outputs<a class=\"headerlink\" href=\"#validate-outputs\" title=\"Permalink to this heading\">#</a></h2><p>In your <code class=\"docutils literal notranslate\"><span class=\"pre\">save_path</span></code>, you will see a newly created <code class=\"docutils literal notranslate\"><span class=\"pre\">figures</span></code> folder:</p>", "a[href=\"#inputs\"]": "<h2 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">1.2. </span>Inputs<a class=\"headerlink\" href=\"#inputs\" title=\"Permalink to this heading\">#</a></h2><p>This example follows a directory structure shown in <a class=\"reference internal\" href=\"../first_steps/setup.html#directory-structure\"><span class=\"std std-ref\">the first steps guide</span></a>.</p><p>Inputs and outputs can be anywhere you wish so long as you have read/write permissions.</p>", "a[href=\"registration.html#normcorre-params\"]": "<h3 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">2.2.1. </span>NoRMCorre Parameters<a class=\"headerlink\" href=\"#normcorre-parameters\" title=\"Permalink to this heading\">#</a></h3><p>The last parameter for this step is a NoRMCorre parameters object.\nThis is just a <a class=\"reference external\" href=\"https://www.mathworks.com/help/matlab/ref/struct.html\">MATLAB structured array</a> that expects specific values.</p><p>NoRMCorre provides the algorithm for registration and dictates the values in that struct.</p>", "a[href=\"#outputs\"]": "<h2 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">1.3. </span>Outputs<a class=\"headerlink\" href=\"#outputs\" title=\"Permalink to this heading\">#</a></h2><p>Output data are saved in <code class=\"docutils literal notranslate\"><span class=\"pre\">.h5</span></code> format, with the following characteristics:</p>", "a[href=\"../image_gallery.html#ex-meanimage\"]": "<figure class=\"align-default\" id=\"ex-meanimage\">\n<a class=\"reference internal image-reference\" href=\"../_images/ex_meanimage.svg\"><img alt=\"ex_meanimage\" height=\"372\" src=\"../_images/ex_meanimage.svg\" width=\"456\"/></a>\n</figure>", "a[href=\"#h5-groups\"]": "<h3 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">1.3.1. </span>H5 Groups<a class=\"headerlink\" href=\"#h5-groups\" title=\"Permalink to this heading\">#</a></h3><p><a class=\"reference external\" href=\"https://www.neonscience.org/resources/learning-hub/tutorials/about-hdf5\">HDF5</a> is the primary file format for this pipeline. HDF5 relied on groups and attributes to save data to disk.</p>", "a[href=\"../image_gallery.html#ex-scanphase\"]": "<figure class=\"align-default\" id=\"ex-scanphase\">\n<a class=\"reference internal image-reference\" href=\"../_images/ex_scanphase.svg\"><img alt=\"ex_scanphase\" height=\"509\" src=\"../_images/ex_scanphase.svg\" width=\"336\"/></a>\n<figcaption>\n<p><span class=\"caption-text\">Scan-phase diagram</span><a class=\"headerlink\" href=\"#ex-scanphase\" title=\"Permalink to this image\">#</a></p>\n</figcaption>\n</figure>", "a[href=\"#trim-image\"]": "<h3 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">1.2.3. </span>Trim Image<a class=\"headerlink\" href=\"#trim-image\" title=\"Permalink to this heading\">#</a></h3><p>In the same manner as <a class=\"reference internal\" href=\"#trim-roi\"><span class=\"std std-ref\">trimming ROIs</span></a>, the <code class=\"docutils literal notranslate\"><span class=\"pre\">trim_image</span></code> parameter will trim the edges of the <a class=\"reference internal\" href=\"../image_gallery.html#ex-retile\"><span class=\"std std-ref\">retiled-image</span></a>.</p>", "a[href=\"#trim-roi\"]": "<h3 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">1.2.2. </span>Trim ROIs<a class=\"headerlink\" href=\"#trim-rois\" title=\"Permalink to this heading\">#</a></h3><p>There are times when the seam between re-tiled ROI\u2019s is still present.</p><p>This seam may not appear when frames are viewed individually, but are present in the <a class=\"reference internal\" href=\"../image_gallery.html#ex-meanimage\"><span class=\"std std-ref\">mean image</span></a>.</p>", "a[href=\"../api/utility.html#read_h5_metadata\"]": "<dt class=\"sig sig-object mat\" id=\"read_h5_metadata\">\n<span class=\"sig-name descname\"><span class=\"pre\">read_h5_metadata</span></span><span class=\"sig-paren\">(</span><em class=\"sig-param\"><span class=\"pre\">h5_fullfile</span></em>, <em class=\"sig-param\"><span class=\"pre\">loc</span></em><span class=\"sig-paren\">)</span></dt><dd><p>Reads metadata from an HDF5 file.</p><p>Reads the metadata attributes from a specified location within an HDF5 file\nand returns them as a structured array.</p><p class=\"rubric\">Notes</p><p>The function uses <cite>h5info</cite> to retrieve information about the specified location\nwithin the HDF5 file and <cite>h5readatt</cite> to read attribute values. The attribute names\nare converted to valid MATLAB field names using <cite>matlab.lang.makeValidName</cite>.</p><p class=\"rubric\">Examples</p></dd>", "a[href=\"../first_steps/overview.html#ds\"]": "<p id=\"ds\"><code class=\"code docutils literal notranslate\"><span class=\"pre\">ds</span></code>\n: Dataset name/group path, a character or string (\u2019\u2019 or \u201c\u201d) array beginning with a foreward slash \u2018\u2019. For example, \u2018/Y\u2019, \u201c/mov\u201d, \u2018/raw\u2019.</p>", "a[href=\"../api/core.html#convertScanImageTiffToVolume\"]": "<dt class=\"sig sig-object mat\" id=\"convertScanImageTiffToVolume\">\n<span class=\"sig-name descname\"><span class=\"pre\">convertScanImageTiffToVolume</span></span><span class=\"sig-paren\">(</span><em class=\"sig-param\"><span class=\"pre\">data_path</span></em>, <em class=\"sig-param\"><span class=\"pre\">varargin</span></em><span class=\"sig-paren\">)</span></dt><dd><p>Convert ScanImage .tif files into a 4D volume.</p><p>Convert raw scanimage multi-roi .tif files from a single session\ninto a single 4D volumetric time-series (x, y, z, t). It\u2019s designed to process files for the\nScanImage Version: 2016 software.</p></dd>"}
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