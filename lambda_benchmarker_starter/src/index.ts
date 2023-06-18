import { SQS, SendMessageCommand } from "@aws-sdk/client-sqs"
import https from "https"
import { setTimeout } from "timers/promises"

const sqs = new SQS({ region: "ap-northeast-1" })


/**
 * spread sheetから参加者の情報を取得する
 * 
 * @param url 
 * @returns 
 */
const fetchRunningDataFromGoogleSpreadSheet = async (url: string) => {
    const response = await fetch(url)
    const data = await response.json()
    return data
}

export const handler = async (event) => {
    console.log(event)
    const sheetsApiUrl = process.env.GOOGLE_SHEETS_API
    const queueUrl = process.env.SQS_QUEUE_URL || "https://sqs.ap-northeast-1.amazonaws.com/254374927794/benchmark_queue"
    console.log("url: " + sheetsApiUrl)
    try {
	const data = await fetchRunningDataFromGoogleSpreadSheet(sheetsApiUrl)
	console.log(JSON.stringify(data))
    } catch (e) {
	console.error(e)
	return;
    }
    const teamId = event.teamId;
    const targetIp = "http://54.249.115.183"
    console.log("teamId: " + teamId)
    const params = {
        // DelaySeconds: 10,
        MessageAttributes: {
            targetIp: {
                DataType: "String",
                StringValue: targetIp,
            },
	    teamId: {
		DataType: "Number",
		StringValue: teamId,
	    }
        },
        MessageBody: "TESTです。",
        QueueUrl: queueUrl,
    }
    try {
	console.log("send message")
	const command = new SendMessageCommand(params)
        await sqs.send(command)
    } catch(e) {
	console.error("error debug")
	console.error(e)
	return {
		statusCode: 500,
		body: JSON.stringify(`Error :${e}`),
	}
    }
    const response = {
        statusCode: 200,
        body: JSON.stringify("Hello from Lambda!"),
    }

    return response
}
