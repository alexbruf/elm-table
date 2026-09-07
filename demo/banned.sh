#!/usr/bin/env sh
# Case-insensitive check of the ViewEngine banned lexicon against the demo
# source and the built page. Prints every hit; exits non-zero if there are any.

set -u

WORDS="best-in-class world-class cutting-edge revolutionary game-changing
state-of-the-art unparalleled unmatched next-generation seamless robust
leverage unpack empower utilize foster facilitate streamline delve tapestry
testament vibrant pivotal realm embark elevate unlock harness bespoke curated
meticulous ever-evolving fast-paced myriad solutions ultimately crucial
foundational effortlessly"

PHRASES="committed to excellence|dedicated to quality|passionate about|focused on delivering|designed to meet your needs|in today's|when it comes to|it's worth noting|at its core|in a world where|at the end of the day|a testament to|plays a vital role|rich tapestry|dive into|let's dive in|game changer|keep in mind|in conclusion|to summarize|hope this helps|pro tip|here's the catch|varies significantly|varies widely|depends on several factors|a wide range of|many people wonder|it's a common question|whether you're|great question|a number of|here's the thing|after careful consideration|digital landscape|competitive landscape|seo landscape|in today's landscape"

TARGETS="src index.html dist/index.html dist/elm.js"
hits=0

for word in $WORDS; do
  for target in $TARGETS; do
    [ -e "$target" ] || continue
    if grep -rilF "$word" "$target" >/dev/null 2>&1; then
      echo "HIT word '$word' in $target"
      hits=$((hits + 1))
    fi
  done
done

for target in $TARGETS; do
  [ -e "$target" ] || continue
  if grep -riE "$PHRASES" "$target" >/dev/null 2>&1; then
    echo "HIT phrase in $target"
    hits=$((hits + 1))
  fi
done

if [ "$hits" -eq 0 ]; then
  echo "0 hits across: $TARGETS"
  exit 0
fi

echo "$hits hits"
exit 1
