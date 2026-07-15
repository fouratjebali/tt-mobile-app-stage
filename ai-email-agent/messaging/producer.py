import json
import pika
from messaging.rabbitmq import get_channel
def publish_email(to: str, subject: str, body: str):
    """
    Envoie un message vers RabbitMQ.
    """
    connection, channel = get_channel()
    message = {
        "to": to,
        "subject": subject,
        "body": body
    }
    channel.basic_publish(
        exchange="",
        routing_key="email_queue",
        body=json.dumps(message),
        properties=pika.BasicProperties(
            delivery_mode=2
        )
    )
    connection.close()
