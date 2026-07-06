import { SQSClient, SendMessageCommand } from "@aws-sdk/client-sqs";

const client = new SQSClient({});
const QUEUE_URL = process.env.ORDERS_QUEUE_URL;

export async function publishOrderCreated(order) {
  if (!QUEUE_URL) {
    console.warn("ORDERS_QUEUE_URL not set — skipping SQS publish (dev mode only)");
    return;
  }

  await client.send(
    new SendMessageCommand({
      QueueUrl: QUEUE_URL,
      MessageBody: JSON.stringify({
        order_id: order.id,
        user_sub: order.user_sub,
        items: order.items,
        total: order.total,
      }),
    })
  );
}
