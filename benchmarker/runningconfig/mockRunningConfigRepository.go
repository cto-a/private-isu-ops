package runningconfig

type RunningConfigRepositoryImple struct{}

func (r *RunningConfigRepositoryImple) GetRunningConfig() (RunningConfig, error) {
	return RunningConfig{Target: "http://example.com", TeamID: 1}, nil
}
