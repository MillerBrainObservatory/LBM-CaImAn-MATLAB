selector_to_html = {"a[href=\"https://en.wikipedia.org/wiki/Image_registration\"]": "<img src=\"https://upload.wikimedia.org/wikipedia/commons/thumb/d/d7/Registrator_Demo2.png/320px-Registrator_Demo2.png\" alt=\"Wikipedia thumbnail\" style=\"float:left; margin-right:10px;\"><p><b>Image registration</b> is the process of transforming different sets of data into one coordinate system. Data may be multiple photographs, data from different sensors, times, depths, or viewpoints. It is used in computer vision, medical imaging, military automatic target recognition, and compiling and analyzing images and data from satellites. Registration is necessary in order to be able to compare or integrate the data obtained from these different measurements.</p>", "a[href^=\"https://en.wikipedia.org/wiki/Image_registration#\"]": "<img src=\"https://upload.wikimedia.org/wikipedia/commons/thumb/d/d7/Registrator_Demo2.png/320px-Registrator_Demo2.png\" alt=\"Wikipedia thumbnail\" style=\"float:left; margin-right:10px;\"><p><b>Image registration</b> is the process of transforming different sets of data into one coordinate system. Data may be multiple photographs, data from different sensors, times, depths, or viewpoints. It is used in computer vision, medical imaging, military automatic target recognition, and compiling and analyzing images and data from satellites. Registration is necessary in order to be able to compare or integrate the data obtained from these different measurements.</p>", "a[href=\"#non-rigid\"]": "<h3 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">1.1.2. </span>Non-rigid<a class=\"headerlink\" href=\"#non-rigid\" title=\"Permalink to this heading\">#</a></h3><p>Non-Rigid motion\n: The object is moved and transforms shape or size.</p>", "a[href=\"#types-of-registration\"]": "<h2 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">1.1. </span>Types of Registration<a class=\"headerlink\" href=\"#types-of-registration\" title=\"Permalink to this heading\">#</a></h2><p><a class=\"reference external\" href=\"https://en.wikipedia.org/wiki/Image_registration\">Image registration</a> can often improve the quality of cellular traces obtained during the later segmentation step.</p><p>The motion artifacts present in a 3D timeseries come in two flavors, <code class=\"docutils literal notranslate\"><span class=\"pre\">rigid</span></code> and <code class=\"docutils literal notranslate\"><span class=\"pre\">non-rigid</span></code>.</p>", "a[href=\"#explained-registration\"]": "<h1 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">1. </span>Explained: Registration<a class=\"headerlink\" href=\"#explained-registration\" title=\"Permalink to this heading\">#</a></h1><h2><span class=\"section-number\">1.1. </span>Types of Registration<a class=\"headerlink\" href=\"#types-of-registration\" title=\"Permalink to this heading\">#</a></h2><p><a class=\"reference external\" href=\"https://en.wikipedia.org/wiki/Image_registration\">Image registration</a> can often improve the quality of cellular traces obtained during the later segmentation step.</p><p>The motion artifacts present in a 3D timeseries come in two flavors, <code class=\"docutils literal notranslate\"><span class=\"pre\">rigid</span></code> and <code class=\"docutils literal notranslate\"><span class=\"pre\">non-rigid</span></code>.</p>", "a[href=\"../glossary.html#term-Rigid-registration\"]": "<dt id=\"term-Rigid-registration\">Rigid-registration</dt><dd><p>The object retains shape and size.</p></dd>", "a[href=\"#rigid\"]": "<h3 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">1.1.1. </span>Rigid<a class=\"headerlink\" href=\"#rigid\" title=\"Permalink to this heading\">#</a></h3><p><a class=\"reference internal\" href=\"../glossary.html#term-Rigid-registration\"><span class=\"xref std std-term\">Rigid motion</span></a></p><p>Rigid motion\n: The object is moved with its shape and size preserved.</p>"}
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