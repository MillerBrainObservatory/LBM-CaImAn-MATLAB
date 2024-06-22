import sys
import os

os.path.abspath(os.path.join("..", "core/utils"))
sys.path.insert(0, os.path.abspath(os.path.join("..", "core")))
matlab_src_dir = os.path.abspath("../core/")

primary_domain = "mat"
matlab_auto_link="basic"
matlab_short_links = True

project = 'LBM-CaImAn-MATLAB'
copyright = '2024, Elizabeth R. Miller Brain Observatory (MBO) | The Rockefeller University. All Rights Reserved.'

source_suffix = {
        '.rst': 'restructuredtext',
        '.md': 'markdown',
        }

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

suppress_warnings = ["myst.domains", "ref.ref"]

intersphinx_mapping = {
    "python": ("https://docs.python.org/3.9", None),
    "sphinx": ("https://www.sphinx-doc.org/en/master", None),
}

templates_path = ["_templates"]

html_theme = "sphinx_book_theme"
html_short_title="LBM-CaImAn-MATLAB"
html_static_path = ["_static"]
html_css_files = ['LBM_docs.css']
html_favicon = "_static/LBM_icon.ico"
html_copy_source = True

# for sphinx_book_theme only
# theme-dependent options make uploading
# an MBO theme-option set confusing
sphinx_book_options = {
    "path_to_docs": "docs",
    "repository_url": "https://github.com/MillerBrainObservatory/LBM-CaImAn-MATLAB",
    "repository_branch": "master",
    "launch_buttons": {
        "binderhub_url": "https://mybinder.org",
        "colab_url": "https://colab.research.google.com/",
        "notebook_interface": "jupyterlab",
        # "jupyterhub_url": "", TODO
    },
    "use_edit_page_button": True,
    "use_source_button": True,
    "use_issues_button": True,
    "use_repository_button": True,
    "use_download_button": True,
    "use_sidenotes": True,
    "show_toc_level": 3,
    "logo": {
        "image_dark": "https://github.com/MillerBrainObservatory/static-assets/blob/master/img/favicon/MillerBrainObservatory_logo.svg",
        "text": html_short_title
    },
    "icon_links": [
        {
            "icon": "fa fa-home",
            "name": "MBO",
            "url": "https://mbo.rockefeller.edu",
        },
        {
            "name": "GitHub",
            "url": "https://github.com/MillerBrainObservatory/LBM-CaImAn-MATLAB",
            "icon": "fa-brands fa-github",
        },
    ],
}

html_theme_options = sphinx_book_options
