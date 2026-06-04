package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestRootHandler(t *testing.T) {
	req, err := http.NewRequest("GET", "/", nil)
	if err != nil {
		t.Fatal(err)
	}

	rr := httptest.NewRecorder()
	handler := instrumentedHandler("root", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprintf(w, `{"status": "healthy", "version": "1.0.0", "hostname": "test-host"}`)
	})

	handler.ServeHTTP(rr, req)

	if status := rr.Code; status != http.StatusOK {
		t.Errorf("handler returned wrong status code: got %v want %v", status, http.StatusOK)
	}

	var response map[string]interface{}
	err = json.Unmarshal(rr.Body.Bytes(), &response)
	if err != nil {
		t.Fatalf("failed to parse response body: %v", err)
	}

	if response["status"] != "healthy" {
		t.Errorf("expected status 'healthy', got %v", response["status"])
	}
}

func TestHealthzHandler(t *testing.T) {
	// Set initial state
	healthyMu.Lock()
	healthy = true
	healthyMu.Unlock()

	req, err := http.NewRequest("GET", "/healthz", nil)
	if err != nil {
		t.Fatal(err)
	}

	// Test Healthy
	rr := httptest.NewRecorder()
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		healthyMu.RLock()
		isHealthy := healthy
		healthyMu.RUnlock()
		if isHealthy {
			w.WriteHeader(http.StatusOK)
			w.Write([]byte(`{"status": "ok"}`))
		} else {
			w.WriteHeader(http.StatusInternalServerError)
			w.Write([]byte(`{"status": "error"}`))
		}
	})

	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("expected 200 OK for healthy state, got %d", rr.Code)
	}

	// Set Unhealthy
	healthyMu.Lock()
	healthy = false
	healthyMu.Unlock()

	rr2 := httptest.NewRecorder()
	handler.ServeHTTP(rr2, req)

	if rr2.Code != http.StatusInternalServerError {
		t.Errorf("expected 500 Internal Server Error for unhealthy state, got %d", rr2.Code)
	}

	// Restore state
	healthyMu.Lock()
	healthy = true
	healthyMu.Unlock()
}

func TestToggleHealth(t *testing.T) {
	healthyMu.Lock()
	healthy = true
	healthyMu.Unlock()

	req, err := http.NewRequest("POST", "/toggle-health", nil)
	if err != nil {
		t.Fatal(err)
	}

	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		healthyMu.Lock()
		healthy = !healthy
		currentStatus := healthy
		healthyMu.Unlock()
		w.WriteHeader(http.StatusOK)
		fmt.Fprintf(w, `{"status": "success", "healthy": %t}`, currentStatus)
	})

	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("expected 200 OK, got %d", rr.Code)
	}

	var response map[string]interface{}
	json.Unmarshal(rr.Body.Bytes(), &response)

	if response["healthy"] != false {
		t.Errorf("expected healthy to toggle to false, got %v", response["healthy"])
	}

	// Toggle back
	rr2 := httptest.NewRecorder()
	handler.ServeHTTP(rr2, req)
	json.Unmarshal(rr2.Body.Bytes(), &response)

	if response["healthy"] != true {
		t.Errorf("expected healthy to toggle back to true, got %v", response["healthy"])
	}
}
