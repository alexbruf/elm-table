.PHONY: dist dev deploy clean

dist:
	bun run build.ts

dev:
	bun run build.ts --dev

deploy: dist
	./deploy.sh

clean:
	rm -rf dist elm-stuff
