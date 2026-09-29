package test

import "testing"

// TestLiveTestsSkipWithoutFlag pins the safety property of this package: with
// TERRATEST_LIVE unset, a live test must skip rather than touch AWS. It runs a
// throwaway subtest through requireLive and fails if that subtest was not
// skipped. CI runs this package with the flag unset, so a change that made the
// live suite run by default would fail here before it could create anything.
func TestLiveTestsSkipWithoutFlag(t *testing.T) {
	t.Setenv(liveEnv, "")

	reached := false
	var skipped bool
	t.Run("probe", func(t *testing.T) {
		defer func() { skipped = t.Skipped() }()
		requireLive(t)
		reached = true
	})

	if reached || !skipped {
		t.Fatalf("with %s unset, requireLive must skip (reached=%v skipped=%v)", liveEnv, reached, skipped)
	}
}
