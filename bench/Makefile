ELM ?= elm

SOURCES := src/Bench.elm $(wildcard ../src/*.elm) $(wildcard ../src/Table/*.elm) $(wildcard ../src/Table/Internal/*.elm)

.PHONY: run clean

run: elm-bench.js
	node run.js

elm-bench.js: $(SOURCES) elm.json
	$(ELM) make src/Bench.elm --optimize --output=elm-bench.js

clean:
	rm -rf elm-stuff elm-bench.js
