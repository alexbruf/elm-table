.PHONY: check test format format-check review docs bench demo deploy clean example examples-site docs-site

check: format-check review test

test:
	elm-test

format:
	elm-format --yes src tests

format-check:
	elm-format --validate src tests

review:
	elm-review

docs:
	elm make --docs=docs.json

bench:
	$(MAKE) -C bench run

demo:
	$(MAKE) -C demo dist

deploy:
	$(MAKE) -C demo deploy

clean:
	rm -rf elm-stuff docs.json demo/dist demo/elm-stuff examples/elm-stuff bench/elm-stuff

example:
	cd examples && elm make src/Main.elm --output=/dev/null

examples-site:
	$(MAKE) -C examples-site dist

docs-site:
	$(MAKE) -C docs-site dist
