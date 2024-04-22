import sys
import os

sys.path.insert(0, os.path.abspath(os.path.join("..", "..")))
matlab_src_dir = os.path.abspath("..")

project = 'caiman_matlab'
copyright = '2024, Elizabeth R. Miller Brain Observatory (MBO)'

source_suffix = {
        '.rst': 'restructuredtext',
        '.txt': 'restructuredtext',
        '.md': 'markdown',
        }

templates_path = ['_templates']
exclude_patterns = ['_build', 'Thumbs.db', '.DS_Store']
html_static_path = ['_static']
extensions = ["sphinx.ext.autodoc", "sphinxcontrib.matlab", "numpydoc", "sphinx.ext.intersphinx"]
primary_domain = "mat"
templates_path = ["_templates"]
exclude_patterns = ["_build", "Thumbs.db", ".DS_Store"]
html_theme = "default"
