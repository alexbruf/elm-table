.PHONY: dist dev serve deploy clean

dist:
	bun run build.ts

dev:
	bun run build.ts --fast

serve: dist
	python3 -m http.server 8099 --directory dist

deploy: dist
	./deploy.sh

clean:
	rm -rf dist elm-stuff snippets/elm-stuff
