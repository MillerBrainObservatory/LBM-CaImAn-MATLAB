selector_to_html = {"a[href=\"#installation\"]": "<h2 class=\"tippy-header\" style=\"margin-top: 0;\">Installation<a class=\"headerlink\" href=\"#installation\" title=\"Permalink to this heading\">#</a></h2><p>Users with <a class=\"reference external\" href=\"https://git-scm.com/\">git</a> experience are encouraged to skip to the <a class=\"reference internal\" href=\"#installation-git\"><span class=\"std std-ref\">git installation section</span></a>.\nThis option avoids the need repeat the download process each time a new version of the pipeline is produced.</p>", "a[href=\"#directory-structure\"]": "<h2 class=\"tippy-header\" style=\"margin-top: 0;\">Directory Structure<a class=\"headerlink\" href=\"#directory-structure\" title=\"Permalink to this heading\">#</a></h2><p>The following is an example of the directory hierarchy\nused for the demo.</p>", "a[href=\"#with-git\"]": "<h3 class=\"tippy-header\" style=\"margin-top: 0;\">With git<a class=\"headerlink\" href=\"#with-git\" title=\"Permalink to this heading\">#</a></h3><p>Modern versions of matlab (2017+) solve most Linux/Windows filesystem conflicts. Installation is similar independent of OS.</p>", "a[href=\"#from-source\"]": "<h3 class=\"tippy-header\" style=\"margin-top: 0;\">From Source<a class=\"headerlink\" href=\"#from-source\" title=\"Permalink to this heading\">#</a></h3><p>The easiest way to download the source code is to visit the\n<a class=\"reference external\" href=\"https://github.com/MillerBrainObservatory/LBM-CaImAn-MATLAB\">github repository</a>,\ndownload the project via the <a class=\"sd-sphinx-override sd-badge sd-outline-light sd-text-light reference external\" href=\"Download ZIP\"><span>Download ZIP</span></a> button.</p><p>Move/extract the downloaded folder into a folder on your <code class=\"docutils literal notranslate\"><span class=\"pre\">userpath</span></code>.</p>", "a[href=\"#windows\"]": "<h3 class=\"tippy-header\" style=\"margin-top: 0;\">Windows<a class=\"headerlink\" href=\"#windows\" title=\"Permalink to this heading\">#</a></h3><p>The easiest method to download this repository with git is via <a class=\"reference external\" href=\"https://gitforwindows.org/\">mysys</a></p>", "a[href=\"#dependencies\"]": "<h2 class=\"tippy-header\" style=\"margin-top: 0;\">Dependencies<a class=\"headerlink\" href=\"#dependencies\" title=\"Permalink to this heading\">#</a></h2><p>Before running your first dataset, you should ensure that all dependencies of the pipeline are satisfied.</p><p>This pipeline requires the parallel pool, statistics and machine learning, and image processing toolboxes.</p>", "a[href=\"#project-setup\"]": "<h1 class=\"tippy-header\" style=\"margin-top: 0;\">0.1. Project Setup<a class=\"headerlink\" href=\"#project-setup\" title=\"Permalink to this heading\">#</a></h1><h2>Installation<a class=\"headerlink\" href=\"#installation\" title=\"Permalink to this heading\">#</a></h2><p>Users with <a class=\"reference external\" href=\"https://git-scm.com/\">git</a> experience are encouraged to skip to the <a class=\"reference internal\" href=\"#installation-git\"><span class=\"std std-ref\">git installation section</span></a>.\nThis option avoids the need repeat the download process each time a new version of the pipeline is produced.</p>", "a[href=\"#linux\"]": "<h3 class=\"tippy-header\" style=\"margin-top: 0;\">Linux<a class=\"headerlink\" href=\"#linux\" title=\"Permalink to this heading\">#</a></h3><p>In Linux, WSL or mysys, clone this repository with the pre-installed git client:</p>", "a[href=\"#wsl2-windows-subsystem-for-linux\"]": "<h3 class=\"tippy-header\" style=\"margin-top: 0;\">WSL2 (Windows Subsystem for Linux)<a class=\"headerlink\" href=\"#wsl2-windows-subsystem-for-linux\" title=\"Permalink to this heading\">#</a></h3><p>Windows subsystem for Linux (WSL/WSL2) is a local environment on your windows machine that is capable of running linux commands using a separate filesystem.</p><p>As of 2024, Mathworks does not officially support and is not planning support for MATLAB on WSL or WSL2.</p>", "a[href=\"#installation-git\"]": "<h3 class=\"tippy-header\" style=\"margin-top: 0;\">With git<a class=\"headerlink\" href=\"#with-git\" title=\"Permalink to this heading\">#</a></h3><p>Modern versions of matlab (2017+) solve most Linux/Windows filesystem conflicts. Installation is similar independent of OS.</p>"}
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