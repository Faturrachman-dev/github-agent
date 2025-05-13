@echo off
setlocal enabledelayedexpansion

REM Extract token from .env file
for /f "tokens=2 delims==" %%a in ('findstr "GITHUB_TOKEN" .env') do set TOKEN=%%a

REM First, check what repositories we have access to
echo Checking accessible repositories...
curl -s -H "Authorization: Bearer %TOKEN%" -H "Accept: application/vnd.github+json" "https://api.github.com/user/repos?per_page=5" > repos_check.json
type repos_check.json
echo.

REM Second, test a wider date range with one repository
echo Testing wider date range (May 2025)...
set REPO=faturrachman-dev
set SINCE=2025-05-01T00:00:00Z
set UNTIL=2025-05-31T23:59:59Z

REM Test with no author filter to see all commits
curl -s -H "Authorization: Bearer %TOKEN%" -H "Accept: application/vnd.github+json" "https://api.github.com/repos/Faturrachman-dev/%REPO%/commits?since=%SINCE%&until=%UNTIL%" > commits_wide.json
powershell -Command "$commits = Get-Content commits_wide.json | ConvertFrom-Json; if ($commits -is [array]) { Write-Host 'Found' $commits.Count 'total commits'; foreach ($c in $commits) { Write-Host $c.commit.author.name 'with email' $c.commit.author.email 'on' $c.commit.author.date } } else { Write-Host 'No commits found' }"

echo.
echo Done. Please check the output above to see what author information GitHub has stored.
pause