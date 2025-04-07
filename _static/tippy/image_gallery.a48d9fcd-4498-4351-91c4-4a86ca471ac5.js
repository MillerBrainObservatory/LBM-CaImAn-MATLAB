selector_to_html = {"a[href=\"#gh-download\"]": "<figure class=\"align-default\" id=\"gh-download\">\n<a class=\"reference internal image-reference\" href=\"_images/gh_download.png\"><img alt=\"gh_download\" src=\"_images/gh_download.png\" style=\"width: 560.5px; height: 280.0px;\"/></a>\n<figcaption>\n<p><span class=\"caption-text\">Download project source code.</span><a class=\"headerlink\" href=\"#gh-download\" title=\"Permalink to this image\">#</a></p>\n<div class=\"legend\">\n<p>Navigate to the github repository site and download the source code via \u201cDownload ZIP\u201d.\nExtract this somewhere on your matlab userpath.</p>\n</div>\n</figcaption>\n</figure>", "a[href=\"#image-gallery\"]": "<h1 class=\"tippy-header\" style=\"margin-top: 0;\">Image Gallery<a class=\"headerlink\" href=\"#image-gallery\" title=\"Permalink to this heading\">#</a></h1><h2>Image Assembly<a class=\"headerlink\" href=\"#image-assembly\" title=\"Permalink to this heading\">#</a></h2><p><a class=\"reference external\" href=\"https://cerodell.github.io/sphinx-quickstart-guide/build/html/addtoindx.html\">Back to Guide</a></p>", "a[href=\"#ex-diagram-remote\"]": "<figure class=\"align-default\" id=\"ex-diagram-remote\">\n<img alt=\"ex_diagram_remote\" src=\"https://github.com/MillerBrainObservatory/static-assets/blob/master/_images/ex_diagram.svg\"/><figcaption>\n<p><span class=\"caption-text\">Scan-phase diagram (Remote)\n:scale: 50 %</span><a class=\"headerlink\" href=\"#ex-diagram-remote\" title=\"Permalink to this image\">#</a></p>\n<div class=\"legend\">\n<p>This is the caption of the figure (a simple paragraph).</p>\n<p>The legend consists of all elements after the caption.  In this\ncase, the legend consists of this paragraph and the following table</p>\n</div>\n</figcaption>\n</figure>", "a[href=\"#image-assembly\"]": "<h2 class=\"tippy-header\" style=\"margin-top: 0;\">Image Assembly<a class=\"headerlink\" href=\"#image-assembly\" title=\"Permalink to this heading\">#</a></h2><p><a class=\"reference external\" href=\"https://cerodell.github.io/sphinx-quickstart-guide/build/html/addtoindx.html\">Back to Guide</a></p>", "a[href=\"#ex-scanphase\"]": "<figure class=\"align-default\" id=\"ex-scanphase\">\n<a class=\"reference internal image-reference\" href=\"_images/ex_scanphase.svg\"><img alt=\"ex_scanphase\" height=\"509\" src=\"_images/ex_scanphase.svg\" width=\"336\"/></a>\n<figcaption>\n<p><span class=\"caption-text\">Scan-phase diagram</span><a class=\"headerlink\" href=\"#ex-scanphase\" title=\"Permalink to this image\">#</a></p>\n</figcaption>\n</figure>"}
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
