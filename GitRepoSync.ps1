param (
    [alias('--c')]
    [alias('-config')]
    [string] $configFilePath = "code-environment.project.json"
)

function Get-ConfigurationFile {
    param ([string] $configurationFilePath)
    Write-Host "Loading configuration file..."
    if (!(Test-Path -Path $configurationFilePath)) {
        Write-Error "Configuration file not found: $configurationFilePath"
        exit 1
    }
    return (Get-Content -Path $configurationFilePath | ConvertFrom-Json)
}

function Add-Directory {
    param ([string] $directoryPath)
    if (!(Test-Path -Path $directoryPath)) {
        Write-Host "Creating directory: $directoryPath"
        New-Item -Path $directoryPath -ItemType Directory | Out-Null
    }
}

function Invoke-Git {
    param ([ScriptBlock] $Command)
    $initialForegroundColor = $Host.UI.RawUI.ForegroundColor
    $Host.UI.RawUI.ForegroundColor = 'Yellow'
    & $Command 2>&1
    $Host.UI.RawUI.ForegroundColor = $initialForegroundColor
}

function Sync-Branches {
    param (
        [parameter(Mandatory)]
        [alias('-sync')]
        [array] $syncBranches,
        [alias('--d')]
        [string] $defaultBranch
    )

    if (!($defaultBranch)) {
        # If default branch not provided then store current branch before sync
        $defaultBranch = git symbolic-ref --short -q HEAD
    }

    foreach ($branch in $syncBranches) {
        Write-Host "Syncing branch: $branch"
        Invoke-Git { git checkout $branch }
        Invoke-Git { git pull origin $branch }
    }

    Invoke-Git { git checkout $defaultBranch }
}

function Sync-BranchesWithChanges {
    param (
        [parameter(Mandatory)]
        [alias('-sync')]
        [array] $syncBranches,
        [parameter(Mandatory)]
        [alias('-current')]
        [string] $currentBranch
    )

    # Create sync branch with unique name in case if it's already exist
    $currentDate = Get-Date -Format "ddMMyyyy-HHmm"
    $syncBranchName = "${currentBranch}-sync-${currentDate}"

    Write-Host "Creating sync branch: $syncBranchName"
    Invoke-Git { git checkout -b $syncBranchName }

    Write-Host "Committing changes with message 'autosync'"
    Invoke-Git { git add . }
    Invoke-Git { git commit -m 'autosync' }

    Sync-Branches -sync $syncBranches

    Write-Host "Switching back to the original branch"
    Invoke-Git { git checkout $currentBranch }

    Write-Host "Trying to cherry-pick autosync commit"
    Invoke-Git { git cherry-pick ${syncBranchName} }

    $hasConflicts = $null -ne  (git status --porcelain | Select-String -Pattern "^U")

    if (-not $hasConflicts) {
        Write-Host "Resetting soft the autosync commit"
        Invoke-Git { git reset --soft HEAD~1 }
    
        Write-Host "Deleting sync branch"
        Invoke-Git { git branch -D $syncBranchName }
    }
    else {
        Write-Host "Conflict detected. Changes are stored in the ${syncBranchName} branch."
        Invoke-Git { git cherry-pick --abort }
        Invoke-Git { git checkout $syncBranchName }
    }
}

function Invoke-SyncRepository {
    param (
        [parameter(Mandatory, ValueFromPipeline)]
        $repository,
        [parameter(Mandatory)]
        [alias('-workspace')]
        [string] $workspacePath
    )

    Write-Host "Configuring repository: $($repository.name)"
    $repositoryDirectoryPath = Join-Path -Path $workspacePath -ChildPath $repository.name

    # Case 1
    if (!(Test-Path -Path $repositoryDirectoryPath)) {
        Write-Host "Cloning repository: ${repository.origin}"
        Invoke-Git { git clone $repository.origin $repositoryDirectoryPath }
        Sync-Branches -sync $repository.branches.sync
        Invoke-Git { git checkout $repository.branches.default }
    } else {
        Push-Location $repositoryDirectoryPath

        $currentBranch = git symbolic-ref --short -q HEAD
        $hasChanges = $null -ne (git status --porcelain)
        $isInSyncList = $repository.branches.sync -contains $currentBranch

        if (-not $hasChanges) {
            Sync-Branches -sync $repository.branches.sync
        } elseif ($hasChanges -and -not $isInSyncList) {
            Write-Host "Uncommitted changes found, stashing changes..."
            Invoke-Git { git stash save "sync-stash" }

            Sync-Branches -sync $repository.branches.sync

            Write-Host "Unstashing changes..."
            Invoke-Git { git stash pop }
        } elseif ($hasChanges -and $isInSyncList) {
            Sync-BranchesWithChanges -sync $repository.branches.sync -current $currentBranch
        }

        Pop-Location
    }
}

$config = Get-ConfigurationFile $configFilePath

# Create root directory if it doesn't exist
Add-Directory $config.root

# Iterate through workspaces
foreach ($workspace in $config.workspaces) {
    Write-Host "Configuring workspace: $($workspace.workspace)"
    $workspacePath = Join-Path -Path $config.root -ChildPath $workspace.workspace

    Add-Directory $workspacePath

    # Iterate through repositories
    foreach ($repository in $workspace.repositories) {
        Invoke-SyncRepository $repository -workspace $workspacePath
    }
}

Write-Host "Repositories sync complete."
Read-Host -Prompt "Press Enter to close..."