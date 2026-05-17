"""
Web push and SMS notification service.
"""


class NotificationService:
    async def send_push(self, subscription: dict, title: str, body: str):
        # TODO: Send VAPID web push
        pass

    async def send_sms(self, phone: str, message: str):
        # TODO: Send via Termii / AfricasTalking
        pass

    async def notify_reveal(self, event_id: str):
        # TODO: Fan out notifications to all guests
        pass


notifications = NotificationService()
