.PHONY: build preview data clean

build:
	yarn build

preview:
	yarn preview

data:
	@./scripts/download.sh
	@./scripts/build_database.sh
	@./scripts/analyze.sh

clean:
	rm -rf docs/.observable/dist
