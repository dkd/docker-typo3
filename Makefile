build:
	docker build -t "dkdde/typo3" .

publish: build
	docker push dkdde/typo3

buildcompose:
	docker-compose stop
	docker-compose rm --all
	docker-compose build
	docker-compose up
