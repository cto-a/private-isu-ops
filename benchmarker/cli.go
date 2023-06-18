package main

import (
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/sqs"
	"github.com/catatsuy/private-isu/benchmarker/checker"
	"github.com/catatsuy/private-isu/benchmarker/output"
	"github.com/catatsuy/private-isu/benchmarker/runningconfig"
	"github.com/catatsuy/private-isu/benchmarker/score"
	"github.com/catatsuy/private-isu/benchmarker/util"
)

// Exit codes are int values that represent an exit code for a particular error.
const (
	ExitCodeOK    int = 0
	ExitCodeError int = 1 + iota

	FailThreshold     = 5
	InitializeTimeout = time.Duration(10) * time.Second
	BenchmarkTimeout  = 60 * time.Second
	WaitAfterTimeout  = 10 * time.Second

	PostsPerPage = 20
)

// CLI is the command line object
type CLI struct {
	// outStream and errStream are the stdout and stderr
	// to write message from the CLI.
	outStream, errStream io.Writer
}

type user struct {
	AccountName string
	Password    string
}

// Run invokes the CLI with the given arguments.
func (cli *CLI) Run(args []string) int {
	log.Println("benchmaker start!")
	// optionはlocalの環境を見ているので要相談
	sess := session.Must(session.NewSessionWithOptions(
		session.Options{
			Config: aws.Config{
				Region: aws.String("ap-northeast-1"),
			},
			Profile:           "cto-a",
			SharedConfigState: session.SharedConfigEnable,
		}),
	)

	// SQSのクライアントを作成
	sqsSvc := sqs.New(sess)

	// APP_SYNC_API_KEYが設定されているかチェック
	apiKey := os.Getenv("APP_SYNC_API_KEY")
	if apiKey == "" {
		log.Println("APP_SYNC_API_KEY is not set")
		return ExitCodeError
	}

	sqsUrl := os.Getenv("SQS_URL")
	if sqsUrl == "" {
		log.Println("SQS_URL is not set")
		return ExitCodeError
	}

	endPointUrl := os.Getenv("APP_SYNC_ENDPOINT_URL")
	if endPointUrl == "" {
		log.Println("APP_SYNC_ENDPOINT_URL is not set")
		// defaultでエンドポイントを指定しておく
		endPointUrl = "https://6bqrafkynnbbzgkticdkxuawki.appsync-api.ap-northeast-1.amazonaws.com/graphql"
	}

	var (
		target   string
		userdata string

		benchmarkTimeout time.Duration
		waitAfterTimeout time.Duration

		version          bool
		debug            bool
		runningConfig    runningconfig.RunningConfigRepository
		outputRepository output.OutputRepository
	)

	runningConfig = runningconfig.NewRunningConfigImple(sqsSvc, sqsUrl)
	outputRepository = output.NewOutputRepositoryImple(apiKey, endPointUrl)

	config, err := runningConfig.GetRunningConfig()
	if err != nil {
		fmt.Fprintf(cli.errStream, "Failed to get running config: %s\n", err)
		log.Println("Failed to get running config use Sample ip and teamID")
		config = runningconfig.RunningConfig{
			TargetAddress: "http://54.249.115.183",
			TeamID:        1,
		}
	}
	log.Println("config_file")
	log.Println(config)

	target = config.TargetAddress

	// Define option flag parse
	flags := flag.NewFlagSet(Name, flag.ContinueOnError)
	flags.SetOutput(cli.errStream)

	// targetはqueueから取得するので不要
	// flags.StringVar(&target, "target", "", "")
	// flags.StringVar(&target, "t", "", "(Short)")

	flags.StringVar(&userdata, "userdata", "", "userdata directory")
	flags.StringVar(&userdata, "u", "", "userdata directory")

	flags.DurationVar(&benchmarkTimeout, "benchmark-timeout", BenchmarkTimeout, "benchmark timeout")
	flags.DurationVar(&waitAfterTimeout, "wait-after-timeout", WaitAfterTimeout, "wait after timeout")

	flags.BoolVar(&version, "version", false, "Print version information and quit.")

	flags.BoolVar(&debug, "debug", false, "Debug mode")
	flags.BoolVar(&debug, "d", false, "Debug mode")

	// Parse commandline flag
	if err := flags.Parse(args[1:]); err != nil {
		return ExitCodeError
	}

	// Show version
	if version {
		fmt.Fprintf(cli.errStream, "%s version %s\n", Name, Version)
		return ExitCodeOK
	}

	targetHost, err := checker.SetTargetHost(target)
	if err != nil {
		output := formatResultJSON(false, []string{"主催者に連絡してください"})
		outputRepository.SaveOutput("1", &output)
		return ExitCodeError
	}

	initialize := make(chan bool)

	setupInitialize(targetHost, initialize)

	users, _, adminUsers, sentences, images, err := prepareUserdata(userdata)
	if err != nil {
		output := formatResultJSON(false, []string{"主催者に連絡してください"})
		outputRepository.SaveOutput("1", &output)
		return ExitCodeError
	}

	initReq := <-initialize

	if !initReq {
		output := formatResultJSON(false, []string{"初期化リクエストに失敗しました"})
		outputRepository.SaveOutput("1", &output)
		return ExitCodeError
	}

	// 最初にDOMチェックなどをやってしまい、通らなければさっさと失敗させる
	commentScenario(checker.NewSession(), randomUser(users), randomUser(users).AccountName, randomSentence(sentences))
	postImageScenario(checker.NewSession(), randomUser(users), randomImage(images), randomSentence(sentences))
	cannotLoginNonexistentUserScenario(checker.NewSession())
	cannotLoginWrongPasswordScenario(checker.NewSession(), randomUser(users))
	cannotAccessAdminScenario(checker.NewSession(), randomUser(users))
	cannotPostWrongCSRFTokenScenario(checker.NewSession(), randomUser(users), randomImage(images))
	loginScenario(checker.NewSession(), randomUser(users))
	banScenario(checker.NewSession(), checker.NewSession(), randomUser(users), randomUser(adminUsers), randomImage(images), randomSentence(sentences))

	if score.GetInstance().GetFails() > 0 {
		output := formatResultJSON(false, score.GetFailErrorsStringSlice())
		outputRepository.SaveOutput("1", &output)
		return ExitCodeError
	}

	indexMoreAndMoreScenarioCh := makeChanBool(2)
	loadIndexScenarioCh := makeChanBool(2)
	userAndPostPageScenarioCh := makeChanBool(2)
	commentScenarioCh := makeChanBool(1)
	postImageScenarioCh := makeChanBool(1)
	loginScenarioCh := makeChanBool(2)
	banScenarioCh := makeChanBool(1)

	timeoutCh := time.After(benchmarkTimeout)

L:
	for {
		select {
		case <-indexMoreAndMoreScenarioCh:
			go func() {
				indexMoreAndMoreScenario(checker.NewSession())
				indexMoreAndMoreScenarioCh <- true
			}()
		case <-loadIndexScenarioCh:
			go func() {
				loadIndexScenario(checker.NewSession())
				loadIndexScenarioCh <- true
			}()
		case <-userAndPostPageScenarioCh:
			go func() {
				userAndPostPageScenario(checker.NewSession(), randomUser(users).AccountName)
				userAndPostPageScenarioCh <- true
			}()
		case <-commentScenarioCh:
			go func() {
				commentScenario(checker.NewSession(), randomUser(users), randomUser(users).AccountName, randomSentence(sentences))
				commentScenarioCh <- true
			}()
		case <-postImageScenarioCh:
			go func() {
				postImageScenario(checker.NewSession(), randomUser(users), randomImage(images), randomSentence(sentences))
				cannotPostWrongCSRFTokenScenario(checker.NewSession(), randomUser(users), randomImage(images))
				postImageScenarioCh <- true
			}()
		case <-loginScenarioCh:
			go func() {
				loginScenario(checker.NewSession(), randomUser(users))
				cannotLoginNonexistentUserScenario(checker.NewSession())
				cannotLoginWrongPasswordScenario(checker.NewSession(), randomUser(users))
				loginScenarioCh <- true
			}()
		case <-banScenarioCh:
			go func() {
				banScenario(checker.NewSession(), checker.NewSession(), randomUser(users), randomUser(adminUsers), randomImage(images), randomSentence(sentences))
				cannotAccessAdminScenario(checker.NewSession(), randomUser(users))
				banScenarioCh <- true
			}()
		case <-timeoutCh:
			break L
		}
	}

	time.Sleep(waitAfterTimeout)

	var msgs []string
	if !debug {
		msgs = score.GetFailErrorsStringSlice()
	} else {
		msgs = score.GetFailRawErrorsStringSlice()
	}

	output := formatResultJSON(true, msgs)
	teamID := strconv.FormatInt(config.TeamID, 10)
	err = outputRepository.SaveOutput(teamID, &output)
	if err != nil {
		log.Println(err)
	}
	return ExitCodeOK
}

func formatResultJSON(pass bool, messages []string) output.Output {
	output := output.Output{
		Pass:     pass,
		Score:    score.GetInstance().GetScore(),
		Suceess:  score.GetInstance().GetSucesses(),
		Fail:     score.GetInstance().GetFails(),
		Messages: messages,
	}
	return output
}

func makeChanBool(len int) chan bool {
	ch := make(chan bool, len)
	for i := 0; i < len; i++ {
		ch <- true
	}
	return ch
}

func randomUser(users []user) user {
	return users[util.RandomNumber(len(users))]
}

func randomImage(images []*checker.Asset) *checker.Asset {
	return images[util.RandomNumber(len(images))]
}

func randomSentence(sentences []string) string {
	return sentences[util.RandomNumber(len(sentences))]
}

func setupInitialize(targetHost *url.URL, initialize chan bool) {
	go func(targetHost *url.URL) {
		client := &http.Client{
			Timeout: InitializeTimeout,
		}

		parsedURL := &url.URL{
			Scheme: targetHost.Scheme,
			Host:   targetHost.Host,
			Path:   "/initialize",
		}
		req, err := http.NewRequest("GET", parsedURL.String(), nil)
		if err != nil {
			return
		}

		req.Header.Set("User-Agent", checker.UserAgent)

		res, err := client.Do(req)

		if err != nil {
			initialize <- false
			return
		}
		defer res.Body.Close()
		initialize <- true
	}(targetHost)
}
