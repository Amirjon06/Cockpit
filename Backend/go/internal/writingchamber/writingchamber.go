package writingchamber

import (
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/octopilot/cockpit-go/internal/auth"
)

type Server struct {
	db   *pgxpool.Pool
	auth *auth.Verifier
}

type Session struct {
	ID        uuid.UUID       `json:"id"`
	Title     string          `json:"title"`
	Payload   json.RawMessage `json:"payload"`
	CreatedAt time.Time       `json:"createdAt"`
	UpdatedAt time.Time       `json:"updatedAt"`
}

type saveReq struct {
	Title   string          `json:"title"`
	Payload json.RawMessage `json:"payload"`
}

func New(db *pgxpool.Pool, verifier *auth.Verifier) *Server {
	return &Server{db: db, auth: verifier}
}

func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	userID, err := s.auth.UserID(r)
	if err != nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	path := strings.Trim(strings.TrimPrefix(r.URL.Path, "/api/v1/writing-chamber"), "/")

	if path == "sessions" {
		switch r.Method {
		case http.MethodGet:
			s.list(w, r, userID)
		case http.MethodPost:
			s.create(w, r, userID)
		default:
			w.WriteHeader(http.StatusMethodNotAllowed)
		}
		return
	}

	if strings.HasPrefix(path, "sessions/") {
		raw := strings.TrimPrefix(path, "sessions/")
		id, err := uuid.Parse(raw)
		if err != nil {
			http.Error(w, "invalid session id", http.StatusBadRequest)
			return
		}

		switch r.Method {
		case http.MethodGet:
			s.get(w, r, userID, id)
		case http.MethodPut:
			s.save(w, r, userID, id)
		case http.MethodDelete:
			s.delete(w, r, userID, id)
		default:
			w.WriteHeader(http.StatusMethodNotAllowed)
		}
		return
	}

	http.NotFound(w, r)
}

func (s *Server) create(w http.ResponseWriter, r *http.Request, userID uuid.UUID) {
	var in saveReq
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		http.Error(w, "invalid body", http.StatusBadRequest)
		return
	}

	in.Title = strings.TrimSpace(in.Title)
	if in.Title == "" {
		in.Title = "Untitled"
	}
	if len(in.Payload) == 0 {
		in.Payload = json.RawMessage(`{}`)
	}

	id := uuid.New()

	row := s.db.QueryRow(
		r.Context(),
		`INSERT INTO writing_chamber_sessions
		(id, user_id, title, payload, created_at, updated_at)
		VALUES ($1, $2, $3, $4::jsonb, now(), now())
		RETURNING id, title, payload, created_at, updated_at`,
		id,
		userID,
		in.Title,
		string(in.Payload),
	)

	out, err := scan(row)
	if err != nil {
		http.Error(w, "could not create session", http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusCreated, out)
}

func (s *Server) list(w http.ResponseWriter, r *http.Request, userID uuid.UUID) {
	rows, err := s.db.Query(
		r.Context(),
		`SELECT id, title, payload, created_at, updated_at
		FROM writing_chamber_sessions
		WHERE user_id = $1
		ORDER BY updated_at DESC`,
		userID,
	)
	if err != nil {
		http.Error(w, "could not load sessions", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	out := []Session{}

	for rows.Next() {
		var item Session
		var raw []byte

		if err := rows.Scan(
			&item.ID,
			&item.Title,
			&raw,
			&item.CreatedAt,
			&item.UpdatedAt,
		); err != nil {
			http.Error(w, "could not load sessions", http.StatusInternalServerError)
			return
		}

		item.Payload = raw
		out = append(out, item)
	}

	if err := rows.Err(); err != nil {
		http.Error(w, "could not load sessions", http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusOK, out)
}

func (s *Server) get(w http.ResponseWriter, r *http.Request, userID uuid.UUID, id uuid.UUID) {
	row := s.db.QueryRow(
		r.Context(),
		`SELECT id, title, payload, created_at, updated_at
		FROM writing_chamber_sessions
		WHERE id = $1 AND user_id = $2`,
		id,
		userID,
	)

	out, err := scan(row)
	if err == pgx.ErrNoRows {
		http.NotFound(w, r)
		return
	}
	if err != nil {
		http.Error(w, "could not load session", http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusOK, out)
}

func (s *Server) save(w http.ResponseWriter, r *http.Request, userID uuid.UUID, id uuid.UUID) {
	var in saveReq
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		http.Error(w, "invalid body", http.StatusBadRequest)
		return
	}

	in.Title = strings.TrimSpace(in.Title)
	if in.Title == "" {
		in.Title = "Untitled"
	}
	if len(in.Payload) == 0 {
		in.Payload = json.RawMessage(`{}`)
	}

	row := s.db.QueryRow(
		r.Context(),
		`UPDATE writing_chamber_sessions
		SET title = $1, payload = $2::jsonb, updated_at = now()
		WHERE id = $3 AND user_id = $4
		RETURNING id, title, payload, created_at, updated_at`,
		in.Title,
		string(in.Payload),
		id,
		userID,
	)

	out, err := scan(row)
	if err == pgx.ErrNoRows {
		http.NotFound(w, r)
		return
	}
	if err != nil {
		http.Error(w, "could not save session", http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusOK, out)
}

func (s *Server) delete(w http.ResponseWriter, r *http.Request, userID uuid.UUID, id uuid.UUID) {
	tag, err := s.db.Exec(
		r.Context(),
		`DELETE FROM writing_chamber_sessions WHERE id = $1 AND user_id = $2`,
		id,
		userID,
	)
	if err != nil {
		http.Error(w, "could not delete session", http.StatusInternalServerError)
		return
	}

	if tag.RowsAffected() == 0 {
		http.NotFound(w, r)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func scan(row pgx.Row) (Session, error) {
	var out Session
	var raw []byte

	err := row.Scan(
		&out.ID,
		&out.Title,
		&raw,
		&out.CreatedAt,
		&out.UpdatedAt,
	)

	out.Payload = raw
	return out, err
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}
