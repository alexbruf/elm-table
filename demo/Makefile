ELM ?= elm
BUNX ?= bunx

SOURCES := $(wildcard src/*.elm) $(wildcard ../src/*.elm) $(wildcard ../src/Table/*.elm) $(wildcard ../src/Table/Internal/*.elm)

TERSER_COMPRESS := pure_funcs=[F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9],pure_getters,keep_fargs=false,unsafe_comps,unsafe

.PHONY: dist dev deploy clean

dist: dist/elm.js dist/index.html

dist/elm.js: $(SOURCES) elm.json
	mkdir -p dist
	$(ELM) make src/Main.elm --optimize --output=dist/elm.js
	$(BUNX) terser dist/elm.js --compress '$(TERSER_COMPRESS)' --mangle --output dist/elm.js

dist/index.html: index.html
	mkdir -p dist
	cp index.html dist/index.html

dev:
	mkdir -p dist
	$(ELM) make src/Main.elm --output=dist/elm.js
	cp index.html dist/index.html

deploy: dist
	./deploy.sh

clean:
	rm -rf dist elm-stuff
