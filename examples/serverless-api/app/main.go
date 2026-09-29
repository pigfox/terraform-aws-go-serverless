// Command bootstrap is a tiny HTTP handler for AWS Lambda behind an API
// Gateway HTTP API (payload format 2.0). It answers every route with a small
// JSON document naming the path it was asked for and the run it belongs to,
// so a test can prove the response came from the deployment it just made.
package main

import (
	"context"
	"encoding/json"
	"net/http"
	"os"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
)

// Response is the JSON body returned for every request.
type Response struct {
	Message string `json:"message"`
	Method  string `json:"method"`
	Path    string `json:"path"`
	RunID   string `json:"run_id"`
}

func handle(_ context.Context, req events.APIGatewayV2HTTPRequest) (events.APIGatewayV2HTTPResponse, error) {
	body, err := json.Marshal(Response{
		Message: "hello from Go on AWS Lambda",
		Method:  req.RequestContext.HTTP.Method,
		Path:    req.RawPath,
		RunID:   os.Getenv("RUN_ID"),
	})
	if err != nil {
		return events.APIGatewayV2HTTPResponse{StatusCode: http.StatusInternalServerError}, err
	}
	return events.APIGatewayV2HTTPResponse{
		StatusCode: http.StatusOK,
		Headers:    map[string]string{"content-type": "application/json"},
		Body:       string(body),
	}, nil
}

func main() {
	lambda.Start(handle)
}
