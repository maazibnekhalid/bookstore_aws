import json
import logging
import os

import boto3
import pymysql

logger = logging.getLogger()
logger.setLevel(logging.INFO)

_secrets_client = boto3.client("secretsmanager")
_db_password = None  # cached across warm invocations


def _get_db_password():
    global _db_password
    if _db_password is None:
        secret_arn = os.environ["DB_SECRET_ARN"]
        value = _secrets_client.get_secret_value(SecretId=secret_arn)
        _db_password = json.loads(value["SecretString"])["password"]
    return _db_password


def _get_connection():
    return pymysql.connect(
        host=os.environ["DB_HOST"],
        user=os.environ["DB_USER"],
        password=_get_db_password(),
        database=os.environ["DB_NAME"],
        connect_timeout=5,
        autocommit=True,
    )


def handler(event, context):
    """
    Triggered by SQS (Orders Queue). Each record is one order-created message
    published by the Order Service. Marks the order PROCESSED in Aurora.
    """
    conn = None
    processed = 0

    for record in event.get("Records", []):
        body = record.get("body")
        try:
            order = json.loads(body)
        except (TypeError, json.JSONDecodeError):
            logger.error("Could not parse order message body: %s", body)
            continue

        order_id = order.get("order_id")
        if not order_id:
            logger.error("Order message missing order_id: %s", order)
            continue

        try:
            if conn is None:
                conn = _get_connection()
            with conn.cursor() as cur:
                cur.execute(
                    "UPDATE orders SET status = %s WHERE id = %s",
                    ("PROCESSED", order_id),
                )
            logger.info("Order %s marked PROCESSED", order_id)
            processed += 1
        except Exception:
            logger.exception("Failed to process order %s", order_id)
            raise  # let SQS retry / eventually route to the DLQ

    if conn:
        conn.close()

    return {"statusCode": 200, "body": f"processed {processed} order(s)"}
