package gateway

import (
	"net/http"
	"net/http/httputil"
	"net/url"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
	"github.com/octopilot/cockpit-go/internal/auth"
	"github.com/octopilot/cockpit-go/internal/config"
	"github.com/octopilot/cockpit-go/internal/writingchamber"
	"github.com/redis/go-redis/v9"
)

type Server struct {
	cfg     config.Config
	proxy   *httputil.ReverseProxy
	auth    *auth.Verifier
	cockpit *pgxpool.Pool
	rdb     *redis.Client
	minio   *minio.Client
	writing *writingchamber.Server
}

func New(cfg config.Config, cockpit *pgxpool.Pool, rdb *redis.Client, verifier *auth.Verifier) (*Server, error) {
	up, err := url.Parse(cfg.Upstream)
	if err != nil {
		return nil, err
	}
	proxy := httputil.NewSingleHostReverseProxy(up)
	proxy.FlushInterval = -1
	mc, err := minio.New(cfg.MinioEndpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.MinioAccess, cfg.MinioSecret, ""),
		Secure: cfg.MinioSecure,
	})
	if err != nil {
		return nil, err
	}
	return &Server{cfg: cfg, proxy: proxy, auth: verifier, cockpit: cockpit, rdb: rdb, minio: mc, writing: writingchamber.New(cockpit, verifier)}, nil
}

func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodOptions {
		s.setCORS(w, r)
		w.WriteHeader(http.StatusNoContent)
		return
	}
	if r.URL.Path == "/go/health" {
		s.setCORS(w, r)
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"ok":true,"role":"gateway"}`))
		return
	}
	if r.URL.Path == "/api/v1/writing-chamber" || strings.HasPrefix(r.URL.Path, "/api/v1/writing-chamber/") {
		s.setCORS(w, r)
		s.writing.ServeHTTP(w, r)
		return
	}

	s.proxy.ServeHTTP(w, r)
}

func (s *Server) setCORS(w http.ResponseWriter, r *http.Request) {
	origin := r.Header.Get("Origin")
	if origin == "" {
		return
	}
	for _, o := range strings.Split(s.cfg.CorsOrigins, ",") {
		if strings.TrimSpace(o) == origin {
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Set("Access-Control-Allow-Credentials", "true")
			w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type, X-User-Id, Accept")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS, HEAD")
			w.Header().Set("Access-Control-Max-Age", "600")
			w.Header().Add("Vary", "Origin")
			return
		}
	}
}
