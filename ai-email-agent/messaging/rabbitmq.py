import pika
def get_rabbitmq_connection():
    """
    Cree et retourne une connexion RabbitMQ.
    """
    connection = pika.BlockingConnection(
        pika.ConnectionParameters(host="localhost")
    )
    return connection
def get_channel():
    """
    Retourne un channel RabbitMQ et cree la queue si elle n'existe pas.
    """
    connection = get_rabbitmq_connection()
    channel = connection.channel()

    channel.queue_declare(queue="email_queue", durable=True)

    return connection, channel
