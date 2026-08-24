package api

import (
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/boardwalk-ai/Cockpit/Backend/guided_generation/go_api/internal/pythonclient"
)

func TestGenerateProxiesEventStream(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/agents/lucas/generate" {
			t.Fatalf("unexpected upstream path: %s", r.URL.Path)
		}
		if r.Header.Get("Accept") != "text/event-stream" {
			t.Fatalf("unexpected Accept header: %s", r.Header.Get("Accept"))
		}

		w.Header().Set("Content-Type", "text/event-stream")
		_, _ = io.WriteString(w, "event: delta\ndata: {\"text\":\"hello\"}\n\n")
		if flusher, ok := w.(http.Flusher); ok {
			flusher.Flush()
		}
		_, _ = io.WriteString(w, "event: done\ndata: {}\n\n")
	}))
	defer upstream.Close()

	server := NewServer(pythonclient.New(upstream.URL))
	request := httptest.NewRequest(
		http.MethodPost,
		"/api/guided-generation/generate",
		strings.NewReader(`{"outlines":[{}],"sources":[{}]}`),
	)
	recorder := httptest.NewRecorder()

	server.Handler().ServeHTTP(recorder, request)

	response := recorder.Result()
	defer response.Body.Close()
	body, err := io.ReadAll(response.Body)
	if err != nil {
		t.Fatal(err)
	}

	if response.StatusCode != http.StatusOK {
		t.Fatalf("unexpected status: %d", response.StatusCode)
	}
	if got := response.Header.Get("Content-Type"); got != "text/event-stream" {
		t.Fatalf("unexpected content type: %s", got)
	}
	if !strings.Contains(string(body), "event: delta") || !strings.Contains(string(body), "event: done") {
		t.Fatalf("unexpected stream body: %s", body)
	}
}
