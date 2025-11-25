.PHONY: build preview etl data clean

build:
	yarn build

preview:
	yarn preview

etl: data  # No heavy ETL step, just alias to data
data:
	@./scripts/download.sh
	@./scripts/build_database.sh
	@./scripts/analyze.sh

clean:
	rm -rf docs/.observable/dist
