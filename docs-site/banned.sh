#!/usr/bin/env sh
# Greps content/ and dist/ for the ViewEngine banned words and phrases
# (reports/design-rules.md). Exits non-zero on a hit.

set -e

WORDS='best-in-class|world-class|cutting-edge|revolutionary|game-changing|state-of-the-art|unparalleled|unmatched|next-generation|seamless|robust|leverage|unpack|empower|utilize|foster|facilitate|streamline|delve|tapestry|testament|vibrant|pivotal|realm|embark|elevate|unlock|harness|bespoke|curated|meticulous|ever-evolving|fast-paced|myriad|solutions|ultimately|crucial|foundational|effortlessly'

PHRASES="committed to excellence|dedicated to quality|passionate about|focused on delivering|designed to meet your needs|in today's|when it comes to|it's worth noting|at its core|in a world where|at the end of the day|a testament to|plays a vital role|rich tapestry|dive into|let's dive in|game changer|keep in mind|in conclusion|to summarize|hope this helps|pro tip|here's the catch|varies significantly|varies widely|depends on several factors|a wide range of|many people wonder|it's a common question|whether you're|great question|a number of|here's the thing|after careful consideration|digital landscape|competitive landscape|seo landscape|in today's landscape"

hits=0

for dir in content dist shared README.md; do
  [ -e "$dir" ] || continue
  if grep -rniE "\\b($WORDS)\\b" "$dir" >/tmp/banned-words.txt 2>/dev/null; then
    if [ -s /tmp/banned-words.txt ]; then
      echo "banned words in $dir:"
      cat /tmp/banned-words.txt
      hits=1
    fi
  fi
  if grep -rniE "($PHRASES)" "$dir" >/tmp/banned-phrases.txt 2>/dev/null; then
    if [ -s /tmp/banned-phrases.txt ]; then
      echo "banned phrases in $dir:"
      cat /tmp/banned-phrases.txt
      hits=1
    fi
  fi
done

rm -f /tmp/banned-words.txt /tmp/banned-phrases.txt

if [ "$hits" -ne 0 ]; then
  exit 1
fi

echo "banned-word check: 0 hits"
