#!/usr/bin/env python3
"""Convert kcov cobertura reports into the SonarQube generic coverage format."""
import glob
import sys
import xml.etree.ElementTree as ET

cov_dir, out_path = sys.argv[1], sys.argv[2]
files: dict[str, dict[int, bool]] = {}
reports = glob.glob(f"{cov_dir}/**/cobertura.xml", recursive=True) + glob.glob(f"{cov_dir}/**/coverage.xml", recursive=True)
for cobertura in reports:
    root = ET.parse(cobertura).getroot()
    for cls in root.iter("class"):
        name = cls.get("filename", "")
        for line in cls.iter("line"):
            number = int(line.get("number", "0"))
            hits = int(line.get("hits", "0"))
            covered = files.setdefault(name, {})
            covered[number] = covered.get(number, False) or hits > 0

coverage = ET.Element("coverage", version="1")
for name, lines in sorted(files.items()):
    file_el = ET.SubElement(coverage, "file", path=name)
    for number, covered in sorted(lines.items()):
        ET.SubElement(
            file_el, "lineToCover",
            lineNumber=str(number), covered="true" if covered else "false",
        )
ET.ElementTree(coverage).write(out_path, encoding="utf-8", xml_declaration=True)
print(f"wrote {out_path} for {len(files)} file(s)")
