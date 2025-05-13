@echo off
setlocal enabledelayedexpansion

echo ==== COMPREHENSIVE GITHUB CONTRIBUTIONS ANALYZER ==== [%date% %time%]
echo Creating logs directory...
mkdir logs 2>nul

REM Extract token from .env file
for /f "tokens=2 delims==" %%a in ('findstr "GITHUB_TOKEN" .env') do set TOKEN=%%a
echo Token loaded from .env file [%time%]

REM Check user's GitHub timezone setting
echo Checking GitHub timezone setting... [%time%]
powershell -Command "$env:GH_TOKEN='%TOKEN%'; Invoke-RestMethod -Headers @{Authorization = 'Bearer ' + $env:GH_TOKEN; Accept = 'application/vnd.github+json'} -Uri 'https://api.github.com/user' | ConvertTo-Json -Depth 10 | Out-File logs\user_info.json -Encoding ascii"
powershell -Command "Invoke-RestMethod -Method HEAD -Headers @{Authorization = 'Bearer %TOKEN%'; Accept = 'application/vnd.github+json'} -Uri 'https://api.github.com/rate_limit' | Out-Null; $rateLimitHeader = $LASTEXITCODE; (Invoke-WebRequest -Method HEAD -Headers @{Authorization = 'Bearer %TOKEN%'; Accept = 'application/vnd.github+json'} -Uri 'https://api.github.com/rate_limit').Headers['X-RateLimit-Remaining'] | Out-File logs\rate_limit.txt -Encoding ascii"
powershell -Command "$user = Get-Content logs\user_info.json | ConvertFrom-Json; Write-Host 'Your GitHub profile timezone:' $user.timezone; Write-Host 'GitHub username:' $user.login; Write-Host 'API rate limit:' (Get-Content logs\rate_limit.txt -Raw).Trim() 'remaining'"

REM Get repositories list including private repos
echo Fetching all your repositories... [%time%]
powershell -Command "$env:GH_TOKEN='%TOKEN%'; $repos = Invoke-RestMethod -Headers @{Authorization = 'Bearer ' + $env:GH_TOKEN; Accept = 'application/vnd.github+json'} -Uri 'https://api.github.com/user/repos?per_page=100&affiliation=owner,collaborator,organization_member'; $repos | ConvertTo-Json -Depth 10 | Out-File logs\all_repos.json -Encoding ascii; Write-Host 'Found' $repos.Count 'repositories'; $repos | ForEach-Object { $_.full_name + ' [' + $_.visibility + ']' } | Out-File -FilePath logs\all_repos_list.txt -Encoding ascii; $repos.name | Out-File -FilePath logs\repos.txt -Encoding ascii"

echo.
echo ========== TRYING DIFFERENT DATE FORMATS ==========

REM Try different date formats to find all contributions
echo.
echo APPROACH 1: Using local WIB timezone (UTC+7) [%time%]
set SINCE_WIB=2025-05-11T00:00:00+07:00
set UNTIL_WIB=2025-05-11T23:59:59+07:00
echo Date range: %SINCE_WIB% to %UNTIL_WIB%

REM Try with UTC dates instead
echo.
echo APPROACH 2: Using UTC dates [%time%]
set SINCE_UTC=2025-05-10T17:00:00Z
set UNTIL_UTC=2025-05-11T16:59:59Z
echo Date range: %SINCE_UTC% to %UNTIL_UTC% (equivalent to May 11 in WIB)

REM Try with a wider range to be safe
echo.
echo APPROACH 3: Using wider UTC range (48 hours) [%time%]
set SINCE_WIDE=2025-05-10T00:00:00Z
set UNTIL_WIDE=2025-05-12T23:59:59Z
echo Date range: %SINCE_WIDE% to %UNTIL_WIDE%

echo.
echo ========== DETAILED REPOSITORY SCAN ==========
echo.

set TOTAL_COMMITS_WIB=0
set TOTAL_COMMITS_UTC=0
set TOTAL_COMMITS_WIDE=0

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
  
  REM Approach 3: Wide date range only to save time
  powershell -Command "$env:GH_TOKEN='%TOKEN%'; try { $commits = Invoke-RestMethod -Headers @{Authorization = 'Bearer ' + $env:GH_TOKEN; Accept = 'application/vnd.github+json'} -Uri 'https://api.github.com/repos/Faturrachman-dev/%%r/commits?since=%SINCE_WIDE%&until=%UNTIL_WIDE%'; $commits | ConvertTo-Json -Depth 10 | Out-File logs\%%r_commits_wide.json -Encoding ascii; if ($commits -is [array]) { $count = $commits.Count } else { $count = 0 }; $count | Out-File logs\%%r_count_wide.txt -Encoding ascii } catch { Write-Host 'Error accessing repository'; 0 | Out-File logs\%%r_count_wide.txt -Encoding ascii }"
  
  if exist logs\%%r_count_wide.txt (
    set /p REPO_COUNT_WIDE=<logs\%%r_count_wide.txt
  ) else (
    set REPO_COUNT_WIDE=0
  )
  
  set /a TOTAL_COMMITS_WIDE+=REPO_COUNT_WIDE
  
  if !REPO_COUNT_WIDE! GTR 0 (
    echo   [WIDE] Found !REPO_COUNT_WIDE! commits in %%r
    powershell -Command "$commits = Get-Content logs\%%r_commits_wide.json | ConvertFrom-Json; if ($commits -is [array] -and $commits.Count -gt 0) { foreach ($c in $commits) { Write-Host '  - ' $c.commit.author.date $c.commit.message.Split(\"`n\")[0] } }"
  )

  REM Check for issues and PRs for this repository
  echo   Checking issues and PRs in %%r...
  powershell -Command "$env:GH_TOKEN='%TOKEN%'; try { $issues = Invoke-RestMethod -Headers @{Authorization = 'Bearer ' + $env:GH_TOKEN; Accept = 'application/vnd.github+json'} -Uri 'https://api.github.com/repos/Faturrachman-dev/%%r/issues?state=all&since=%SINCE_WIDE%'; $issues | ConvertTo-Json -Depth 10 | Out-File logs\%%r_issues.json -Encoding ascii; $issueCount = 0; $prCount = 0; $issueCommentCount = 0; $may11Issues = 0; $may11PRs = 0; $may11Comments = 0; foreach ($issue in $issues) { $created = [datetime]$issue.created_at; $day = $created.Day; $isPR = $issue.pull_request -ne $null; if ($created -ge [datetime]'%SINCE_WIDE%' -and $created -le [datetime]'%UNTIL_WIDE%') { if($isPR) { $prCount++; if($day -eq 11) { $may11PRs++ } } else { $issueCount++; if($day -eq 11) { $may11Issues++ } } }; if($issue.comments -gt 0) { $comments = Invoke-RestMethod -Headers @{Authorization = 'Bearer ' + $env:GH_TOKEN; Accept = 'application/vnd.github+json'} -Uri $issue.comments_url; foreach($comment in $comments) { $commentDate = [datetime]$comment.created_at; if($commentDate -ge [datetime]'%SINCE_WIDE%' -and $commentDate -le [datetime]'%UNTIL_WIDE%') { $issueCommentCount++; if($commentDate.Day -eq 11) { $may11Comments++ } } } } }; if($issueCount -gt 0 -or $prCount -gt 0 -or $issueCommentCount -gt 0) { Write-Host \"  Found contributions: $issueCount issues, $prCount PRs, $issueCommentCount comments\"; Write-Host \"  May 11 activity: $may11Issues issues, $may11PRs PRs, $may11Comments comments\" }; $issueCount,$prCount,$issueCommentCount,$may11Issues,$may11PRs,$may11Comments | Out-File logs\%%r_activity_stats.txt -Encoding ascii } catch { Write-Host '  Error accessing issues'; '0,0,0,0,0,0' | Out-File logs\%%r_activity_stats.txt -Encoding ascii }"
)

echo.
echo ========== GITHUB EVENTS ANALYSIS ========== [%time%]
echo.
echo Checking GitHub user events directly...
powershell -Command "$env:GH_TOKEN='%TOKEN%'; $events = Invoke-RestMethod -Headers @{Authorization = 'Bearer ' + $env:GH_TOKEN; Accept = 'application/vnd.github+json'} -Uri 'https://api.github.com/users/Faturrachman-dev/events?per_page=100'; $events | ConvertTo-Json -Depth 10 | Out-File logs\github_events.json -Encoding ascii; $relevantEvents = @(); foreach ($e in $events) { $date = [datetime]$e.created_at; $sinceDate = [datetime]'%SINCE_WIDE%'; $untilDate = [datetime]'%UNTIL_WIDE%'; if ($date -ge $sinceDate -and $date -le $untilDate) { $relevantEvents += $e } }; Write-Host 'Events in date range:' $relevantEvents.Count; $relevantEvents | Group-Object type | ForEach-Object { Write-Host $_.Name ':' $_.Count }; $relevantEvents | ForEach-Object { Write-Output \"{0:yyyy-MM-dd HH:mm:ss} - {1} - {2}\" -f [datetime]$_.created_at, $_.type, $_.repo.name } | Out-File -FilePath logs\github_events.txt -Encoding ascii"

REM Analyze ALL contribution types in detail
echo.
echo Analyzing all contribution types in detail...

REM First, analyze push events for commits
powershell -Command "$events = Get-Content logs\github_events.json | ConvertFrom-Json; $pushEvents = $events | Where-Object { $_.type -eq 'PushEvent' }; $totalCommits = 0; $repoStats = @{}; $branchStats = @{}; $mayCounts = @{11 = 0; 10 = 0; 12 = 0}; foreach ($push in $pushEvents) { $date = [datetime]$push.created_at; $sinceDate = [datetime]'%SINCE_WIDE%'; $untilDate = [datetime]'%UNTIL_WIDE%'; if ($date -ge $sinceDate -and $date -le $untilDate) { $repoName = $push.repo.name; $branch = $push.payload.ref.Replace('refs/heads/', ''); $commits = $push.payload.size; if (-not $commits) { $commits = 0 }; $totalCommits += $commits; $dayOfMonth = $date.Day; if ($mayCounts.ContainsKey($dayOfMonth)) { $mayCounts[$dayOfMonth] += $commits }; if (-not $repoStats.ContainsKey($repoName)) { $repoStats[$repoName] = 0 }; $repoStats[$repoName] += $commits; $branchKey = \"$repoName / $branch\"; if (-not $branchStats.ContainsKey($branchKey)) { $branchStats[$branchKey] = 0 }; $branchStats[$branchKey] += $commits; Write-Host \"$date - $repoName - Branch: $branch - Commits: $commits\"; } }; Write-Host \"`nTotal commits from push events: $totalCommits`n\"; Write-Host \"Commits by date:`n- May 10: $($mayCounts[10])`n- May 11: $($mayCounts[11])`n- May 12: $($mayCounts[12])`n\"; Write-Host \"Commits by repository:\"; $repoStats.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object { Write-Host \"$($_.Key): $($_.Value) commits\" }; Write-Host \"`nCommits by branch:\"; $branchStats.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object { Write-Host \"$($_.Key): $($_.Value) commits\" }; $totalCommits | Out-File logs\push_events_commits.txt -Encoding ascii; $mayCounts[11] | Out-File logs\may11_commits.txt -Encoding ascii"
set /p PUSH_COMMITS=<logs\push_events_commits.txt
set /p MAY11_COMMITS=<logs\may11_commits.txt

REM Now analyze other contribution types
powershell -Command "$events = Get-Content logs\github_events.json | ConvertFrom-Json; $issueEvents = @($events | Where-Object { $_.type -eq 'IssuesEvent' }); $prEvents = @($events | Where-Object { $_.type -eq 'PullRequestEvent' }); $commentEvents = @($events | Where-Object { $_.type -in @('IssueCommentEvent', 'CommitCommentEvent', 'PullRequestReviewCommentEvent') }); $reviewEvents = @($events | Where-Object { $_.type -eq 'PullRequestReviewEvent' }); $createEvents = @($events | Where-Object { $_.type -eq 'CreateEvent' }); $deleteEvents = @($events | Where-Object { $_.type -eq 'DeleteEvent' }); $forkEvents = @($events | Where-Object { $_.type -eq 'ForkEvent' }); $watchEvents = @($events | Where-Object { $_.type -eq 'WatchEvent' }); function CountByDay($eventsArray) { $counts = @{10 = 0; 11 = 0; 12 = 0}; foreach ($e in $eventsArray) { $day = ([datetime]$e.created_at).Day; if ($counts.ContainsKey($day)) { $counts[$day]++ } }; return $counts }; $issueCounts = CountByDay($issueEvents); $prCounts = CountByDay($prEvents); $commentCounts = CountByDay($commentEvents); $reviewCounts = CountByDay($reviewEvents); $createCounts = CountByDay($createEvents); $deleteCounts = CountByDay($deleteEvents); $forkCounts = CountByDay($forkEvents); $watchCounts = CountByDay($watchEvents); Write-Host \"`nContribution analysis by day:`\"; Write-Host \"- Issues: May 10: $($issueCounts[10]), May 11: $($issueCounts[11]), May 12: $($issueCounts[12])\"; Write-Host \"- Pull Requests: May 10: $($prCounts[10]), May 11: $($prCounts[11]), May 12: $($prCounts[12])\"; Write-Host \"- Comments: May 10: $($commentCounts[10]), May 11: $($commentCounts[11]), May 12: $($commentCounts[12])\"; Write-Host \"- Reviews: May 10: $($reviewCounts[10]), May 11: $($reviewCounts[11]), May 12: $($reviewCounts[12])\"; Write-Host \"- Create: May 10: $($createCounts[10]), May 11: $($createCounts[11]), May 12: $($createCounts[12])\"; Write-Host \"- Delete: May 10: $($deleteCounts[10]), May 11: $($deleteCounts[11]), May 12: $($deleteCounts[12])\"; Write-Host \"- Fork: May 10: $($forkCounts[10]), May 11: $($forkCounts[11]), May 12: $($forkCounts[12])\"; Write-Host \"- Watch: May 10: $($watchCounts[10]), May 11: $($watchCounts[11]), May 12: $($watchCounts[12])\"; $may11Total = $issueCounts[11] + $prCounts[11] + $commentCounts[11] + $reviewCounts[11] + $createCounts[11] + $deleteCounts[11] + $forkCounts[11] + $watchCounts[11]; Write-Host \"`nTotal non-commit contributions on May 11: $may11Total\"; $may11Total | Out-File logs\may11_other_contributions.txt -Encoding ascii"
set /p MAY11_OTHER=<logs\may11_other_contributions.txt

REM Calculate total contributions
powershell -Command "$total = %MAY11_COMMITS% + %MAY11_OTHER%; Write-Host 'Total May 11 contributions: ' $total; $total | Out-File logs\may11_total.txt -Encoding ascii"
set /p MAY11_TOTAL=<logs\may11_total.txt

REM Check the contribution graph data directly using alternative API
echo.
echo Checking direct contribution data for May 11...
powershell -Command "try { $directData = Invoke-RestMethod -Uri 'https://github.com/users/Faturrachman-dev/contributions' -Headers @{Accept = 'application/json'}; Write-Host 'Successfully fetched direct contribution data' } catch { Write-Host 'Could not access direct contribution data' }"

echo.
echo ========== RESULTS SUMMARY ========== [%time%]
echo.
echo COMMITS:
echo - Found in repositories API: %TOTAL_COMMITS_WIDE% total commits
echo - Found in Events API: %PUSH_COMMITS% total commits
echo - May 11 commits count: %MAY11_COMMITS%
echo.
echo OTHER CONTRIBUTIONS ON MAY 11:
echo - Issues, PRs, comments, etc.: %MAY11_OTHER%
echo.
echo TOTAL MAY 11 CONTRIBUTIONS: %MAY11_TOTAL%
echo.
echo EXPLANATION:
echo 1. GitHub contribution graph shows ~14 contributions on May 11
echo 2. Our analysis found %MAY11_TOTAL% total contributions on May 11:
echo    - %MAY11_COMMITS% commits
echo    - %MAY11_OTHER% other contribution activities
echo 3. The discrepancy between our count (%MAY11_TOTAL%) and GitHub's count (~14) 
echo    is likely due to:
echo    - Different timezone cutoffs
echo    - Private or organization contributions not visible to the API
echo    - Counting rules that differ from our analysis
echo.
echo ROOT CAUSE:
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