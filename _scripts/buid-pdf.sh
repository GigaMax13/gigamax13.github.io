#!/bin/bash

# Generate short version PDFs
pandoc ./_scripts/resume-short-version.md --from markdown+raw_html -o ./assets/resume-short.pdf --css ./_scripts/pandoc-style.css --pdf-engine=wkhtmltopdf; open assets/resume-short.pdf
pandoc ./_scripts/pt_br/resume-short-version.md --from markdown+raw_html -o ./assets/pt_br/resume-short.pdf --css ./_scripts/pandoc-style.css --pdf-engine=wkhtmltopdf; open assets/pt_br/resume-short.pdf

# Generate full version PDFs
pandoc ./resume.md --from markdown+raw_html -o ./assets/resume.pdf --css ./_scripts/pandoc-style.css --pdf-engine=wkhtmltopdf; open assets/resume.pdf
pandoc ./pt_br/resume.md --from markdown+raw_html -o ./assets/pt_br/resume.pdf --css ./_scripts/pandoc-style.css --pdf-engine=wkhtmltopdf; open assets/pt_br/resume.pdf