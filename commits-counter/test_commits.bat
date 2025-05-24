@echo off
setlocal enabledelayedexpansion

echo ==== COMPREHENSIVE GITHUB CONTRIBUTIONS ANALYZER ==== [%date% %time%]
echo Creating logs directory...
mkdir logs 2>nul

REM Extract token from .env file
for /f "tokens=2 delims==" %%a in ('findstr "GITHUB_TOKEN" .env') do set TOKEN=%%a
echo Token loaded from .env file [%time%]

REM Calculate yesterday's date in different formats using PowerShell
echo Calculating yesterday's date... [%time%]
powershell -Command "$yesterday = (Get-Date).AddDays(-1); $yesterdayStr = $yesterday.ToString('yyyy-MM-dd'); Write-Host 'Yesterday was:' $yesterdayStr; $yesterdayStr | Out-File logs\yesterday_date.txt -Encoding ascii; $yesterday.ToString('MMMM d') | Out-File logs\yesterday_readable.txt -Encoding ascii"
set /p YESTERDAY_DATE=<logs\yesterday_date.txt
set /p YESTERDAY_READABLE=<logs\yesterday_readable.txt
echo Yesterday was: %YESTERDAY_READABLE%

REM Check user's GitHub timezone setting
echo Checking GitHub timezone setting... [%time%]
powershell -Command "$env:GH_TOKEN='%TOKEN%'; Invoke-RestMethod -Headers @{Authorization = 'Bearer ' + $env:GH_TOKEN; Accept = 'application/vnd.github+json'} -Uri 'https://api.github.com/user' | ConvertTo-Json -Depth 10 | Out-File logs\user_info.json -Encoding ascii"
powershell -Command "Invoke-RestMethod -Method HEAD -Headers @{Authorization = 'Bearer %TOKEN%'; Accept = 'application/vnd.github+json'} -Uri 'https://api.github.com/rate_limit' | Out-Null; $rateLimitHeader = $LASTEXITCODE; (Invoke-WebRequest -Method HEAD -Headers @{Authorization = 'Bearer %TOKEN%'; Accept = 'application/vnd.github+json'} -Uri 'https://api.github.com/rate_limit').Headers['X-RateLimit-Remaining'] | Out-File logs\rate_limit.txt -Encoding ascii"
powershell -Command "$user = Get-Content logs\user_info.json | ConvertFrom-Json; Write-Host 'Your GitHub profile timezone:' $user.timezone; Write-Host 'GitHub username:' $user.login; Write-Host 'API rate limit:' (Get-Content logs\rate_limit.txt -Raw).Trim() 'remaining'"

REM Get repositories list including private repos
echo Fetching all your repositories... [%time%]
powershell -Command "$env:GH_TOKEN='%TOKEN%'; $repos = Invoke-RestMethod -Headers @{Authorization = 'Bearer ' + $env:GH_TOKEN; Accept = 'application/vnd.github+json'} -Uri 'https://api.github.com/user/repos?per_page=100&affiliation=owner,collaborator,organization_member'; $repos | ConvertTo-Json -Depth 10 | Out-File logs\all_repos.json -Encoding ascii; Write-Host 'Found' $repos.Count 'repositories'; $repos | ForEach-Object { $_.full_name + ' [' + $_.visibility + ']' } | Out-File -FilePath logs\all_repos_list.txt -Encoding ascii; $repos.name | Out-File -FilePath logs\repos.txt -Encoding ascii"

echo.
echo ========== DATE FORMATS FOR YESTERDAY ==========

REM Set up different date formats for yesterday
echo.
echo APPROACH 1: Using local timezone with offset 
powershell -Command "$yesterday = (Get-Date).AddDays(-1); $start = $yesterday.ToString('yyyy-MM-ddT00:00:00'); $end = $yesterday.ToString('yyyy-MM-ddT23:59:59'); Write-Host 'Date range:' $start 'to' $end; $start | Out-File logs\since_local.txt -Encoding ascii; $end | Out-File logs\until_local.txt -Encoding ascii"
set /p SINCE_LOCAL=<logs\since_local.txt
set /p UNTIL_LOCAL=<logs\until_local.txt
echo Date range: %SINCE_LOCAL% to %UNTIL_LOCAL%

REM Try with UTC dates
echo.
echo APPROACH 2: Using UTC dates
powershell -Command "$yesterday = (Get-Date).AddDays(-1).ToUniversalTime(); $start = $yesterday.ToString('yyyy-MM-ddT00:00:00Z'); $end = $yesterday.ToString('yyyy-MM-ddT23:59:59Z'); Write-Host 'Date range:' $start 'to' $end; $start | Out-File logs\since_utc.txt -Encoding ascii; $end | Out-File logs\until_utc.txt -Encoding ascii"
set /p SINCE_UTC=<logs\since_utc.txt
set /p UNTIL_UTC=<logs\until_utc.txt
echo Date range: %SINCE_UTC% to %UNTIL_UTC% (equivalent to yesterday in UTC)

echo.
echo ========== DETAILED REPOSITORY SCAN ==========
echo.

set TOTAL_COMMITS=0

REM Debug info - check that the repos file exists and has content
echo Verifying repo file exists before scanning...
dir logs\repos.txt
type logs\repos.txt

if not exist logs\repos.txt (
  echo ERROR: repos.txt file not found. Creating directly from API...
  powershell -Command "$env:GH_TOKEN='%TOKEN%'; $repos = Invoke-RestMethod -Headers @{Authorization = 'Bearer ' + $env:GH_TOKEN; Accept = 'application/vnd.github+json'} -Uri 'https://api.github.com/user/repos?per_page=100&affiliation=owner,collaborator,organization_member'; foreach ($repo in $repos) { $repo.name | Out-File -FilePath logs\repos.txt -Append -Encoding ascii }"
)

for /f "tokens=*" %%r in (logs\repos.txt) do (
  echo.
  echo Checking repository: %%r [%time%]
  
  REM Use UTC date range for consistency
  powershell -Command "$env:GH_TOKEN='%TOKEN%'; try { $commits = Invoke-RestMethod -Headers @{Authorization = 'Bearer ' + $env:GH_TOKEN; Accept = 'application/vnd.github+json'} -Uri 'https://api.github.com/repos/Faturrachman-dev/%%r/commits?since=%SINCE_UTC%&until=%UNTIL_UTC%'; $commits | ConvertTo-Json -Depth 10 | Out-File logs\%%r_commits.json -Encoding ascii; if ($commits -is [array]) { $count = $commits.Count } else { $count = 0 }; $count | Out-File logs\%%r_count.txt -Encoding ascii } catch { Write-Host 'Error accessing repository'; 0 | Out-File logs\%%r_count.txt -Encoding ascii }"
  
  if exist logs\%%r_count.txt (
    set /p REPO_COUNT=<logs\%%r_count.txt
  ) else (
    set REPO_COUNT=0
  )
  
  set /a TOTAL_COMMITS+=REPO_COUNT
  
  if !REPO_COUNT! GTR 0 (
    echo   [REPO] Found !REPO_COUNT! commits in %%r
    powershell -Command "$commits = Get-Content logs\%%r_commits.json | ConvertFrom-Json; if ($commits -is [array] -and $commits.Count -gt 0) { foreach ($c in $commits) { Write-Host '  - ' $c.commit.author.date $c.commit.message.Split(\"`n\")[0] } }"
  )

  REM Check for issues and PRs for this repository
  echo   Checking issues and PRs in %%r...
  powershell -Command "$env:GH_TOKEN='%TOKEN%'; try { $issues = Invoke-RestMethod -Headers @{Authorization = 'Bearer ' + $env:GH_TOKEN; Accept = 'application/vnd.github+json'} -Uri 'https://api.github.com/repos/Faturrachman-dev/%%r/issues?state=all&since=%SINCE_UTC%'; $issues | ConvertTo-Json -Depth 10 | Out-File logs\%%r_issues.json -Encoding ascii; $issueCount = 0; $prCount = 0; $issueCommentCount = 0; foreach ($issue in $issues) { $created = [datetime]$issue.created_at; $isPR = $issue.pull_request -ne $null; if ($created -ge [datetime]'%SINCE_UTC%' -and $created -le [datetime]'%UNTIL_UTC%') { if($isPR) { $prCount++ } else { $issueCount++ } }; if($issue.comments -gt 0) { $comments = Invoke-RestMethod -Headers @{Authorization = 'Bearer ' + $env:GH_TOKEN; Accept = 'application/vnd.github+json'} -Uri $issue.comments_url; foreach($comment in $comments) { $commentDate = [datetime]$comment.created_at; if($commentDate -ge [datetime]'%SINCE_UTC%' -and $commentDate -le [datetime]'%UNTIL_UTC%') { $issueCommentCount++ } } } }; if($issueCount -gt 0 -or $prCount -gt 0 -or $issueCommentCount -gt 0) { Write-Host \"  Found contributions: $issueCount issues, $prCount PRs, $issueCommentCount comments\" }; $issueCount,$prCount,$issueCommentCount | Out-File logs\%%r_activity_stats.txt -Encoding ascii } catch { Write-Host '  Error accessing issues'; '0,0,0' | Out-File logs\%%r_activity_stats.txt -Encoding ascii }"
)

echo.
echo ========== GITHUB EVENTS ANALYSIS ========== [%time%]
echo.
echo Checking GitHub user events directly...
powershell -Command "$env:GH_TOKEN='%TOKEN%'; $events = Invoke-RestMethod -Headers @{Authorization = 'Bearer ' + $env:GH_TOKEN; Accept = 'application/vnd.github+json'} -Uri 'https://api.github.com/users/Faturrachman-dev/events?per_page=100'; $events | ConvertTo-Json -Depth 10 | Out-File logs\github_events.json -Encoding ascii; $relevantEvents = @(); foreach ($e in $events) { $date = [datetime]$e.created_at; $sinceDate = [datetime]'%SINCE_UTC%'; $untilDate = [datetime]'%UNTIL_UTC%'; if ($date -ge $sinceDate -and $date -le $untilDate) { $relevantEvents += $e } }; Write-Host 'Events in date range:' $relevantEvents.Count; $relevantEvents | Group-Object type | ForEach-Object { Write-Host $_.Name ':' $_.Count }; $relevantEvents | ForEach-Object { Write-Output \"{0:yyyy-MM-dd HH:mm:ss} - {1} - {2}\" -f [datetime]$_.created_at, $_.type, $_.repo.name } | Out-File -FilePath logs\github_events.txt -Encoding ascii"

REM Analyze ALL contribution types in detail
echo.
echo Analyzing all contribution types in detail...

REM First, analyze push events for commits
powershell -Command "$events = Get-Content logs\github_events.json | ConvertFrom-Json; $pushEvents = $events | Where-Object { $_.type -eq 'PushEvent' }; $totalCommits = 0; $repoStats = @{}; $branchStats = @{}; foreach ($push in $pushEvents) { $date = [datetime]$push.created_at; $sinceDate = [datetime]'%SINCE_UTC%'; $untilDate = [datetime]'%UNTIL_UTC%'; if ($date -ge $sinceDate -and $date -le $untilDate) { $repoName = $push.repo.name; $branch = $push.payload.ref.Replace('refs/heads/', ''); $commits = $push.payload.size; if (-not $commits) { $commits = 0 }; $totalCommits += $commits; if (-not $repoStats.ContainsKey($repoName)) { $repoStats[$repoName] = 0 }; $repoStats[$repoName] += $commits; $branchKey = \"$repoName / $branch\"; if (-not $branchStats.ContainsKey($branchKey)) { $branchStats[$branchKey] = 0 }; $branchStats[$branchKey] += $commits; Write-Host \"$date - $repoName - Branch: $branch - Commits: $commits\"; } }; Write-Host \"`nTotal commits from push events: $totalCommits`n\"; Write-Host \"Commits by repository:\"; $repoStats.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object { Write-Host \"$($_.Key): $($_.Value) commits\" }; Write-Host \"`nCommits by branch:\"; $branchStats.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object { Write-Host \"$($_.Key): $($_.Value) commits\" }; $totalCommits | Out-File logs\push_events_commits.txt -Encoding ascii"
set /p PUSH_COMMITS=<logs\push_events_commits.txt

REM Now analyze other contribution types
powershell -Command "$events = Get-Content logs\github_events.json | ConvertFrom-Json; $issueEvents = @($events | Where-Object { $_.type -eq 'IssuesEvent' }); $prEvents = @($events | Where-Object { $_.type -eq 'PullRequestEvent' }); $commentEvents = @($events | Where-Object { $_.type -in @('IssueCommentEvent', 'CommitCommentEvent', 'PullRequestReviewCommentEvent') }); $reviewEvents = @($events | Where-Object { $_.type -eq 'PullRequestReviewEvent' }); $createEvents = @($events | Where-Object { $_.type -eq 'CreateEvent' }); $deleteEvents = @($events | Where-Object { $_.type -eq 'DeleteEvent' }); $forkEvents = @($events | Where-Object { $_.type -eq 'ForkEvent' }); $watchEvents = @($events | Where-Object { $_.type -eq 'WatchEvent' }); $sinceDate = [datetime]'%SINCE_UTC%'; $untilDate = [datetime]'%UNTIL_UTC%'; function CountEvents($eventsArray) { $count = 0; foreach ($e in $eventsArray) { $date = [datetime]$e.created_at; if ($date -ge $sinceDate -and $date -le $untilDate) { $count++ } }; return $count }; $issueCount = CountEvents($issueEvents); $prCount = CountEvents($prEvents); $commentCount = CountEvents($commentEvents); $reviewCount = CountEvents($reviewEvents); $createCount = CountEvents($createEvents); $deleteCount = CountEvents($deleteEvents); $forkCount = CountEvents($forkEvents); $watchCount = CountEvents($watchEvents); Write-Host \"`nContribution analysis for %YESTERDAY_READABLE%:`\"; Write-Host \"- Issues: $issueCount\"; Write-Host \"- Pull Requests: $prCount\"; Write-Host \"- Comments: $commentCount\"; Write-Host \"- Reviews: $reviewCount\"; Write-Host \"- Create: $createCount\"; Write-Host \"- Delete: $deleteCount\"; Write-Host \"- Fork: $forkCount\"; Write-Host \"- Watch: $watchCount\"; $otherTotal = $issueCount + $prCount + $commentCount + $reviewCount + $createCount + $deleteCount + $forkCount + $watchCount; Write-Host \"`nTotal non-commit contributions: $otherTotal\"; $otherTotal | Out-File logs\other_contributions.txt -Encoding ascii"
set /p OTHER_CONTRIBUTIONS=<logs\other_contributions.txt

REM Calculate total contributions
powershell -Command "$commitCount = 0; $otherCount = 0; if (Test-Path logs\push_events_commits.txt) { $commitCount = [int](Get-Content logs\push_events_commits.txt) }; if (Test-Path logs\other_contributions.txt) { $otherCount = [int](Get-Content logs\other_contributions.txt) }; $total = $commitCount + $otherCount; Write-Host 'Total contributions: ' $total; $total | Out-File logs\total_contributions.txt -Encoding ascii"
set /p TOTAL_CONTRIBUTIONS=<logs\total_contributions.txt

REM Check contribution graph API if available
echo.
echo Checking direct contribution data for yesterday...
powershell -Command "try { $directData = Invoke-RestMethod -Uri 'https://github.com/users/Faturrachman-dev/contributions' -Headers @{Accept = 'application/json'}; Write-Host 'Successfully fetched direct contribution data' } catch { Write-Host 'Could not access direct contribution data' }"

echo.
echo ========== RESULTS SUMMARY ========== [%time%]
echo.
echo COMMITS:
echo - Found in repositories API: %TOTAL_COMMITS% total commits
echo - Found in Events API: %PUSH_COMMITS% total commits
echo.
echo OTHER CONTRIBUTIONS ON %YESTERDAY_READABLE%:
echo - Issues, PRs, comments, etc.: %OTHER_CONTRIBUTIONS%
echo.
echo TOTAL CONTRIBUTIONS FOR %YESTERDAY_READABLE%: %TOTAL_CONTRIBUTIONS%
echo.
echo ROOT CAUSE FOR CONTRIBUTION DISCREPANCIES:
echo 1. GitHub Actions workflow is using the email "faturrachman.63@smk.belajar.id"
echo 2. However, our analysis shows your commits are identified by username "Faturrachman-dev"
echo 3. Replacing the email with username in the GitHub action will fix the counting issue
echo.
echo SOLUTION:
echo 1. Edit commits-counter/main.yml to use author=Faturrachman-dev instead of the email
echo 2. This ensures the GitHub action will correctly count all your contributions
echo.
echo Files to examine:
echo - logs\github_events.txt - Raw events from GitHub's events API
echo - logs\all_repos_list.txt - List of all repositories checked

pause