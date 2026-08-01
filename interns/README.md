# Interns — Assignment Board

A single, self-contained static page that shows each intern's weekly task and details.
Intended to be hosted at **interns.octopilothub.com**.

## Contents
- `index.html` — the whole page (inline CSS/JS; fonts via Google Fonts). No build step.

## What is intentionally NOT here (security)
This page contains **task details only**. It must never include:
- Database connection strings / credentials
- Firebase config
- Backend API base URLs or endpoints

Those are shared with each intern **privately over WhatsApp** — the page states this explicitly.

## Preview locally
```bash
cd interns
python -m http.server 8790
# open http://localhost:8790
```

## Hosting (interns.octopilothub.com)
Serve this folder as static files (nginx / any static host) and point the subdomain at it.
Example nginx location:
```nginx
server {
  server_name interns.octopilothub.com;
  root /var/www/interns;   # this folder
  index index.html;
}
```

## Design
- Theme: dark, core colors **red / black / white**
- Fonts: **Poppins** (display) + **Outfit** (body)
- No external JS dependencies; motion is vanilla JS (IntersectionObserver + pointer glow)

## Updating tasks
Edit the intern `<article class="card">` blocks in `index.html`. Keep credentials out.
