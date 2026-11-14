#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Forwarder for test_qn_release to satisfy `python3 -m unittest scripts/test_qn_release.py`
"""
import os
import sys

_REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if _REPO_ROOT not in sys.path:
    sys.path.append(_REPO_ROOT)

from test.scripts.test_qn_release import *

if __name__ == "__main__":
    import unittest
    unittest.main()
