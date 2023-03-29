@echo off
powershell.exe -ExecutionPolicy Bypass -File "GitRepoSync.ps1" -configFilePath "code-environment.personal.json"
