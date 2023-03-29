param (
    [string]$configFilePath = "code-environment.project.json"
)

function Invoke-Git {
    param ([ScriptBlock]$Command)
    $Host.UI.RawUI.ForegroundColor = 'Yellow'
    & $Command 2>&1
    $Host.UI.RawUI.ForegroundColor = $initialForegroundColor
}

$initialForegroundColor = $Host.UI.RawUI.ForegroundColor

# Load configuration file
Write-Host "Loading configuration file..."
if (!(Test-Path -Path $configFilePath)) {
    Write-Error "Configuration file not found: $configFilePath"
    exit 1
}
$config = Get-Content -Path $configFilePath | ConvertFrom-Json

# Create root directory if it doesn't exist
$root = $config.root
if (!(Test-Path -Path $root)) {
    Write-Host "Creating root directory: $root"
    New-Item -Path $root -ItemType Directory | Out-Null
}

# Iterate through workspaces
foreach ($workspace in $config.workspaces) {
    Write-Host "Configuring workspace: $($workspace.workspace)"
    $workspacePath = Join-Path -Path $root -ChildPath $workspace.workspace

    if (!(Test-Path -Path $workspacePath)) {
        Write-Host "Creating workspace directory: $workspacePath"
        New-Item -Path $workspacePath -ItemType Directory | Out-Null
    }

    # Iterate through repositories
    foreach ($repo in $workspace.repositories) {
        Write-Host "Configuring repository: $($repo.name)"
        $repoPath = Join-Path -Path $workspacePath -ChildPath $repo.name

        # Clone the repo if it doesn't exist locally
        if (!(Test-Path -Path $repoPath)) {
            Write-Host "Cloning repository: $($repo.origin)"
            Invoke-Git { git clone $repo.origin $repoPath }
        }

        # Move to the repo directory
        Push-Location $repoPath

        # Check for uncommitted changes and stash them if present
        $hasChanges = (git status --porcelain) -ne ''
        if ($hasChanges) {
            Write-Host "Uncommitted changes found, stashing changes..."
            Invoke-Git { git stash save "sync-stash" }
        }

        # Sync branches
        foreach ($branch in $repo.branches.sync) {
            Write-Host "Syncing branch: $branch"
            Invoke-Git { git checkout $branch }
            Invoke-Git { git pull origin $branch }
        }

        # Checkout the default branch
        Invoke-Git { git checkout $repo.branches.default }

        # Unstash changes if there were any
        if ($hasChanges) {
            Write-Host "Unstashing changes..."
            Invoke-Git { git stash pop }
        }

        # Return to the previous directory
        Pop-Location
    }
}

Write-Host "Repositories sync complete."
Read-Host -Prompt "Press Enter to close..."