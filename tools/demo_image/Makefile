server:
	go build -o server

image: server
	docker build -t christianb93/demo:v0.3 .

push:
	docker login
	docker push christianb93/demo:v0.3


