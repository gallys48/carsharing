FROM python:3.12-slim

WORKDIR /app

RUN pip install --no-cache-dir psycopg[binary] pytest

COPY tests/ tests/

CMD ["sh", "-c", "sleep 5 && pytest tests/"]