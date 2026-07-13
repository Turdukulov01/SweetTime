from celery import Celery

from app.config import settings

celery_app = Celery("sweettime", broker=settings.redis_url, backend=settings.redis_url)


@celery_app.task
def send_order_push(user_id: str, title: str, body: str) -> dict[str, str]:
    return {"user_id": user_id, "title": title, "body": body, "mode": "mock"}
