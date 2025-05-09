import json
import urllib3
import os

http = urllib3.PoolManager()
SLACK_WEBHOOK_URL = os.environ['SLACK_WEBHOOK_URL']
slack_user_id = os.environ.get("SLACK_MENTIONS", "").split(",") # e.g., "<@U12345678>"
MENTION_NAMES = [f"<@{m.strip()}>" for m in slack_user_id]

def send_to_slack(event, context):
    for record in event['Records']:
        sns_message = json.loads(record['Sns']['Message'])

        alarm_name = sns_message.get('AlarmName', 'Unknown Alarm')
        new_state = sns_message.get('NewStateValue', 'N/A')
        reason = sns_message.get('NewStateReason', 'No reason provided')
        region = sns_message.get('Region', 'N/A')
        time = sns_message.get('StateChangeTime', 'N/A')
        alarm_arn = sns_message.get('AlarmArn', '')

        # Construct AWS Console link
        alarm_url = f"https://console.aws.amazon.com/cloudwatch/home?region={region}#alarmsV2:alarm/{alarm_name}"

        slack_message = {
            "blocks": [
                {
                    "type": "header",
                    "text": {
                        "type": "plain_text",
                        "text": ":rotating_light: CloudWatch Alarm Triggered",
                        "emoji": True
                    }
                },
                {
                    "type": "section",
                    "fields": [
                        {"type": "mrkdwn", "text": f"*Alarm Name:*\n{alarm_name}"},
                        {"type": "mrkdwn", "text": f"*State:*\n{new_state}"},
                        {"type": "mrkdwn", "text": f"*Region:*\n{region}"},
                        {"type": "mrkdwn", "text": f"*Time:*\n{time}"}
                    ]
                },
                {
                    "type": "section",
                    "text": {"type": "mrkdwn", "text": f"*Reason:*\n{reason}"}
                },
                {
                    "type": "actions",
                    "elements": [
                        {
                            "type": "button",
                            "text": {"type": "plain_text", "text": "View in CloudWatch"},
                            "url": alarm_url
                        }
                    ]
                },
                {
                    "type": "context",
                    "elements": [
                        {"type": "mrkdwn", "text": " ".join(MENTION_NAMES)}
                    ]
                }
            ]
        }

        response = http.request(
            'POST',
            SLACK_WEBHOOK_URL,
            body=json.dumps(slack_message),
            headers={'Content-Type': 'application/json'}
        )

        if response.status != 200:
            raise Exception(f"Slack notification failed: {response.status}")

    return {
        'statusCode': 200,
        'body': json.dumps('Alarm sent to Slack.')
    }
