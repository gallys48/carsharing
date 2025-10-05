FROM python:3.12-slim
WORKDIR /app
COPY . .
RUN pip install psycopg pytest
CMD ["pytest", "-q"]