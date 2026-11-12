#!/usr/bin/env python3
"""Render every .sls as Jinja (with a stub pillar) and check it parses as YAML. Needs: jinja2, pyyaml."""
import sys
from pathlib import Path

import jinja2
import yaml

PILLAR = {"app": {"name": "demoapp", "version": "1.2.3", "user": "demoapp", "port": 8080}}


class Pillar:
    def get(self, key, default=None):
        return PILLAR.get(key, default)


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    failed = 0
    for sls in sorted((root / "salt").rglob("*.sls")) + sorted((root / "pillar").rglob("*.sls")):
        try:
            rendered = jinja2.Template(sls.read_text()).render(pillar=Pillar(), grains={"role": "app"})
            data = yaml.safe_load(rendered)
            assert isinstance(data, dict) and data, "empty or non-mapping document"
            print(f"ok    {sls.relative_to(root)} ({len(data)} top-level keys)")
        except Exception as exc:  # noqa: BLE001
            failed += 1
            print(f"FAIL  {sls.relative_to(root)}: {exc}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
