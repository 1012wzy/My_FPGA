"""Validate design receipts, including a documented post-build tool-path correction."""
from pathlib import Path
import hashlib
import json

PORTABLE_PYTHON = b'[file join $::env(XILINX_VIVADO) .. tps win64 python-3.13.0 python.exe]'

def validate_hardware_receipt(root):
    root = Path(root)
    receipt = json.loads((root / 'soc_hw/hardware_sources.json').read_text())
    corrected = []
    for name, expected in receipt.items():
        data = (root / name).read_bytes()
        actual = hashlib.sha256(data).hexdigest()
        if actual == expected:
            continue
        if name != 'soc_prj/scripts/build_soc.tcl':
            raise RuntimeError('Hardware/source mismatch: ' + name + '; rebuild Vivado first')
        patch = json.loads((root / 'scripts/validation/build_recipe_portability.json').read_text())
        normalized = data.replace(PORTABLE_PYTHON, b'@PYTHON_EXECUTABLE@')
        if not (
            patch['file'] == name
            and patch['change'] == 'post_build_python_executable_only'
            and patch['recorded_sha256'] == expected
            and patch['updated_sha256'] == actual
            and data.count(PORTABLE_PYTHON) == 1
            and patch['normalized_sha256'] == hashlib.sha256(normalized).hexdigest()
        ):
            raise RuntimeError('Unverified build-script change; rebuild Vivado first')
        corrected.append(name)
    return corrected
