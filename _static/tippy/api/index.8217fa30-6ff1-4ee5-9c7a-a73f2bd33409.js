selector_to_html = {"a[href=\"#api\"]": "<h1 class=\"tippy-header\" style=\"margin-top: 0;\">API<a class=\"headerlink\" href=\"#api\" title=\"Permalink to this heading\">#</a></h1><p>There are two forms of functions to know for this pipeline:</p>", "a[href=\"utility.html#validation\"]": "<h2 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">2.4. </span>Validation<a class=\"headerlink\" href=\"#validation\" title=\"Permalink to this heading\">#</a></h2>", "a[href=\"internal.html\"]": "<h1 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">3. </span>Internals<a class=\"headerlink\" href=\"#internals\" title=\"Permalink to this heading\">#</a></h1><p>Functions that are meant for use within the pipeline, not for public use.</p>", "a[href=\"utility.html#writers\"]": "<h2 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">2.2. </span>Writers<a class=\"headerlink\" href=\"#writers\" title=\"Permalink to this heading\">#</a></h2>", "a[href=\"internal.html#internal-api\"]": "<h1 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">3. </span>Internals<a class=\"headerlink\" href=\"#internals\" title=\"Permalink to this heading\">#</a></h1><p>Functions that are meant for use within the pipeline, not for public use.</p>", "a[href=\"utility.html#readers\"]": "<h2 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">2.1. </span>Readers<a class=\"headerlink\" href=\"#readers\" title=\"Permalink to this heading\">#</a></h2>", "a[href=\"core.html#core-api\"]": "<h1 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">1. </span>Core<a class=\"headerlink\" href=\"#core\" title=\"Permalink to this heading\">#</a></h1><p>Core functions used to run the pipeline.</p>", "a[href=\"utility.html\"]": "<h1 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">2. </span>Utility<a class=\"headerlink\" href=\"#utility\" title=\"Permalink to this heading\">#</a></h1><p>Functions used by the pipeline that users can take advantage of to further process LBM datasets.</p>", "a[href=\"utility.html#utility-api\"]": "<h1 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">2. </span>Utility<a class=\"headerlink\" href=\"#utility\" title=\"Permalink to this heading\">#</a></h1><p>Functions used by the pipeline that users can take advantage of to further process LBM datasets.</p>", "a[href=\"utility.html#visualization\"]": "<h2 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">2.3. </span>Visualization<a class=\"headerlink\" href=\"#visualization\" title=\"Permalink to this heading\">#</a></h2>", "a[href=\"core.html\"]": "<h1 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">1. </span>Core<a class=\"headerlink\" href=\"#core\" title=\"Permalink to this heading\">#</a></h1><p>Core functions used to run the pipeline.</p>"}
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
