selector_to_html = {"a[href=\"#deconvolution\"]": "<h2 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">2.2. </span>Deconvolution<a class=\"headerlink\" href=\"#deconvolution\" title=\"Permalink to this heading\">#</a></h2><p>The CNMF output yields \u201craw\u201d traces, we need to deconvolve these to convert these raw traces to interpritable neuronal traces.</p><p>These raw traces are noisy, jagged, and must be denoised, detrended and deconvolved.</p>", "a[href=\"#explained-source-extraction\"]": "<h1 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">2. </span>Explained: Source Extraction<a class=\"headerlink\" href=\"#explained-source-extraction\" title=\"Permalink to this heading\">#</a></h1><p>This section details background information helpful with <a class=\"reference internal\" href=\"../user_guide/segmentation.html#ug-source-extraction\"><span class=\"std std-ref\">Step 3: Segmentation</span></a></p><p>Source extraction is the umbrella term for a sequence of steps designed to distinguish neurons from background signal calculate the properties and characteristics of these neurons relative to the background.</p>", "a[href=\"#constrained-non-negative-matrix-factorization-cnmf\"]": "<h2 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">2.1. </span>Constrained Non-Negative Matrix Factorization (CNMF)<a class=\"headerlink\" href=\"#constrained-non-negative-matrix-factorization-cnmf\" title=\"Permalink to this heading\">#</a></h2><p>At a high-level, the <a class=\"reference internal\" href=\"../glossary.html#term-CNMF\"><span class=\"xref std std-term\">CNMF</span></a> algorithm works by:</p>", "a[href=\"../glossary.html#term-segmentation\"]": "<dt id=\"term-segmentation\">segmentation</dt><dd><p>The general process of dividing an image based on the contents of that image, in our case, based on neuron location.</p></dd>", "a[href=\"#validating-neurons-and-traces\"]": "<h2 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">2.3. </span>Validating Neurons and Traces<a class=\"headerlink\" href=\"#validating-neurons-and-traces\" title=\"Permalink to this heading\">#</a></h2><p>The key idea for validating our neurons is that <strong>we know how long the\nbrightness indicating neurons activity should stay bright</strong> as a function\nof the <em>number of frames</em>.</p><p>That is, our calcium indicator (in this example: GCaMP-6s):</p>", "a[href=\"../user_guide/segmentation.html#ug-source-extraction\"]": "<h1 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">3. </span>Segmentation<a class=\"headerlink\" href=\"#segmentation\" title=\"Permalink to this heading\">#</a></h1><p>Function for this step: <a class=\"reference internal\" href=\"../api/core.html#segmentPlane\" title=\"segmentPlane\"><code class=\"xref mat mat-func docutils literal notranslate\"><span class=\"pre\">segmentPlane()</span></code></a></p>", "a[href=\"../glossary.html#term-CNMF\"]": "<dt id=\"term-CNMF\">CNMF</dt><dd><p>The name for a set of algorithms within the flatironinstitute\u2019s <a class=\"reference external\" href=\"https://github.com/flatironinstitute/CaImAn-MATLAB\">CaImAn Pipeline</a> that initialize parameters and run source extraction.</p></dd>"}
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
