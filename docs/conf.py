import sys
import os

os.path.abspath(os.path.join("..", "core/utils"))
sys.path.insert(0, os.path.abspath(os.path.join("..", "core")))
matlab_src_dir = os.path.abspath("../core/")

primary_domain = "mat"
matlab_auto_link="basic"
matlab_short_links = True

project = 'caiman_matlab'
copyright = '2024, Elizabeth R. Miller Brain Observatory (MBO) | The Rockefeller University. All Rights Reserved.'

source_suffix = {
        '.rst': 'restructuredtext',
        '.txt': 'restructuredtext',
        '.md': 'markdown',
        }

templates_path = ['_templates']
exclude_patterns = ['_build', 'Thumbs.db', '.DS_Store', 'exclude/*']
extensions = ["sphinx.ext.autodoc", "sphinxcontrib.matlab", "numpydoc", "sphinx.ext.intersphinx", "sphinx.ext.napoleon"]

templates_path = ["_templates"]
html_theme = "pydata_sphinx_theme"
html_short_title="LBM"
html_static_path = ["_static"]
html_logo = "_static/favicon.ico"

