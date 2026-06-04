package main

import (
	"fmt"
	"net/http"
	"os"
	"sync"
	"time"

	"log/slog"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	// Thread-safe health status tracker
	healthyMu sync.RWMutex
	healthy   = true

	// Custom Prometheus metrics
	httpRequestsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "Total number of HTTP requests processed.",
		},
		[]string{"method", "endpoint", "status"},
	)

	httpRequestDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "http_request_duration_seconds",
			Help:    "Histogram of response latency in seconds.",
			Buckets: []float64{.005, .01, .025, .05, .1, .25, .5, 1, 2.5, 5, 10},
		},
		[]string{"method", "endpoint"},
	)
)

func init() {
	// Register custom metrics with Prometheus
	prometheus.MustRegister(httpRequestsTotal)
	prometheus.MustRegister(httpRequestDuration)
}

// Middleware to log requests and record Prometheus metrics
func instrumentedHandler(handlerName string, next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		
		// Use a custom ResponseWriter to capture status code
		wrappedWriter := &statusResponseWriter{ResponseWriter: w, statusCode: http.StatusOK}
		
		next.ServeHTTP(wrappedWriter, r)
		
		duration := time.Since(start).Seconds()
		statusStr := fmt.Sprintf("%d", wrappedWriter.statusCode)
		
		// Record metrics
		httpRequestsTotal.WithLabelValues(r.Method, handlerName, statusStr).Inc()
		httpRequestDuration.WithLabelValues(r.Method, handlerName).Observe(duration)
		
		// Structured JSON Logging using slog
		slog.Info("HTTP Request Processed",
			slog.String("method", r.Method),
			slog.String("path", r.URL.Path),
			slog.Int("status", wrappedWriter.statusCode),
			slog.Float64("duration_sec", duration),
			slog.String("remote_addr", r.RemoteAddr),
			slog.String("user_agent", r.UserAgent()),
		)
	}
}

type statusResponseWriter struct {
	http.ResponseWriter
	statusCode int
}

func (w *statusResponseWriter) WriteHeader(code int) {
	w.statusCode = code
	w.ResponseWriter.WriteHeader(code)
}

func main() {
	// Initialize slog to output JSON to stdout
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	}))
	slog.SetDefault(logger)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	appVersion := os.Getenv("APP_VERSION")
	if appVersion == "" {
		appVersion = "1.0.0"
	}

	hostname, err := os.Hostname()
	if err != nil {
		hostname = "unknown"
	}

	slog.Info("Starting Go application...",
		slog.String("version", appVersion),
		slog.String("hostname", hostname),
		slog.String("port", port),
	)

	// Define Handlers
	http.HandleFunc("/", instrumentedHandler("root", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			w.WriteHeader(http.StatusNotFound)
			fmt.Fprintf(w, "404 Not Found")
			return
		}
		
		healthyMu.RLock()
		status := "healthy"
		if !healthy {
			status = "unhealthy"
		}
		healthyMu.RUnlock()

		w.Header().Set("Content-Type", "application/json")
		fmt.Fprintf(w, `{"status": "%s", "version": "%s", "hostname": "%s", "message": "Welcome to the Self-Hosted Deployment Platform app!"}`, status, appVersion, hostname)
	}))

	http.HandleFunc("/healthz", instrumentedHandler("healthz", func(w http.ResponseWriter, r *http.Request) {
		healthyMu.RLock()
		isHealthy := healthy
		healthyMu.RUnlock()

		w.Header().Set("Content-Type", "application/json")
		if isHealthy {
			w.WriteHeader(http.StatusOK)
			fmt.Fprintf(w, `{"status": "ok"}`)
		} else {
			w.WriteHeader(http.StatusInternalServerError)
			fmt.Fprintf(w, `{"status": "error", "message": "unhealthy state triggered"}`)
		}
	}))

	http.HandleFunc("/toggle-health", instrumentedHandler("toggle-health", func(w http.ResponseWriter, r *http.Request) {
		healthyMu.Lock()
		healthy = !healthy
		currentStatus := healthy
		healthyMu.Unlock()

		slog.Warn("Application health toggled", slog.Bool("healthy", currentStatus))

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		fmt.Fprintf(w, `{"status": "success", "healthy": %t}`, currentStatus)
	}))

	http.Handle("/metrics", promhttp.Handler())

	serverAddr := ":" + port
	if err := http.ListenAndServe(serverAddr, nil); err != nil {
		slog.Error("Failed to start server", slog.String("error", err.Error()))
		os.Exit(1)
	}
}
