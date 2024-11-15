#!/bin/bash

pandoc ./_scripts/resume-short-version.md -o ./assets/resume.pdf --css ./_scripts/pandoc-style.css --pdf-engine=wkhtmltopdf; open assets/resume.pdf