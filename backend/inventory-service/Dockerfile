# ============================================================
# Inventory Service — Dockerfile (Python / FastAPI)
# ============================================================

FROM python:3.12-slim AS base

WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8086

FROM base AS development
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8086", "--reload"]

FROM base AS production
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8086"]

