from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

router = APIRouter()


class PaymentInitBody(BaseModel):
    event_id: str
    provider: str
    tier: str
    currency: str = "NGN"


@router.post("/{provider}/init")
async def init_payment(provider: str, body: PaymentInitBody):
    if provider not in ("paystack", "flutterwave", "stripe"):
        raise HTTPException(status_code=400, detail="Unsupported provider")

    # TODO: Call provider API to initialize payment
    return {
        "checkout_url": f"https://checkout.{provider}.com/placeholder",
        "reference": f"mora-{body.event_id}",
    }


@router.post("/webhook/{provider}")
async def payment_webhook(provider: str):
    # TODO: Verify signature, update payment status, upgrade event tier
    return {"message": "Webhook received"}
