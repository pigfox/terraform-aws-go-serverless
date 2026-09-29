// Package test holds the live end-to-end suite. It creates real, billable AWS
// resources, so every test is skipped unless TERRATEST_LIVE=1 is set; the
// mocked `terraform test` suite under tests/ is the one that runs on every
// change.
//
//	TERRATEST_LIVE=1 AWS_REGION=us-east-1 go test -v -timeout 30m ./...
//
// TERRATEST_TF_BINARY=tofu runs the same test with OpenTofu.
package test

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	awsconfig "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/iam"
	iamtypes "github.com/aws/aws-sdk-go-v2/service/iam/types"
	"github.com/aws/aws-sdk-go-v2/service/resourcegroupstaggingapi"
	taggingtypes "github.com/aws/aws-sdk-go-v2/service/resourcegroupstaggingapi/types"
	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

const (
	liveEnv     = "TERRATEST_LIVE"
	exampleDir  = "../examples/serverless-api"
	wantMessage = "hello from Go on AWS Lambda"

	// The tagging API is eventually consistent: a resource deleted a moment
	// ago can still be listed. Poll this long before calling it a leftover.
	leftoverDeadline = 5 * time.Minute
	leftoverPoll     = 15 * time.Second
)

// response mirrors the JSON the example handler returns.
type response struct {
	Message string `json:"message"`
	Method  string `json:"method"`
	Path    string `json:"path"`
	RunID   string `json:"run_id"`
}

// requireLive skips the calling test unless live runs were asked for.
func requireLive(t *testing.T) {
	t.Helper()
	if os.Getenv(liveEnv) != "1" {
		t.Skipf("set %s=1 to run: this test creates real AWS resources and costs money", liveEnv)
	}
}

func region() string {
	if r := os.Getenv("AWS_REGION"); r != "" {
		return r
	}
	return "us-east-1"
}

func tfBinary() string {
	if b := os.Getenv("TERRATEST_TF_BINARY"); b != "" {
		return b
	}
	return "terraform"
}

// TestServerlessAPI applies examples/serverless-api, calls the endpoint and
// checks the response came from this deployment, destroys everything, then
// fails if anything tagged with this run's run_id is still there.
func TestServerlessAPI(t *testing.T) {
	requireLive(t)

	runID := "tt-" + strings.ToLower(random.UniqueId())
	name := "go-serverless-" + runID

	shell.RunCommand(t, shell.Command{Command: "./build.sh", WorkingDir: exampleDir})

	opts := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir:    exampleDir,
		TerraformBinary: tfBinary(),
		Vars: map[string]any{
			"region": region(),
			"name":   name,
			"run_id": runID,
		},
		NoColor: true,
	})

	// Cleanups run last-registered first: destroy, then the leftover check.
	t.Cleanup(func() { assertNothingLeft(t, runID, name) })
	t.Cleanup(func() { terraform.Destroy(t, opts) })

	terraform.InitAndApply(t, opts)

	endpoint := terraform.Output(t, opts, "api_endpoint")
	url := strings.TrimRight(endpoint, "/") + "/hello"

	// A fresh stage can answer 404 or 5xx for a few seconds; retry until 200.
	var body string
	http_helper.HttpGetWithRetryWithCustomValidation(t, url, nil, 30, 5*time.Second, func(status int, b string) bool {
		body = b
		return status == http.StatusOK
	})

	var got response
	if err := json.Unmarshal([]byte(body), &got); err != nil {
		t.Fatalf("response is not JSON: %v\nbody: %s", err, body)
	}
	want := response{Message: wantMessage, Method: "GET", Path: "/hello", RunID: runID}
	if got != want {
		t.Fatalf("response = %+v, want %+v", got, want)
	}
}

// assertNothingLeft fails the test if any resource tagged run_id=<runID>
// survives the destroy. The tagging API does not index IAM roles, so the
// function's role is checked directly as well.
func assertNothingLeft(t *testing.T, runID, name string) {
	t.Helper()
	ctx := context.Background()

	cfg, err := awsconfig.LoadDefaultConfig(ctx, awsconfig.WithRegion(region()))
	if err != nil {
		t.Fatalf("load AWS config for the leftover check: %v", err)
	}

	tagging := resourcegroupstaggingapi.NewFromConfig(cfg)
	deadline := time.Now().Add(leftoverDeadline)
	var remaining []string
	for {
		remaining, err = taggedResources(ctx, tagging, runID)
		if err != nil {
			t.Fatalf("query the tagging API for run_id=%s: %v", runID, err)
		}
		if len(remaining) == 0 || time.Now().After(deadline) {
			break
		}
		time.Sleep(leftoverPoll)
	}
	if len(remaining) > 0 {
		t.Errorf("%d resource(s) tagged run_id=%s remain after destroy:\n  %s",
			len(remaining), runID, strings.Join(remaining, "\n  "))
	}

	roleName := name + "-lambda"
	_, err = iam.NewFromConfig(cfg).GetRole(ctx, &iam.GetRoleInput{RoleName: aws.String(roleName)})
	var notFound *iamtypes.NoSuchEntityException
	switch {
	case errors.As(err, &notFound):
		// Gone, as it should be.
	case err == nil:
		t.Errorf("IAM role %s remains after destroy", roleName)
	default:
		t.Fatalf("check IAM role %s: %v", roleName, err)
	}
}

func taggedResources(ctx context.Context, c *resourcegroupstaggingapi.Client, runID string) ([]string, error) {
	var arns []string
	p := resourcegroupstaggingapi.NewGetResourcesPaginator(c, &resourcegroupstaggingapi.GetResourcesInput{
		TagFilters: []taggingtypes.TagFilter{{Key: aws.String("run_id"), Values: []string{runID}}},
	})
	for p.HasMorePages() {
		page, err := p.NextPage(ctx)
		if err != nil {
			return nil, fmt.Errorf("GetResources: %w", err)
		}
		for _, m := range page.ResourceTagMappingList {
			arns = append(arns, aws.ToString(m.ResourceARN))
		}
	}
	return arns, nil
}
