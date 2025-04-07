selector_to_html = {"a[href=\"#glossary\"]": "<h1 class=\"tippy-header\" style=\"margin-top: 0;\">Glossary<a class=\"headerlink\" href=\"#glossary\" title=\"Permalink to this heading\">#</a></h1>", "a[href=\"#term-pixel-resolution\"]": "<dt id=\"term-pixel-resolution\">pixel-resolution</dt><dd><p>The length of each pixel, in micron (px/um).</p></dd>", "a[href=\"#term-Rigid-registration\"]": "<dt id=\"term-Rigid-registration\">Rigid-registration</dt><dd><p>The object retains shape and size.</p></dd>", "a[href=\"#term-deconvolution\"]": "<dt id=\"term-deconvolution\">deconvolution</dt><dd><p>The process performed after segmentation to the resulting traces to infer spike times from flourescence values.</p></dd>", "a[href=\"#term-Non-rigid-registration\"]": "<dt id=\"term-Non-rigid-registration\">Non-rigid-registration</dt><dd><p>The object is moved and transforms shape or size.</p></dd>", "a[href=\"#term-source-extraction\"]": "<dt id=\"term-source-extraction\">source-extraction</dt><dd><p>Umbrella term for all of the individual processes that produce a segmented image.</p></dd>", "a[href=\"#term-CNMF\"]": "<dt id=\"term-CNMF\">CNMF</dt><dd><p>The name for a set of algorithms within the flatironinstitute\u2019s <a class=\"reference external\" href=\"https://github.com/flatironinstitute/CaImAn-MATLAB\">CaImAn Pipeline</a> that initialize parameters and run source extraction.</p></dd>", "a[href=\"#term-segmentation\"]": "<dt id=\"term-segmentation\">segmentation</dt><dd><p>The general process of dividing an image based on the contents of that image, in our case, based on neuron location.</p></dd>"}
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
