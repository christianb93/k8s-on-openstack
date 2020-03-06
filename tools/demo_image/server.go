package main

import (
	"log"
	"net/http"
	"os"
)

func build_handler(msg string) func(http.ResponseWriter, *http.Request) {
	return func(writer http.ResponseWriter, request *http.Request) {
		writer.Write([]byte(msg + "\n"))
	}
}

func main() {
	msg := os.Args[1]
	http.HandleFunc("/", build_handler(msg))
	log.Fatal(http.ListenAndServe(":8888", nil))
}
