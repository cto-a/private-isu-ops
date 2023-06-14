package output

import (
	"bytes"
	"io/ioutil"
	"log"
	"net/http"
	"strconv"
	"time"
)

type OutputRepositoryImple struct {
	apiKey string
	url    string
}

func NewOutputRepositoryImple(apiKey string, url string) OutputRepository {
	return &OutputRepositoryImple{apiKey: apiKey, url: url}
}

func (r *OutputRepositoryImple) SaveOutput(teamId string, output *Output) error {
	url := r.url

	scoreData := strconv.FormatInt(output.Score, 10)
	successData := strconv.FormatInt(output.Suceess, 10)
	failsData := strconv.FormatInt(output.Fail, 10)
	now := time.Now().Unix()
	nowStr := strconv.FormatInt(now, 10)

	// 一旦GQLクライアントを利用せずに文字列で組み立て
	str := `{
		"query": "mutation { updateTeamScore(team_id: ` + teamId + `, pass: true, score: ` + scoreData + ` success: ` + successData + `, fail: ` + failsData + `, messages: [\"` + output.Messages[0] + `\"], timestamp: ` + nowStr + `) { team_id pass score success fail messages timestamp } }"
	}`
	log.Println(str)
	jsonData := []byte(str)

	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return err
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("x-api-key", r.apiKey)

	client := &http.Client{}

	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return err
	}

	log.Println("response:", string(body))
	return nil
}
