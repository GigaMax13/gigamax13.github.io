# Maximiliano Dalla Porta - Portfolio Website

A Jekyll-based static website showcasing my professional resume and portfolio. The site is bilingual (English and Portuguese) and automatically deploys to GitHub Pages via GitHub Actions.

## Running Locally

Run the development script:

```bash
./_scripts/dev.sh
```

The site will be available at `http://localhost:4000`.

## Generating PDFs

Generate PDF versions of the resume:

```bash
./_scripts/buid-pdf.sh
```

This generates PDFs for both English and Portuguese versions (short and full).

**Note:** Requires `pandoc` and `wkhtmltopdf` to be installed.
