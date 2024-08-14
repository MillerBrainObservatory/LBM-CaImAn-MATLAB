import sys
import os
from pathlib import Path

os.path.abspath(os.path.join("..", "core/utils"))
sys.path.insert(0, os.path.abspath(os.path.join("..", "core")))

project = "LBM-CaImAn-MATLAB"
copyright = "2024, Elizabeth R. Miller Brain Observatory | The Rockefeller University. All Rights Reserved"

myst_enable_extensions = [
    "colon_fence",
    "dollarmath",
    "html_image",
]

myst_url_schemes = ("http", "https", "mailto")

templates_path = ["_templates"]
exclude_patterns = ["_build", "Thumbs.db", ".DS_Store", "exclude"]

extensions = [
    "sphinxcontrib.matlab",
    "sphinx.ext.autodoc",
    "sphinxcontrib.images",
    "sphinxcontrib.video",
    "myst_nb",
    "sphinx_copybutton",
    "numpydoc",
    "sphinx.ext.intersphinx",
    "sphinx.ext.viewcode",
    "sphinx.ext.napoleon",
    "sphinx_togglebutton",
    "sphinx_design",
    "sphinx_tippy",
]

# https://github.com/sphinx-contrib/matlabdomain
matlab_src_dir = os.path.abspath("../core/")

primary_domain = "mat"
matlab_auto_link = "basic"
matlab_short_links = True


images_config = dict(
    backend="LightBox2",
    default_image_width="100%",
    default_show_title="True",
    default_group="default",
)

# source_suffix = {
#     ".rst": "restructuredtext",
#     ".ipynb": "myst-nb",
#     ".myst": "myst-nb",
# }

current_filepath = (
    Path().home()
    / "repos"
    / "work"
    / "millerbrainobservatory.github.io/docs/build/html/"
)
# print(current_filepath.is_dir())

intersphinx_mapping = {
    "mbo": ("https://millerbrainobservatory.github.io/", None),
}

templates_path = ["_templates"]

html_theme = "sphinx_book_theme"

html_logo = "_static/CaImAn-MATLAB_logo.svg"
html_short_title = "LBM CaImAn Pipeline"
html_static_path = ["_static"]
html_css_files = ["custom.css"]
# html_js_files = ["subtoc.js"]
html_favicon = "./_static/lbm_caiman_mat.svg"
html_copy_source = True

html_theme_options = {
    "path_to_docs": "docs",
    "repository_url": "https://github.com/MillerBrainObservatory/LBM-CaImAn-MATLAB",
    "repository_branch": "master",
    "use_edit_page_button": True,
    "use_source_button": True,
    "use_issues_button": True,
    "use_download_button": True,
    "show_toc_level": 3,
    "navbar_align": "content",
    "icon_links": [
        {
            "name": "MBO User Hub",
            "url": "https://millerbrainobservatory.github.io/",
            "icon": "./_static/icon_mbo_home.png",
            "type": "local",
        },
        {
            "name": "MBO Github",
            "url": "https://github.com/MillerBrainObservatory/",
            "icon": "fa-brands fa-github",
            "type": "fontawesome",
        },
        {
            "name": "Connect with MBO",
            "url": "https://mbo.rockefeller.edu/contact/",
            "icon": "fa-regular fa-address-card",
            "type": "fontawesome",
        },
    ],
}
