package output

type OutputRepository interface {
	// GetRunningConfig returns the running config.
	SaveOutput(teamId string, output *Output) error
}
