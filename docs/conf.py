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
        '.txt': 'restructuredtext',
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
    "python": ("https://docs.python.org/3.8", None),
    "sphinx": ("https://www.sphinx-doc.org/en/master", None),
    "pst": ("https://pydata-sphinx-theme.readthedocs.io/en/latest/", None),
}

templates_path = ["_templates"]

html_theme = "sphinx_book_theme"
html_short_title="LBM-CaImAn-MATLAB"
html_static_path = ["_static"]
html_css_files = ['LBM_docs.css']
html_logo = "_static/LBM_icon.ico"
html_copy_source = True

html_sidebars = {
    "reference/blog/*": [
        "navbar-logo.html",
        "search-field.html",
        "ablog/postcard.html",
        "ablog/recentposts.html",
        "ablog/tagcloud.html",
        "ablog/categories.html",
        "ablog/archives.html",
        "sbt-sidebar-nav.html",
    ]
}


html_theme_options = {
    "path_to_docs": "docs",
    "repository_url": "https://github.com/MillerBrainObservatory/LBM-CaImAn-MATLAB",
    "repository_branch": "master",
    "launch_buttons": {
        "binderhub_url": "https://mybinder.org",
        "colab_url": "https://colab.research.google.com/",
        "deepnote_url": "https://deepnote.com/",
        "notebook_interface": "jupyterlab",
        # "jupyterhub_url": "https://datahub.berkeley.edu",  # For testing
    },
    "use_edit_page_button": True,
    "use_source_button": True,
    "use_issues_button": True,
    "use_repository_button": True,
    "use_download_button": True,
    "use_sidenotes": True,
    "show_toc_level": 2,
    "logo": {
        "image_dark": "_static/LBM_icon.svg",
        "text": html_short_title
    },
    "icon_links": [
        {
            "name": "MBO",
            "url": "https://mbo.rockefeller.edu",
        },

  #     {"name": "MBO", "url": ""},
        {
            "name": "GitHub",
            "url": "https://github.com/MillerBrainObservatory/LBM-CaImAn-MATLAB",
            "icon": "fa-brands fa-github",
        },
        # {
        #     "name": "PyPI",
        #     "url": "https://pypi.org/project/sphinx-book-theme/",
        #     "icon": "https://img.shields.io/pypi/dw/sphinx-book-theme",
        #     "type": "url",
        # },
    ],
    # For testing
    # "use_fullscreen_button": False,
    # "home_page_in_toc": True,
    # "extra_footer": "<a href='https://google.com'>Test</a>",  # DEPRECATED KEY
    # "show_navbar_depth": 2,
    # Testing layout areas
    # "navbar_start": ["test.html"],
    # "navbar_center": ["test.html"],
    # "navbar_end": ["test.html"],
    # "navbar_persistent": ["test.html"],
    # "footer_start": ["test.html"],
    # "footer_end": ["test.html"]
}

html_theme_options = {
  "show_navbar_depth": 2,
  "home_page_in_toc": True,
  # "external_links": [
  #     {"name": "MBO", "url": "https://mbo.rockefeller.edu"},
  # ]
}
