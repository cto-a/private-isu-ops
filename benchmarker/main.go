package main

import (
	"log"
	"os"
)

func main() {
	cli := &CLI{outStream: os.Stdout, errStream: os.Stderr}
	exitCode := cli.Run(os.Args)
	log.Println("benchmaker end!")
	os.Exit(exitCode)
}
