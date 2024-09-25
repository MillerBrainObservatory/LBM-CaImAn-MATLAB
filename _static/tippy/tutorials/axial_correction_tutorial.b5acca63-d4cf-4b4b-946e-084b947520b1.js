selector_to_html = {"a[href=\"#explained-axial-offset-correction\"]": "<h1 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">3. </span>Explained: Axial Offset Correction<a class=\"headerlink\" href=\"#explained-axial-offset-correction\" title=\"Permalink to this heading\">#</a></h1><h2><span class=\"section-number\">3.1. </span>Background<a class=\"headerlink\" href=\"#background\" title=\"Permalink to this heading\">#</a></h2><p>Light beads traveling to our sample need to be temporally distinct relative to our sensor\nso that the aquisition system knows the origin and subsequent depth of each bead.</p><p>The current LBM design incoorperates 2 cavities, hereby named <code class=\"docutils literal notranslate\"><span class=\"pre\">Cavity</span> <span class=\"pre\">A</span></code> and <code class=\"docutils literal notranslate\"><span class=\"pre\">Cavity</span> <span class=\"pre\">B</span></code>.\nThese two cavities are non-overlapping areas where light beads travel. If we plot\na sample pollen grain through each z-depth, we can see these cavities manifest:</p>", "a[href=\"#background\"]": "<h2 class=\"tippy-header\" style=\"margin-top: 0;\"><span class=\"section-number\">3.1. </span>Background<a class=\"headerlink\" href=\"#background\" title=\"Permalink to this heading\">#</a></h2><p>Light beads traveling to our sample need to be temporally distinct relative to our sensor\nso that the aquisition system knows the origin and subsequent depth of each bead.</p><p>The current LBM design incoorperates 2 cavities, hereby named <code class=\"docutils literal notranslate\"><span class=\"pre\">Cavity</span> <span class=\"pre\">A</span></code> and <code class=\"docutils literal notranslate\"><span class=\"pre\">Cavity</span> <span class=\"pre\">B</span></code>.\nThese two cavities are non-overlapping areas where light beads travel. If we plot\na sample pollen grain through each z-depth, we can see these cavities manifest:</p>"}
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
