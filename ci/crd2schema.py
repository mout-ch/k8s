#!/usr/bin/env python3
"""Turn the CRDs found in a rendered manifest into kubeconform JSON schemas.

Usage: crd2schema.py <rendered.yaml> <output-dir>

Writes <output-dir>/<group>/<kind>_<version>.json (kind lowercased), matching
the kubeconform schema-location template used in validate.sh. This lets a
chart's resources be validated against the exact CRD version it ships,
instead of a third-party catalog that may lag behind.
"""
import json
import os
import sys

import yaml


def convert(node):
    """OpenAPI v3 (Kubernetes flavour) -> JSON schema, strict like the catalog."""
    if isinstance(node, list):
        return [convert(n) for n in node]
    if not isinstance(node, dict):
        return node

    if node.get("x-kubernetes-int-or-string") or node.get("format") == "int-or-string":
        rest = {k: v for k, v in node.items()
                if k not in ("type", "format", "x-kubernetes-int-or-string")}
        return {**convert(rest), "oneOf": [{"type": "string"}, {"type": "integer"}]}

    out = {k: convert(v) for k, v in node.items()}
    if ("properties" in out and "additionalProperties" not in out
            and not node.get("x-kubernetes-preserve-unknown-fields")):
        out["additionalProperties"] = False
    if node.get("nullable") and isinstance(out.get("type"), str):
        out["type"] = [out["type"], "null"]
    return out


def main(rendered, outdir):
    count = 0
    with open(rendered) as f:
        for doc in yaml.safe_load_all(f):
            if not doc or doc.get("kind") != "CustomResourceDefinition":
                continue
            spec = doc["spec"]
            group, kind = spec["group"], spec["names"]["kind"].lower()
            for version in spec.get("versions", []):
                schema = (version.get("schema") or {}).get("openAPIV3Schema")
                if not schema:
                    continue
                path = os.path.join(outdir, group, f"{kind}_{version['name']}.json")
                os.makedirs(os.path.dirname(path), exist_ok=True)
                with open(path, "w") as out:
                    json.dump(convert(schema), out)
                count += 1
    print(f"    {count} schema(s) from bundled CRDs")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
