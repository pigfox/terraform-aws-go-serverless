package main

import (
	"testing"
	"time"
)

func TestRunReportsRunAndStartTime(t *testing.T) {
	now := time.Date(2026, 1, 2, 3, 4, 5, 0, time.FixedZone("x", 3600))
	env := func(k string) string {
		if k == "RUN_ID" {
			return "run-7"
		}
		return ""
	}

	got := run(now, env)

	if got["run_id"] != "run-7" {
		t.Fatalf("run_id = %v, want run-7", got["run_id"])
	}
	if got["started_at"] != "2026-01-02T02:04:05Z" {
		t.Fatalf("started_at = %v, want the time in UTC", got["started_at"])
	}
}
