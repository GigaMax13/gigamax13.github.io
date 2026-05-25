#!/bin/bash
# Render TSV of applicable rules (from applicable-rules.sh) as a Markdown table.
#
# Usage: render-rules-table.sh <PROJECT_ID> <RULES_DIR> [--no-changes]
# Stdin (TSV): category<TAB>rule<TAB>trigger<TAB>existence
# Stdout: heading + Markdown table.
#
# A rule with existence=="missing" is rendered with a " (missing)" suffix in
# the Rule column, so gaps in the rules directory stay visible instead of
# being silently skipped.

set -e

PROJECT_ID="${1:-?}"
RULES_DIR="${2:-?}"
MODE="${3:-}"

HEADING="Loaded rules for $PROJECT_ID (source: $RULES_DIR)"
if [ "$MODE" = "--no-changes" ]; then
  HEADING="$HEADING — no changed files (repo-wide view)"
fi

echo "$HEADING"
echo

awk -F'\t' '
BEGIN {
  w1 = length("Category");
  w2 = length("Rule");
  w3 = length("Trigger");
  n = 0;
}
NF >= 3 {
  cat = $1; rule = $2; trig = $3; ex = $4;
  if (ex == "missing") rule = rule " (missing)";
  rows[n, 1] = cat;
  rows[n, 2] = rule;
  rows[n, 3] = trig;
  if (length(cat)  > w1) w1 = length(cat);
  if (length(rule) > w2) w2 = length(rule);
  if (length(trig) > w3) w3 = length(trig);
  n++;
}
END {
  printf "| %-*s | %-*s | %-*s |\n", w1, "Category", w2, "Rule", w3, "Trigger";
  dash1 = ""; for (i = 0; i < w1; i++) dash1 = dash1 "-";
  dash2 = ""; for (i = 0; i < w2; i++) dash2 = dash2 "-";
  dash3 = ""; for (i = 0; i < w3; i++) dash3 = dash3 "-";
  printf "| %s | %s | %s |\n", dash1, dash2, dash3;
  for (i = 0; i < n; i++) {
    printf "| %-*s | %-*s | %-*s |\n", w1, rows[i,1], w2, rows[i,2], w3, rows[i,3];
  }
}
'
