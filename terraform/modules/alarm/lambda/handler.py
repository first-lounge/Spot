import boto3
from datetime import datetime
import json
import os
import urllib.error, urllib.request

ssm = boto3.client("ssm")
status_icon_message = {
    "ALARM": { "icon": "🚨",  "color": 15158332, "message": "위험" },
    "OK": { "icon": "✅", "color": 3066993, "message": "정상" },
    "INSUFFICIENT_DATA" : { "icon": "❔", "color": 9807270, "message": "알 수 없음" }
}

def get_webhook_url():
    response = ssm.get_parameter(
        Name=os.environ["WEBHOOK_PARAM_NAME"],
        WithDecryption=True,
    )

    return response["Parameter"]["Value"]

def handler(event, context):
    msg = json.loads(event["Records"][0]["Sns"]["Message"])
    status = status_icon_message[msg["NewStateValue"]]

    trigger = msg["Trigger"]
    caused = {"name": "원인", "value": f'{trigger["Period"] // 60 * trigger["EvaluationPeriods"]}분간 {trigger.get("DatapointsToAlarm", trigger["EvaluationPeriods"])}회', "inline": False}
    
    utc = datetime.strptime(
        msg["StateChangeTime"], 
        "%Y-%m-%dT%H:%M:%S.%f%z"
    ).isoformat()

    payload = {
        "username": "CloudWatch Alarm",
        "embeds": [
            {
                "title": msg["AlarmName"],
                "timestamp": utc,
                "color": status["color"],
                "fields": [
                    {"name": "설명", "value": msg["AlarmDescription"], "inline": False},
                    {"name": "상태", "value": f'{status["icon"]} {status["message"]}', "inline": False}
                ]
            }
        ]
    }
    
    if msg["NewStateValue"] == "ALARM":
        payload["embeds"][0]["fields"].insert(1, caused)

    headers = {
        "Content-Type": "application/json",
        "User-Agent": "spot-alarm/1.0",
    }

    # request
    url = get_webhook_url()
    data = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(url, data=data, method="POST", headers=headers)

    # response
    try:
        with urllib.request.urlopen(request, timeout=5) as response:
            print(response.status)

    except urllib.error.HTTPError as e:
        print(f'HTTP 에러: {e.code}')
        print(f'HTTP 에러 로그: {e.read().decode("UTF-8")}')
        raise
    
    except urllib.error.URLError as e:
        print(f'요청 실패: {e.reason}')
        raise