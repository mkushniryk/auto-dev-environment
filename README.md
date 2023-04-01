# Git Repositories Sync

GitRepoSync is a PowerShell script that automates the process of syncing local Git repositories with their remote counterparts. It streamlines the synchronization of multiple repositories and branches, handling various cases to ensure that your local environment stays up-to-date with remote changes while preserving any uncommitted work.

## Features

1. Clones repositories if they don't exist locally.
2. Syncs specified branches from the remote repository.
3. Preserves uncommitted changes and handles conflicts.
4. Supports multiple workspaces and repositories.

## Usage

1. Customize your configuration file, e.g., code-environment.project.json, to define the root directory, workspaces, repositories, and branches to sync.
2. Run the script using the following command:

```powershell
    powershell.exe -ExecutionPolicy Bypass -File "GitRepoSync.ps1" --c "code-environment.project.json"
```

## Sync Behavior

### Case 1 - Repository does not exist

The script pulls the repository and syncs all branches from the config file, leaving the repository on the default branch.

### Case 2 - Repository exists, no changes

The script syncs branches from the config file with the remote repository, keeping the repository on the same branch as before syncing.

### Case 3 - Repository exists, uncommitted changes on a branch not in the sync list

The script stashes changes on the branch not in the sync list, syncs all branches from the config file, moves back to the original branch, and performs a stash pop. The repository stays on the same branch as before syncing.

### Case 4 - Repository exists, uncommitted changes on one of the branches from the sync list

The script creates a new branch with the name `[original-branch]-sync-[ddMMyyyy-HHmm]` and commits the changes with the message `autosync`. It then syncs the branches listed in the config file. After syncing, it goes back to the original branch and tries to cherry-pick the `autosync` commit. If there are no conflicts, it performs a soft reset of the commit on the original branch and deletes the `[original-branch]-sync-[ddMMyyyy-HHmm]` branch. If there are conflicts, it aborts the cherry-pick and checks out the `[original-branch]-sync-[ddMMyyyy-HHmm]` branch.

## Configuration Example

A sample configuration file, `code-environment.[project].json`, is provided:

```json
{
    "root": "C:\\Development",
    "workspaces": [
        {
            "workspace": "Personal",
            "repositories": [
                {
                    "name": "auto-dev-environment",
                    "branches": {
                        "default": "main",
                        "sync": [ "main" ]
                    },
                    "origin": "https://github.com/dotmen/auto-dev-environment.git"
                }
            ]
        }
    ]
}

```

This configuration file specifies the root directory, a workspace called "Personal", and a single repository within the workspace. The repository has a default branch, "main," which is also the only branch in the sync list.

### Structure

- `root`: The root directory for your workspaces.
- `workspaces`: An array of workspaces, each with the following properties:
  - `workspace`: The name of the workspace.
  - `repositories`: An array of repositories, each with the following properties:
    - `name`: The name of the repository.
    - `branches`: An object with the following properties:
      - `default`: The default branch to checkout after syncing.
      - `sync`: An array of branch names that should be synchronized.
    - `origin`: The remote URL of the repository.

Modify the configuration file to include your own workspaces, repositories, and branches as needed.

## Notes

This tool assumes you have Git installed and configured on your system.
Ensure that you have the appropriate permissions to read and write to the specified directories in the configuration file.
The script is designed to work with the default origin remote. If you have multiple remotes, you may need to modify the script to accommodate your specific setup.
