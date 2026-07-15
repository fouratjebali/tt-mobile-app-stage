import json
from messaging.rabbitmq import get_channel
from gmail.sender import send_email
def callback(ch, method, properties, body):
    """
    Traite les messages reçus depuis RabbitMQ.
    """
    message = json.loads(body)
    send_email(
        to=message["to"],
        subject=message["subject"],
        body=message["body"]
    )
    print(f"Email envoyé à {message['to']}")
    ch.basic_ack(delivery_tag=method.delivery_tag)
def start_consumer():
    """
    Démarre le consumer RabbitMQ.
    """
    connection, channel = get_channel()
    channel.basic_consume(
        queue="email_queue",
        on_message_callback=callback
    )
    print("En attente des messages...")

    channel.start_consuming()
