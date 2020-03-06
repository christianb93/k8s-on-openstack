server:
	go build -o server

image: server
	docker build -t christianb93/kuryr-demo .

push:
	docker login
	docker push christianb93/kuryr-demo


