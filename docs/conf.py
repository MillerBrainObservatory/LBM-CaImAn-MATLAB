import sys
import os
from pathlib import Path

os.path.abspath(os.path.join("..", "core/utils"))
sys.path.insert(0, os.path.abspath(os.path.join("..", "core")))
matlab_src_dir = os.path.abspath("../core/")

primary_domain = "mat"
matlab_auto_link="basic"
matlab_short_links = True

project = 'LBM-CaImAn-MATLAB'
copyright = '2024, Elizabeth R. Miller Brain Observatory (MBO) | The Rockefeller University. All Rights Reserved.'


myst_enable_extensions = [
    "amsmath",
    "colon_fence",
    "deflist",
    "dollarmath",
    "html_image",
]
myst_url_schemes = ("http", "https", "mailto")

templates_path = ['_templates']
exclude_patterns = ['_build', 'Thumbs.db', '.DS_Store', 'exclude']

extensions = ["sphinx.ext.autodoc",
              "sphinxcontrib.images",
              "sphinxcontrib.video" ,
              "sphinxcontrib.matlab",
              "myst_nb",
              "sphinx_copybutton",
              "numpydoc",
              "sphinx.ext.intersphinx",
              "sphinx.ext.viewcode",
              "sphinx.ext.napoleon",
              "sphinx.ext.autosectionlabel",
              "sphinx_togglebutton",
              ]

images_config = dict(backend='LightBox2',
                     default_image_width='100%',
                     default_show_title='True',
                     default_group='default'
    )

# suppress_warnings = ["myst.domains", "ref.ref"]
source_suffix = {
    '.rst': 'restructuredtext',
    '.ipynb': 'myst-nb',
    '.md': 'myst-nb',
}
myst_enable_extensions = [
    "amsmath",
    "attrs_inline",
    "colon_fence",
    "deflist",
    "dollarmath",
    "fieldlist",
    "html_admonition",
    "html_image",
    "linkify",
    "replacements",
    "smartquotes",
    "strikethrough",
    "substitution",
    "tasklist",
]

intersphinx_mapping = {
    "python": ("https://docs.python.org/3.9", None),
    'mbo': ('https://millerbrainobservatory.github.io/',None),
    'lbmpy': ('https://millerbrainobservatory.github.io/LBM-CaImAn-Python/', None)
}

templates_path = ["_templates"]

html_theme = "pydata_sphinx_theme"

html_logo = "_static/CaImAn-MATLAB_logo.svg"
html_short_title="CaImAn Pipeline"
html_static_path = ["_static"]
html_css_files = ['custom.css']
html_favicon = "_static/mbo_icon_dark.ico"
html_copy_source = True

html_context = {
    "github_user": "https://github.com/MillerBrainObservatory/",
    "github_repo": "https://github.com/MillerBrainObservatory/LBM-CaImAn-MATLAB",
    "doc_path": "docs",
}

sphinx_book_options = {
    "external_links": [
        {"name": "MBO.io", "url": "https://millerbrainobservatory.github.io/index.html"},
        {"name": "LBM.Py", "url": "https://millerbrainobservatory.github.io/LBM-CaImAn-Python/index.html"},
        {"name": "scanreader", "url": "https://millerbrainobservatory.github.io/scanreader/index.html"},
    ],
}

html_theme_options = sphinx_book_options

