package score

type ScoreRepository interface {
	// GetRunningConfig returns the running config.
	SaveScore(score *Score) error
}
