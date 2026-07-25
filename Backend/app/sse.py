"""Small helpers for Server-Sent Events.

The whole API speaks `text/event-stream`. Each message is a named event whose
`data` is JSON. Event names used across the API:

    item       one element of a collection (e.g. a studio in the list)
    data       a single full payload (e.g. one studio / topic / me)
    delta      an incremental text chunk (e.g. a token of an /ask answer)
    citations  the sources backing a streamed answer
    progress   a job progress update (ingest/build)
    ok         a write acknowledgement
    done       terminal success marker (always the last event)
    error      terminal failure marker
"""

from __future__ import annotations

import json
from typing import Any

from pydantic import BaseModel


def event(name: str, data: Any = None) -> dict[str, str]:
    """Build one SSE message dict for sse-starlette's EventSourceResponse."""
    if isinstance(data, BaseModel):
        payload = data.model_dump_json(by_alias=True)
    elif data is None:
        payload = "{}"
    else:
        payload = json.dumps(data, default=str)
    return {"event": name, "data": payload}


def done() -> dict[str, str]:
    return {"event": "done", "data": "{}"}


def error(message: str) -> dict[str, str]:
    return {"event": "error", "data": json.dumps({"message": message})}
