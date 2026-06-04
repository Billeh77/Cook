FROM python:3.12-slim

WORKDIR /app

# Install uv
RUN pip install --no-cache-dir uv

# Copy dependency files first (layer caching)
COPY pyproject.toml uv.lock ./

# Install production dependencies
RUN uv sync --frozen --no-dev

# Install Playwright's Chromium browser + all required OS-level system deps.
# Placed here (after uv sync, before COPY app/) so Chromium is a cached layer
# and won't be re-downloaded on every code change.
RUN uv run playwright install --with-deps chromium

# Copy application code and migrations
COPY app/ ./app/
COPY alembic/ ./alembic/
COPY alembic.ini ./

# Railway injects $PORT at runtime
EXPOSE 8000

# Run migrations then start server
CMD uv run alembic upgrade head && \
    uv run uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}
