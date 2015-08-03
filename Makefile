build:
	boot2docker up
	docker build -t "dkdde/typo3" .

publish: build
	boot2docker up
	docker push dkdde/typo3
