selector_to_html = {"a[href=\"#inputs\"]": "<h2 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">4.1. </span>Inputs<a class=\"headerlink\" href=\"#inputs\" title=\"Permalink to this heading\">#</a></h2><p>First, the [Y, X] offsets (in microns) are used for an initial, dirty axial alignment:</p>", "a[href=\"#outputs\"]": "<h2 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">4.2. </span>Outputs<a class=\"headerlink\" href=\"#outputs\" title=\"Permalink to this heading\">#</a></h2><p>This output file mirrors the registration output but with all z-planes collated into a single dataset.</p>", "a[href=\"../api/core.html#collatePlanes\"]": "<dt class=\"sig sig-object mat\" id=\"collatePlanes\">\n<span class=\"sig-name descname\"><span class=\"pre\">collatePlanes</span></span><span class=\"sig-paren\">(</span><em class=\"sig-param\"><span class=\"pre\">data_path</span></em>, <em class=\"sig-param\"><span class=\"pre\">varargin</span></em><span class=\"sig-paren\">)</span></dt><dd><p>Parameters\n:param data_path: Path to the directory containing the files assembled via convertScanImageTiffToVolume.\n:type data_path: char\n:param save_path: Path to the directory to save the motion vectors.\n:type save_path: char\n:param ds: Group path within the hdf5 file that contains raw data.\n:type ds: string, optional\n:param debug_flag: If set to 1, the function displays the files in the command window and does</p></dd>", "a[href=\"#axial-collation-and-correction\"]": "<h1 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">4. </span>Axial Collation and Correction<a class=\"headerlink\" href=\"#axial-collation-and-correction\" title=\"Permalink to this heading\">#</a></h1><p>Use pollen calibration data to spatially align each z-plane and merge across planes.</p><p>Core function(s): <a class=\"reference internal\" href=\"../api/core.html#collatePlanes\" title=\"collatePlanes\"><code class=\"xref mat mat-func docutils literal notranslate\"><span class=\"pre\">collatePlanes()</span></code></a></p>"}
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
