FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /srv

# System deps kept minimal. build-essential is only needed if a wheel is missing.
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

# Install CPU-only torch in its OWN layer first (this is a CPU server — no GPU).
# The default torch wheel drags in ~5GB of unused NVIDIA CUDA libs. Keeping it in
# a separate layer (before requirements.txt) means editing requirements.txt does
# not re-download torch. sentence-transformers reuses this already-satisfied torch.
RUN pip install --upgrade pip \
    && pip install --index-url https://download.pytorch.org/whl/cpu torch==2.5.1

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY app ./app
COPY scripts ./scripts

EXPOSE 8100

HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
    CMD curl -fsS http://localhost:8100/health || exit 1

# Dev default (compose prod overrides with --workers and no --reload).
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8100", "--reload"]
