package main

import (
	"log"
	"example.com/feature/internal"
)

func main() {
	deps, err := internal.BuildDependencies()
	if err != nil {
		log.Fatal(err)
	}
	_ = deps
	log.Println("feature server ready")
}
