import { SQS, SendMessageCommand } from "@aws-sdk/client-sqs"
import { ECSClient, RunTaskCommand, RunTaskCommandInput } from "@aws-sdk/client-ecs"
import https from "https"
import { setTimeout } from "timers/promises"

const sqs = new SQS({ region: "ap-northeast-1" })

const client = new ECSClient({
    region: "ap-northeast-1",
})

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

/**
 * ECSのタスクを起動する
 *
 * @returns
 */
const runTask = async () => {
    const subnetIds = process.env.ECS_SUBNET_IDS ? process.env.ECS_SUBNET_IDS.split(',') : [];
    
    const input: RunTaskCommandInput = {
        cluster: process.env.ECS_CLUSTER_NAME || "benchmarker-ecs-cluster",
        taskDefinition: process.env.ECS_TASK_DEFINITION_NAME || "benchmarker-task-definition:7",
        launchType: "FARGATE",
        count: 1,
        networkConfiguration: {
            awsvpcConfiguration: {
                subnets: subnetIds,
                securityGroups: [process.env.ECS_SECURITY_GROUP_ID || ""],
                assignPublicIp: "DISABLED",
            },
        },
        capacityProviderStrategy: [
            {
                capacityProvider: "FARGATE_SPOT",
                weight: 1,
            },
            {
                capacityProvider: "FARGATE",
                weight: 1,
            },
        ],
    }
    const command = new RunTaskCommand(input)
    return await client.send(command)
}

export const handler = async (event) => {
    console.log(event)
    // 接続元IPを取得
    const sourceIp = event?.requestContext?.http?.sourceIp

    if (sourceIp === undefined) {
        return {
            statusCode: 400,
            body: JSON.stringify("Error: sourceIp is not defined"),
        }
    }

    // const { teamId } = event
    const sheetsApiUrl = process.env.GOOGLE_SHEETS_API
    const queueUrl =
        process.env.SQS_QUEUE_URL || "https://sqs.ap-northeast-1.amazonaws.com/254374927794/benchmark_queue"
    console.log("url: " + sheetsApiUrl)
    console.log("queueUrl: " + queueUrl)

    let sheetsData
    try {
        sheetsData = await fetchRunningDataFromGoogleSpreadSheet(sheetsApiUrl)
        console.log(JSON.stringify(sheetsData))
    } catch (e) {
        console.error(e)
        return
    }
    const teamList: {
        teamId: string
        teamName: string
        teamIp: string
    }[] = []
    // sheetsDataのデータからチームID、チーム名、チームIPをteamList配列に入れ直す
    sheetsData.sheets[0].data[0].rowData.forEach((data) => {
        const teamData = {
            teamId: data.values[0]?.formattedValue,
            teamName: data.values[1]?.formattedValue,
            teamIp: data.values[2]?.formattedValue,
        }
        teamList.push(teamData)
    })
    // 接続元IPのチーム名を抽出する
    const targetTeam = teamList.filter((team) => team.teamIp == sourceIp)
    // 複数あった場合は最初のものを利用する
    const targetIp = sourceIp
    const teamId = targetTeam[0]?.teamId
    const teamName = targetTeam[0]?.teamName
    if (targetIp === undefined || teamId === undefined || teamName === undefined) {
        return {
            statusCode: 500,
            body: JSON.stringify(`Error : targetIp:${targetIp} teamId:${teamId} teamName:${teamName} is undefined`),
        }
    }
    console.log("targetIp: " + targetIp)
    console.log("teamId: " + teamId)
    console.log("teamId: " + teamName)
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
            },
            teamName: {
                DataType: "String",
                StringValue: teamName,
            },
        },
        MessageBody: JSON.stringify({ team_id: parseInt(teamId), target_address: targetIp }),
        QueueUrl: queueUrl,
    }

    // SQSへ、実行したTeamIdとIPアドレスを送信する
    try {
        console.log("send message")
        const command = new SendMessageCommand(params)
        await sqs.send(command)
    } catch (e) {
        console.error("error debug")
        console.error(e)
        return {
            statusCode: 500,
            body: JSON.stringify(`Error :${e}`),
        }
    }

    // CloudTaskの起動
    try {
        console.log("run task")
        const data = await runTask()
        console.log("run task result : " + JSON.stringify(data))
    } catch (e) {
        console.error(e)
        return {
            statusCode: 500,
            body: JSON.stringify(`Error :${e}`),
        }
    }

    const response = {
        statusCode: 200,
        body: JSON.stringify("---------------benchmarker start target ip [" + targetIp + "]----------------\n"),
    }

    return response
}
