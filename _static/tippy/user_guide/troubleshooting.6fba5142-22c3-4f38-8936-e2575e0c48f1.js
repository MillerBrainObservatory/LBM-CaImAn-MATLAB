selector_to_html = {"a[href=\"#memory\"]": "<h2 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">6.1. </span>Memory<a class=\"headerlink\" href=\"#memory\" title=\"Permalink to this heading\">#</a></h2>", "a[href=\"#troubleshooting\"]": "<h1 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">6. </span>Troubleshooting<a class=\"headerlink\" href=\"#troubleshooting\" title=\"Permalink to this heading\">#</a></h1><h2><span class=\"section-number\">6.1. </span>Memory<a class=\"headerlink\" href=\"#memory\" title=\"Permalink to this heading\">#</a></h2>", "a[href=\"#matlab-server-issues\"]": "<h2 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">6.3. </span>Matlab Server Issues<a class=\"headerlink\" href=\"#matlab-server-issues\" title=\"Permalink to this heading\">#</a></h2><p>These come in many flavors and are mostly <cite>windows</cite> issues due to their background serrvice.</p><p>Here is the general fix for all of them:</p>", "a[href=\"#windows-filepaths\"]": "<h2 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">6.4. </span>Windows Filepaths<a class=\"headerlink\" href=\"#windows-filepaths\" title=\"Permalink to this heading\">#</a></h2><p>Sometimes Windows filepaths, with the backslash, is taken as an escape character rather than a file-path separator:</p>", "a[href=\"../api/core.html#motionCorrectPlane\"]": "<dt class=\"sig sig-object mat\" id=\"motionCorrectPlane\">\n<span class=\"sig-name descname\"><span class=\"pre\">motionCorrectPlane</span></span><span class=\"sig-paren\">(</span><em class=\"sig-param\"><span class=\"pre\">data_path</span></em>, <em class=\"sig-param\"><span class=\"pre\">varargin</span></em><span class=\"sig-paren\">)</span></dt><dd><p>Perform motion correction on imaging data.</p><p>Each motion-corrected plane is saved as a .h5 group containing the 2D\nshift vectors in x and y. The raw movie is saved in \u2018/Y\u2019 and the</p><p class=\"rubric\">Notes</p></dd>", "a[href=\"#ts-matlab-server\"]": "<h2 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">6.3. </span>Matlab Server Issues<a class=\"headerlink\" href=\"#matlab-server-issues\" title=\"Permalink to this heading\">#</a></h2><p>These come in many flavors and are mostly <cite>windows</cite> issues due to their background serrvice.</p><p>Here is the general fix for all of them:</p>", "a[href=\"#missing-compiled-binary-windows\"]": "<h2 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">6.2. </span>Missing Compiled Binary (Windows)<a class=\"headerlink\" href=\"#missing-compiled-binary-windows\" title=\"Permalink to this heading\">#</a></h2><p><strong>Cause:</strong> Likely caused by missing compiled binary for <cite>graph_conn_comp_mex.mexw64 (win)</cite>/ <cite>graph_conn_comp_mex.mexa64 (unix)</cite></p><p><strong>Solution:</strong>\n1. Compile the binary in MATLAB via the command window:</p>"}
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
