import os
from fastapi import FastAPI, Header, HTTPException


app = FastAPI(title="NexaCommerce Inventory Service")

PORT = int(os.getenv("PORT", "8086"))

# sku -> available quantity (local dev only)
STOCK = {"nexa-hoodie": 42, "nexa-mug": 120, "nexa-keyboard": 0}


@app.get("/health/live")
def live():
    return {"status": "UP"}


@app.get("/health/ready")
def ready():
    return {"status": "UP"}


@app.get("/api/v1/inventory/{sku}")
def get_inventory(sku: str):
    if sku not in STOCK:
        raise HTTPException(status_code=404, detail="sku_not_found")
    return {"sku": sku, "available": STOCK[sku]}


@app.post("/api/v1/inventory/{sku}/reserve")
def reserve(sku: str, qty: int, x_user_id: str | None = Header(default=None)):
    _ = x_user_id  # reserved for future auth/audit
    if qty <= 0:
        raise HTTPException(status_code=400, detail="qty_must_be_positive")
    if sku not in STOCK:
        raise HTTPException(status_code=404, detail="sku_not_found")
    if STOCK[sku] < qty:
        raise HTTPException(status_code=409, detail="insufficient_stock")
    STOCK[sku] -= qty
    return {"sku": sku, "reserved": qty, "remaining": STOCK[sku]}


@app.get("/__port")
def _port():
    return {"port": PORT}

