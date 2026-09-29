// Command job is a batch job that runs to completion and exits. It stands in
// for real work (a report, a cleanup, a sync): it logs one structured line to
// stdout, which the awslogs driver ships to CloudWatch, and exits 0.
package main

import (
	"log/slog"
	"os"
	"time"
)

func run(now time.Time, env func(string) string) map[string]any {
	return map[string]any{
		"job":        "nightly",
		"run_id":     env("RUN_ID"),
		"started_at": now.UTC().Format(time.RFC3339),
	}
}

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	fields := run(time.Now(), os.Getenv)
	args := make([]any, 0, len(fields)*2)
	for k, v := range fields {
		args = append(args, k, v)
	}
	logger.Info("job finished", args...)
}
