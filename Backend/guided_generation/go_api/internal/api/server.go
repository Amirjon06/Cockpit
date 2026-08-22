package api

import (
	"encoding/json"
	"io"
	"net/http"

	"github.com/boardwalk-ai/Cockpit/Backend/guided_generation/go_api/internal/pythonclient"
)

type Server struct {
	python *pythonclient.Client
}

func NewServer(python *pythonclient.Client) *Server {
	return &Server{python: python}
}

func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("GET /health", s.health)
	mux.HandleFunc("POST /api/guided-generation/analyze", s.analyze)
	mux.HandleFunc("POST /api/guided-generation/outlines", s.outlines)

	return mux
}

func (s *Server) health(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{
		"status":  "ok",
		"service": "guided-generation-go-api",
	})
}

func (s *Server) analyze(w http.ResponseWriter, r *http.Request) {
	s.forward(w, r, "/agents/hein/analyze")
}

func (s *Server) outlines(w http.ResponseWriter, r *http.Request) {
	s.forward(w, r, "/agents/lily/generate")
}

func (s *Server) forward(w http.ResponseWriter, r *http.Request, path string) {
	body, err := io.ReadAll(r.Body)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid request body"})
		return
	}

	data, status, err := s.python.Post(r.Context(), path, body)
	if err != nil && status == 0 {
		writeJSON(w, http.StatusBadGateway, map[string]string{"error": "agent service unavailable"})
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_, _ = w.Write(data)
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}
