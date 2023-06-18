import { SQS, SendMessageCommand } from '@aws-sdk/client-sqs';
import https from 'https';
import { setTimeout } from 'timers/promises';


var sqs = new SQS({region: 'ap-northeast-1'});

export const handler = async (event) => {
  console.log(event);
  let sheetsApiUrl = process.env.GOOGLE_SHEETS_API;
  console.log("url: "+sheetsApiUrl);
  // https.get(sheetsApiUrl, function(res) {
  //       console.log("Got response: " + res.statusCode);
  //       console.log(res);
  //       console.log(res.data);
        
  //   }).on('error', function(e) {
  //       console.log(e.statusCode);
  //       //context.done('error', e);
  //   });
  const req = https.request(sheetsApiUrl, (res) => {
    console.log(`BODY: ${res}`);
    res.on('data', (chunk) => {
        console.log(`BODY: ${chunk}`);
    });
    res.on('end', () => {
        console.log('No more data in response.');
    });
  });
  await setTimeout(4000);
  console.log(req);
  let sourceIp = event.requestContext.http.sourceIp;
  let rawQueryString = event.rawQueryString;
  let val = event.queryStringParameters.val;
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
    MessageBody:
      "TESTです。",
    QueueUrl: "https://sqs.ap-northeast-1.amazonaws.com/254374927794/benchmark_queue" 
    
  };
  const command = new SendMessageCommand(params);
    let response = {
        statusCode: 200,
        body: JSON.stringify('Hello from Lambda!'),
    };

   try {
      await sqs.send(command);
      console.log("Success");
    } catch (e) {
      console.log("Error", e);
      response = {
        statusCode: 200,
        body: JSON.stringify('Error'),
    };
    }

    return response;
};