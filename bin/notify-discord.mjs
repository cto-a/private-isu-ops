import https from 'https';
import zlib from 'zlib';

export async function handler(event) {
    const HOOK_URL = process.env.HookUrl;

    console.log(JSON.stringify(event));

    // SNSトピックからの連携
    if (event.Records) {
        const snsMessage = event.Records[0].Sns.Message;
        let snsText = '';
        const word = ',"input"';
        
        if (snsMessage.includes(word)) {
            snsText = snsMessage.split(word)[0] + "}}";
        } else {
            snsText = snsMessage;
        }

        const snsParsed = JSON.parse(snsText);
        let msg = {
            summary: "Alarm",
            text: snsMessage
        };

        if (snsParsed.AlarmName) {
            // Alarmのアラート
            msg.summary = snsParsed.AlarmName;
            msg.title = snsParsed.AlarmName;
        } else if (snsParsed.resources) {
            // StepFunctionのアラート
            const match = snsParsed.resources[0].match(/execution:(.+):/);
            if (match) {
                msg.summary = match[1];
                msg.title = match[1];
            }
        }

        msg.text = snsMessage;
        console.log("Sending message to Teams:", msg);
        try {
            await sendToTeams(HOOK_URL, msg);
        } catch (error) {
            console.error("Error sending message to Teams:", error);
        }
        
        console.log({
            message: snsMessage,
            status_code: 200,
            response: "Sent to Teams"
        });

    // サブスクリプションフィルターからの連携
    } else {
        // base64 デコード
        const decodedData = Buffer.from(event.awslogs.data, 'base64');
        // gzip 解凍
        const decompressedData = zlib.gunzipSync(decodedData);
        const jsonData = JSON.parse(decompressedData.toString('utf8'));

        // ロググループ取得
        const logGroup = jsonData.logGroup;
        // ログデータ取得
        const errorLogs = jsonData.logEvents;

        console.log(JSON.stringify(errorLogs));
        console.log(errorLogs.length);

        // ログ内容集約
        const messageList = createMessageList(errorLogs, 25000);

        let cnt = 1;
        for (const message of messageList) {
            let msg = {
                summary: "エラーログ通知: " + logGroup,
                title: cnt + ". エラーログ通知: " + logGroup,
                text: message
            };
            console.log("Sending message to Teams:", msg);
            try {
                await sendToTeams(HOOK_URL, msg);
            } catch (error) {
                console.error("Error sending message to Teams:", error);
            }
            cnt++;
        }

        return {
            statusCode: 200,
            body: JSON.stringify({ message: 'Notifications sent' })
        };
    }
}

function createMessageList(error_logs, max_byte) {
    let messageList = [];
    let currentMessage = "エラー内容 </br>";

    for (const log of error_logs) {
        currentMessage += log.message + "</br>";

        if (Buffer.byteLength(currentMessage, 'utf8') > max_byte) {
            currentMessage = currentMessage.slice(0, 4000);
            messageList.push(currentMessage);
            currentMessage = "エラー内容 </br>";
        }
    }
    if (currentMessage !== "エラー内容 </br>") {
        messageList.push(currentMessage);
    }

    return messageList;
}

async function sendToTeams(url, message, retryCount = 3) {
    // メッセージ内容をエスケープ
    const data = JSON.stringify(message).replace(/[\u0000-\u001F\u007F-\u009F]/g, "");

    const urlObject = new URL(url);
    const options = {
        hostname: urlObject.hostname,
        port: 443,
        path: urlObject.pathname + urlObject.search,
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(data)
        }
    };

    return new Promise((resolve, reject) => {
        const req = https.request(options, (res) => {
            let response = '';
            res.on('data', (chunk) => {
                response += chunk;
            });
            res.on('end', () => {
                if (res.statusCode >= 200) {
                    resolve(response);
                } else {
                    console.error(`Failed to send message to Teams. Status code: ${res.statusCode}`);
                    console.error(`Response: ${response}`);
                    if (retryCount > 0) {
                        console.log(`Retrying... ${retryCount} attempts left`);
                        sendToTeams(url, message, retryCount - 1).then(resolve).catch(reject);
                    } else {
                        reject(new Error(`Failed to send message to Teams. Status code: ${res.statusCode}`));
                    }
                }
            });
        });

        req.on('error', (e) => {
            if (retryCount > 0) {
                console.log(`Retrying... ${retryCount} attempts left`);
                sendToTeams(url, message, retryCount - 1).then(resolve).catch(reject);
            } else {
                reject(e);
            }
        });

        req.write(data);
        req.end();
    });
}
