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
    console.log(data)
    return data
}

export const handler = async (event) => {
    console.log(event)
    const sheetsApiUrl = process.env.GOOGLE_SHEETS_API
    console.log("url: " + sheetsApiUrl)
    try {
	const data = await fetchRunningDataFromGoogleSpreadSheet(sheetsApiUrl)
	console.log(data)
    } catch (e) {
	console.error(e)
	return;
    }
    const sourceIp = event.requestContext.http.sourceIp
    const rawQueryString = event.rawQueryString
    const val = event.queryStringParameters.val
    const params = {
        // DelaySeconds: 10,
        MessageAttributes: {
            sourceIp: {
                DataType: "String",
                StringValue: sourceIp,
            },
            rawQueryString: {
                DataType: "String",
                StringValue: rawQueryString,
            },
            val: {
                DataType: "String",
                StringValue: val,
            },
        },
        MessageBody: "TESTです。",
        QueueUrl: "https://sqs.ap-northeast-1.amazonaws.com/254374927794/benchmark_queue",
    }
    const command = new SendMessageCommand(params)
    let response = {
        statusCode: 200,
        body: JSON.stringify("Hello from Lambda!"),
    }

    try {
        await sqs.send(command)
        console.log("Success")
    } catch (e) {
        console.log("Error", e)
        response = {
            statusCode: 200,
            body: JSON.stringify("Error"),
        }
    }

    return response
}
