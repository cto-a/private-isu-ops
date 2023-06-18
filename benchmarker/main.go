package main

import (
	"log"
	"os"
)

func main() {
	log.Println("benchmaker start!")
	cli := &CLI{outStream: os.Stdout, errStream: os.Stderr}
	log.Println("benchmaker end!")
	os.Exit(cli.Run(os.Args))
}
