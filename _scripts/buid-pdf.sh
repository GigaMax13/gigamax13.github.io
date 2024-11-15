#!/bin/bash

pandoc resume-short-version.md -o ./assets/resume.pdf --css pandoc-style.css --pdf-engine=wkhtmltopdf; open assets/resume.pdf