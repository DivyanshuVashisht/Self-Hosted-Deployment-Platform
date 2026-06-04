# Self-Hosted Deployment Platform Local Setup Script
$ErrorActionPreference = "Stop"

# Helper function to refresh PATH environment variable in current session
function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

Refresh-Path

# 1. Verify/Install dependencies
Write-Host "=== Step 1: Checking Dependencies ===" -ForegroundColor Cyan

# Check Helm
$hasHelm = Get-Command helm -ErrorAction SilentlyContinue
if (-not $hasHelm) {
    Write-Host "Helm is not installed. Attempting to install via winget..." -ForegroundColor Yellow
    try {
        winget install -e --id Helm.Helm --accept-source-agreements --accept-package-agreements
        Refresh-Path
        $hasHelm = Get-Command helm -ErrorAction SilentlyContinue
        if (-not $hasHelm) {
            # Try Chocolatey as fallback
            if (Get-Command choco -ErrorAction SilentlyContinue) {
                Write-Host "Falling back to choco..." -ForegroundColor Yellow
                choco install kubernetes-helm -y
                Refresh-Path
            }
        }
    } catch {
        Write-Host "Failed to automatically install Helm. Please install it manually from https://helm.sh/" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Helm is already installed: $(helm version --short)" -ForegroundColor Green
}

# Check K3d
$hasK3d = Get-Command k3d -ErrorAction SilentlyContinue
if (-not $hasK3d) {
    Write-Host "K3d is not installed. Attempting to install via winget..." -ForegroundColor Yellow
    try {
        winget install -e --id k3d.k3d --accept-source-agreements --accept-package-agreements
        Refresh-Path
        $hasK3d = Get-Command k3d -ErrorAction SilentlyContinue
        if (-not $hasK3d) {
            # Try Chocolatey as fallback
            if (Get-Command choco -ErrorAction SilentlyContinue) {
                Write-Host "Falling back to choco..." -ForegroundColor Yellow
                choco install k3d -y
                Refresh-Path
            }
        }
    } catch {
        Write-Host "Failed to automatically install K3d. Please install it manually from https://k3d.io/" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "K3d is already installed: $(k3d --version)" -ForegroundColor Green
}

# Double check dependencies are available in path
$hasHelm = Get-Command helm -ErrorAction SilentlyContinue
$hasK3d = Get-Command k3d -ErrorAction SilentlyContinue
if (-not $hasHelm -or -not $hasK3d) {
    Write-Host "Error: helm or k3d is still not found in system PATH. Please restart your terminal and run setup.ps1 again." -ForegroundColor Red
    exit 1
}

# 2. Spin up K3d cluster using config
Write-Host "`n=== Step 2: Provisioning K3d Cluster ===" -ForegroundColor Cyan
$clusterList = k3d cluster list self-hosted-cluster -o json | ConvertFrom-Json
$clusterExists = $false
if ($clusterList) {
    if ($clusterList.name -eq "self-hosted-cluster") {
        $clusterExists = $true
    }
}

if (-not $clusterExists) {
    Write-Host "Creating K3d cluster 'self-hosted-cluster' using k3d-config.yaml..." -ForegroundColor Yellow
    k3d cluster create --config k3d-config.yaml
} else {
    Write-Host "Cluster 'self-hosted-cluster' already exists. Starting it if stopped..." -ForegroundColor Green
    k3d cluster start self-hosted-cluster
}

# 3. Build Docker image
Write-Host "`n=== Step 3: Building Application Docker Image ===" -ForegroundColor Cyan
Write-Host "Running: docker build -t self-hosted-app:latest -f ./src/Dockerfile ./src" -ForegroundColor Gray
docker build -t self-hosted-app:latest -f ./src/Dockerfile ./src

# 4. Import Docker image into K3d
Write-Host "`n=== Step 4: Loading Image into Cluster ===" -ForegroundColor Cyan
Write-Host "Running: k3d image import self-hosted-app:latest -c self-hosted-cluster" -ForegroundColor Gray
k3d image import self-hosted-app:latest -c self-hosted-cluster

# 5. Deploy Helm Chart
Write-Host "`n=== Step 5: Deploying Application via Helm ===" -ForegroundColor Cyan
Write-Host "Upgrading/Installing Helm release 'self-hosted-app' in namespace 'self-hosted-platform'..." -ForegroundColor Yellow
helm upgrade --install self-hosted-app ./charts/self-hosted-app `
  --namespace self-hosted-platform --create-namespace `
  --values ./charts/self-hosted-app/values.yaml

# 6. Verify deployment
Write-Host "`n=== Step 6: Verifying Deployment Rollout ===" -ForegroundColor Cyan
kubectl rollout status deployment/self-hosted-app -n self-hosted-platform

Write-Host "`n==================================================" -ForegroundColor Green
Write-Host "Deployment Completed Successfully!" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host "Please ensure you have mapped the hostname locally by adding this line:" -ForegroundColor Yellow
Write-Host "  127.0.0.1 self-hosted-app.local" -ForegroundColor Green
Write-Host "to your hosts file at: C:\Windows\System32\drivers\etc\hosts" -ForegroundColor Yellow
Write-Host "`nOnce done, you can access the application at:" -ForegroundColor Yellow
Write-Host "  http://self-hosted-app.local:8082/" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
