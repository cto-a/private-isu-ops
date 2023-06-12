package runningconfig

type RunningConfigRepository interface {
	// GetRunningConfig returns the running config.
	GetRunningConfig() (RunningConfig, error)
}
