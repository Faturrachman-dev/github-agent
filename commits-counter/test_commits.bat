@echo off
setlocal enabledelayedexpansion

REM Extract token from .env file
for /f "tokens=2 delims==" %%a in ('findstr "GITHUB_TOKEN" .env') do set TOKEN=%%a

REM Set date range
set SINCE=2025-05-11T08:00:00Z
set UNTIL=2025-05-12T07:59:59Z

echo Testing different approaches to count commits from May 11:
echo =====================================================

echo 1. Testing with no author filter (all commits):
call :test_repo_no_author cursor-view

echo 2. Testing raw author parameter formats:
echo Testing: author=Faturrachman
call :test_repo_with_author cursor-view Faturrachman

echo Testing: author=Faturrachman-dev
call :test_repo_with_author cursor-view Faturrachman-dev

echo Testing: author=faturrachman.63@smk.belajar.id
call :test_repo_with_author cursor-view faturrachman.63@smk.belajar.id

echo Testing: email=faturrachman.63@smk.belajar.id (different parameter)
call :test_repo_with_email cursor-view faturrachman.63@smk.belajar.id

echo 3. Examine the actual commit:
curl -s -H "Authorization: Bearer %TOKEN%" -H "Accept: application/vnd.github+json" "https://api.github.com/repos/Faturrachman-dev/cursor-view/commits?since=%SINCE%&until=%UNTIL%" > cv_commits.json
echo Commit details:
type cv_commits.json

echo.
echo =====================================================
echo Recommendation: Based on this testing, we should use:
echo 1. Remove author filter completely to count all commits
echo 2. Try a GitHub Actions run with these changes for verification

pause
goto :eof

:test_repo_no_author
set REPO=%~1
echo.
echo Testing %REPO% with no author filter:
curl -s -H "Authorization: Bearer %TOKEN%" -H "Accept: application/vnd.github+json" "https://api.github.com/repos/Faturrachman-dev/%REPO%/commits?since=%SINCE%&until=%UNTIL%" > commits.json
powershell -Command "$commits = Get-Content commits.json | ConvertFrom-Json; if ($commits -is [array]) { Write-Host '  Found' $commits.Count 'commits' } else { Write-Host '  No commits found' }"
del commits.json 2>nul
echo.
goto :eof

:test_repo_with_author
set REPO=%~1
set AUTHOR=%~2
echo.
echo Testing %REPO% with author=%AUTHOR%:
curl -s -H "Authorization: Bearer %TOKEN%" -H "Accept: application/vnd.github+json" "https://api.github.com/repos/Faturrachman-dev/%REPO%/commits?author=%AUTHOR%&since=%SINCE%&until=%UNTIL%" > commits.json
powershell -Command "$commits = Get-Content commits.json | ConvertFrom-Json; if ($commits -is [array]) { Write-Host '  Found' $commits.Count 'commits' } else { Write-Host '  No commits found' }"
del commits.json 2>nul
echo.
goto :eof

:test_repo_with_email
set REPO=%~1
set EMAIL=%~2
echo.
echo Testing %REPO% with email=%EMAIL%:
curl -s -H "Authorization: Bearer %TOKEN%" -H "Accept: application/vnd.github+json" "https://api.github.com/repos/Faturrachman-dev/%REPO%/commits?email=%EMAIL%&since=%SINCE%&until=%UNTIL%" > commits.json
powershell -Command "$commits = Get-Content commits.json | ConvertFrom-Json; if ($commits -is [array]) { Write-Host '  Found' $commits.Count 'commits' } else { Write-Host '  No commits found' }"
del commits.json 2>nul
echo.
goto :eof