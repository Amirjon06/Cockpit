package main

import (
	"log"
	"net/http"
	"os"

	"github.com/boardwalk-ai/Cockpit/Backend/guided_generation/go_api/internal/api"
	"github.com/boardwalk-ai/Cockpit/Backend/guided_generation/go_api/internal/pythonclient"
)

func main() {
	pythonURL := os.Getenv("PYTHON_AGENT_URL")
	if pythonURL == "" {
		pythonURL = "http://localhost:8201"
	}

	client := pythonclient.New(pythonURL)
	server := api.NewServer(client)

	log.Println("guided generation Go API listening on :8200")
	if err := http.ListenAndServe(":8200", server.Handler()); err != nil {
		log.Fatal(err)
	}
}
