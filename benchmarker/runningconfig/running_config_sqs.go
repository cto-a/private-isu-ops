package runningconfig

import (
	"encoding/json"
	"log"

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
	maxMessages := 1
	log.Println("SQS_URL:", r.sqsUrl)
	msgRes, err := GetMessages(r.SQS, r.sqsUrl, maxMessages)
	if err != nil {
		return RunningConfig{}, err
	}
	log.Println("msgRes:", msgRes.Messages[0].Attributes)
	log.Println("msgBody:", msgRes.Messages[0].Body)
	log.Println("msgRecepeBody:", *msgRes.Messages[0].Body)
	var item RunningConfig
	err = json.Unmarshal([]byte(*msgRes.Messages[0].Body), &item)
	if err != nil {
		log.Println("fail to Unmarshal")
		return RunningConfig{}, err
	}
	receiptHandle := msgRes.Messages[0].ReceiptHandle
	err = DeleteMessage(r.SQS, r.sqsUrl, receiptHandle)
	if err != nil {
		log.Println("fail to DeleteMessage")
		return RunningConfig{}, err
	}
	return item, nil
}
