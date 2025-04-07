selector_to_html = {"a[href=\"#core-parameters\"]": "<h2 class=\"tippy-header\" style=\"margin-top: 0;\">Core Parameters<a class=\"headerlink\" href=\"#core-parameters\" title=\"Permalink to this heading\">#</a></h2><p>For the <a class=\"reference internal\" href=\"../api/core.html#core-api\"><span class=\"std std-ref\">Core</span></a> functions in this pipeline, the initial parameters are always the same.</p>", "a[href=\"#pipeline-usage\"]": "<h1 class=\"tippy-header\" style=\"margin-top: 0;\">0.2. Pipeline Usage<a class=\"headerlink\" href=\"#pipeline-usage\" title=\"Permalink to this heading\">#</a></h1><p>The bare-minimum to use this pipeline involves calling four functions which have sensible default values for LBM recordings.</p><p>The only <em>required</em> inputs to the pipeline are a path where your raw/previously processed data lives.</p>", "a[href=\"#required\"]": "<h3 class=\"tippy-header\" style=\"margin-top: 0;\">Required<a class=\"headerlink\" href=\"#required\" title=\"Permalink to this heading\">#</a></h3><p>The only required parameter is the data-path:</p><p><code class=\"code docutils literal notranslate\"><span class=\"pre\">data_path</span></code>\n: A filepath leading to the directory that contains the input files.</p>", "a[href=\"#logging\"]": "<h2 class=\"tippy-header\" style=\"margin-top: 0;\">Logging<a class=\"headerlink\" href=\"#logging\" title=\"Permalink to this heading\">#</a></h2><h3>To File<a class=\"headerlink\" href=\"#to-file\" title=\"Permalink to this heading\">#</a></h3><p>A log file will be saved with every processing step.</p><p>This logs the start time and duration of each computation, as well as storing metadata and function parameters.</p>", "a[href=\"#to-file\"]": "<h3 class=\"tippy-header\" style=\"margin-top: 0;\">To File<a class=\"headerlink\" href=\"#to-file\" title=\"Permalink to this heading\">#</a></h3><p>A log file will be saved with every processing step.</p><p>This logs the start time and duration of each computation, as well as storing metadata and function parameters.</p>", "a[href=\"#optional\"]": "<h3 class=\"tippy-header\" style=\"margin-top: 0;\">Optional<a class=\"headerlink\" href=\"#optional\" title=\"Permalink to this heading\">#</a></h3><p>The remaining parameters are optional:</p><p><code class=\"code docutils literal notranslate\"><span class=\"pre\">save_path</span></code>\n: A filepath leading to the directory where any results are saved.</p>", "a[href=\"#to-command-window\"]": "<h3 class=\"tippy-header\" style=\"margin-top: 0;\">To Command Window<a class=\"headerlink\" href=\"#to-command-window\" title=\"Permalink to this heading\">#</a></h3><p>Additionally, you will see metadata printed to the command window when a processing step is started:</p>", "a[href=\"../api/core.html#core-api\"]": "<h1 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">1. </span>Core<a class=\"headerlink\" href=\"#core\" title=\"Permalink to this heading\">#</a></h1><p>Core functions used to run the pipeline.</p>"}
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
