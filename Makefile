build:
	docker build -t "dkdde/typo3" .

publish: build
	docker push dkdde/typo3
