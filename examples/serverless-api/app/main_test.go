package main

import (
	"context"
	"encoding/json"
	"testing"

	"github.com/aws/aws-lambda-go/events"
)

func TestHandleEchoesRequestAndRun(t *testing.T) {
	t.Setenv("RUN_ID", "run-42")

	var req events.APIGatewayV2HTTPRequest
	req.RawPath = "/items"
	req.RequestContext.HTTP.Method = "GET"

	resp, err := handle(context.Background(), req)
	if err != nil {
		t.Fatalf("handle returned error: %v", err)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("status = %d, want 200", resp.StatusCode)
	}
	if got := resp.Headers["content-type"]; got != "application/json" {
		t.Fatalf("content-type = %q, want application/json", got)
	}

	var body Response
	if err := json.Unmarshal([]byte(resp.Body), &body); err != nil {
		t.Fatalf("body is not JSON: %v", err)
	}
	want := Response{Message: "hello from Go on AWS Lambda", Method: "GET", Path: "/items", RunID: "run-42"}
	if body != want {
		t.Fatalf("body = %+v, want %+v", body, want)
	}
}
