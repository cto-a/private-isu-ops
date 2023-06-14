package runningconfig

import (
	"encoding/json"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/service/sqs"
)

type RunningConfigRepositoryImple struct {
	SQS    *sqs.SQS
	sqsUrl string
}

func NewRunningConfigImple(sqs *sqs.SQS, sqsUrl string) RunningConfigRepository {
	return &RunningConfigRepositoryImple{SQS: sqs, sqsUrl: sqsUrl}
}

func DeleteMessage(s *sqs.SQS, queueUrl string, messageHandle *string) error {
	_, err := s.DeleteMessage(&sqs.DeleteMessageInput{
		QueueUrl:      &queueUrl,
		ReceiptHandle: messageHandle,
	})
	return err
}

func GetMessages(s *sqs.SQS, queueUrl string, maxMessages int) (*sqs.ReceiveMessageOutput, error) {
	msgResult, err := s.ReceiveMessage(&sqs.ReceiveMessageInput{
		QueueUrl:            &queueUrl,
		MaxNumberOfMessages: aws.Int64(1),
	})

	if err != nil {
		return nil, err
	}

	return msgResult, nil
}

// delete queueは別で分けてもいいが一旦雑に同一関数に実装
func (r *RunningConfigRepositoryImple) GetRunningConfig() (RunningConfig, error) {
	// デバッグ用
	// msgJson, err := json.Marshal(RunningConfig{
	// 	TargetAddress: "http://example.com",
	// 	TeamID:        1,
	// })
	// if err != nil {
	// 	return RunningConfig{}, err
	// }
	// _, err = r.SQS.SendMessage(&sqs.SendMessageInput{
	// 	MessageBody: aws.String(string(msgJson)),
	// 	QueueUrl:    &r.sqsUrl,
	// })
	// if err != nil {
	// 	return RunningConfig{}, err
	// }

	maxMessages := 1
	msgRes, err := GetMessages(r.SQS, r.sqsUrl, maxMessages)
	if err != nil {
		return RunningConfig{}, err
	}
	var item RunningConfig
	err = json.Unmarshal([]byte(*msgRes.Messages[0].Body), &item)
	if err != nil {
		return RunningConfig{}, err
	}
	receiptHandle := msgRes.Messages[0].ReceiptHandle
	err = DeleteMessage(r.SQS, r.sqsUrl, receiptHandle)
	if err != nil {
		return RunningConfig{}, err
	}
	return item, nil
}
