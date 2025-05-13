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
powershell -Command "$env:GH_TOKEN='%TOKEN%'; Invoke-RestMethod -Headers @{Authorization = 'Bearer ' + $env:GH_TOKEN; Accept = 'application/vnd.github+json'} -Uri 'https://api.github.com/user/repos?per_page=100&affiliation=owner,collaborator,organization_member' | ConvertTo-Json -Depth 10 | Out-File logs\all_repos.json -Encoding ascii"
powershell -Command "$repos = Get-Content logs\all_repos.json | ConvertFrom-Json; Write-Host 'Found' $repos.Count 'repositories'; $repos | ForEach-Object { $_.full_name + ' [' + $_.visibility + ']' } | Out-File -FilePath logs\all_repos_list.txt -Encoding ascii; $repos | ForEach-Object { $_.name } | Out-File -FilePath logs\all_repos.txt -Encoding ascii"

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
set TOTAL_ISSUES=0
set TOTAL_PRS=0
set TOTAL_REVIEWS=0
set TOTAL_DEFAULT_BRANCH_COMMITS=0
set TOTAL_OTHER_BRANCH_COMMITS=0

for /f "tokens=*" %%r in (logs\all_repos.txt) do (
  echo Checking repository: %%r [%time%]
  
  REM Get default branch name
  powershell -Command "$env:GH_TOKEN='%TOKEN%'; $repo = Invoke-RestMethod -Headers @{Authorization = 'Bearer ' + $env:GH_TOKEN; Accept = 'application/vnd.github+json'} -Uri 'https://api.github.com/repos/Faturrachman-dev/%%r'; $repo | ConvertTo-Json -Depth 10 | Out-File logs\%%r_repo_info.json -Encoding ascii; Write-Host '  Default branch:' $repo.default_branch; $repo.default_branch | Out-File logs\%%r_default_branch.txt -Encoding ascii"
  set /p DEFAULT_BRANCH=<logs\%%r_default_branch.txt
  
  REM Approach 1: WIB timezone
  powershell -Command "$env:GH_TOKEN='%TOKEN%'; $commits = Invoke-RestMethod -Headers @{Authorization = 'Bearer ' + $env:GH_TOKEN; Accept = 'application/vnd.github+json'} -Uri 'https://api.github.com/repos/Faturrachman-dev/%%r/commits?since=%SINCE_WIB%&until=%UNTIL_WIB%'; $commits | ConvertTo-Json -Depth 10 | Out-File logs\%%r_commits_wib.json -Encoding ascii; if ($commits -is [array]) { $count = $commits.Count } else { $count = 0 }; $count | Out-File logs\%%r_count_wib.txt -Encoding ascii"
  set /p REPO_COUNT_WIB=<logs\%%r_count_wib.txt
  set /a TOTAL_COMMITS_WIB+=REPO_COUNT_WIB
  
  if !REPO_COUNT_WIB! GTR 0 (
    echo   [WIB] Found !REPO_COUNT_WIB! commits in %%r
    powershell -Command "$commits = Get-Content logs\%%r_commits_wib.json | ConvertFrom-Json; if ($commits -is [array] -and $commits.Count -gt 0) { foreach ($c in $commits) { Write-Host '  - ' $c.commit.author.date $c.commit.message.Split(\"`n\")[0] } }"
  )
  
  REM Approach 2: UTC dates
  powershell -Command "$env:GH_TOKEN='%TOKEN%'; $commits = Invoke-RestMethod -Headers @{Authorization = 'Bearer ' + $env:GH_TOKEN; Accept = 'application/vnd.github+json'} -Uri 'https://api.github.com/repos/Faturrachman-dev/%%r/commits?since=%SINCE_UTC%&until=%UNTIL_UTC%'; $commits | ConvertTo-Json -Depth 10 | Out-File logs\%%r_commits_utc.json -Encoding ascii; if ($commits -is [array]) { $count = $commits.Count } else { $count = 0 }; $count | Out-File logs\%%r_count_utc.txt -Encoding ascii"
  set /p REPO_COUNT_UTC=<logs\%%r_count_utc.txt
  set /a TOTAL_COMMITS_UTC+=REPO_COUNT_UTC
  
  if !REPO_COUNT_UTC! GTR 0 (
    echo   [UTC] Found !REPO_COUNT_UTC! commits in %%r
    powershell -Command "$commits = Get-Content logs\%%r_commits_utc.json | ConvertFrom-Json; if ($commits -is [array] -and $commits.Count -gt 0) { foreach ($c in $commits) { Write-Host '  - ' $c.commit.author.date $c.commit.message.Split(\"`n\")[0] } }"
  )
  
  REM Approach 3: Wide date range with branch information
  powershell -Command "$env:GH_TOKEN='%TOKEN%'; $commits = Invoke-RestMethod -Headers @{Authorization = 'Bearer ' + $env:GH_TOKEN; Accept = 'application/vnd.github+json'} -Uri 'https://api.github.com/repos/Faturrachman-dev/%%r/commits?since=%SINCE_WIDE%&until=%UNTIL_WIDE%'; $commits | ConvertTo-Json -Depth 10 | Out-File logs\%%r_commits_wide.json -Encoding ascii; if ($commits -is [array]) { $count = $commits.Count } else { $count = 0 }; $count | Out-File logs\%%r_count_wide.txt -Encoding ascii"
  set /p REPO_COUNT_WIDE=<logs\%%r_count_wide.txt
  set /a TOTAL_COMMITS_WIDE+=REPO_COUNT_WIDE
  
  if !REPO_COUNT_WIDE! GTR 0 (
    echo   [WIDE] Found !REPO_COUNT_WIDE! commits in %%r
    echo   Checking branch information:
    
    powershell -Command "$defaultBranch = '%DEFAULT_BRANCH%'.Trim(); $env:GH_TOKEN='%TOKEN%'; $commits = Get-Content logs\%%r_commits_wide.json | ConvertFrom-Json; $defaultCount = 0; $otherCount = 0; Write-Host '  Default branch is:' $defaultBranch; if ($commits -is [array] -and $commits.Count -gt 0) { foreach ($c in $commits) { $branch = 'unknown'; $sha = $c.sha; try { $branchData = Invoke-RestMethod -Headers @{Authorization = 'Bearer ' + $env:GH_TOKEN; Accept = 'application/vnd.github+json'} -Uri ('https://api.github.com/repos/Faturrachman-dev/%%r/commits/' + $sha + '/branches-where-head'); if ($branchData -is [array] -and $branchData.Count -gt 0) { $branch = $branchData[0].name } } catch { Write-Host ('  Error checking branch for commit ' + $sha + ': ' + $_.Exception.Message) }; if ($branch -eq $defaultBranch) { $defaultCount++ } else { $otherCount++ }; Write-Host ('  - ' + $c.commit.author.date + ' ' + $c.commit.message.Split(\"`n\")[0] + ' | Branch: ' + $branch) } }; Write-Host '  Default branch commits:' $defaultCount; Write-Host '  Other branch commits:' $otherCount; $defaultCount | Out-File logs\%%r_default_branch_count.txt -Encoding ascii; $otherCount | Out-File logs\%%r_other_branch_count.txt -Encoding ascii"
    
    set /p REPO_DEFAULT_COUNT=<logs\%%r_default_branch_count.txt
    set /p REPO_OTHER_COUNT=<logs\%%r_other_branch_count.txt
    set /a TOTAL_DEFAULT_BRANCH_COMMITS+=REPO_DEFAULT_COUNT
    set /a TOTAL_OTHER_BRANCH_COMMITS+=REPO_OTHER_COUNT
  )
  
  REM Check issues created/closed in the date range
  powershell -Command "$env:GH_TOKEN='%TOKEN%'; $issues = Invoke-RestMethod -Headers @{Authorization = 'Bearer ' + $env:GH_TOKEN; Accept = 'application/vnd.github+json'} -Uri 'https://api.github.com/repos/Faturrachman-dev/%%r/issues?state=all&since=%SINCE_WIDE%'; $issues | ConvertTo-Json -Depth 10 | Out-File logs\%%r_issues.json -Encoding ascii; $relevantIssues = @(); if ($issues -is [array]) { foreach ($i in $issues) { $created = [datetime]$i.created_at; $updated = [datetime]$i.updated_at; $sinceDate = [datetime]'%SINCE_WIDE%'; $untilDate = [datetime]'%UNTIL_WIDE%'; if (($created -ge $sinceDate -and $created -le $untilDate) -or ($updated -ge $sinceDate -and $updated -le $untilDate)) { $relevantIssues += $i } } }; Write-Host '  Issues activity:' $relevantIssues.Count; foreach ($i in $relevantIssues) { Write-Host '  - ' $i.created_at $i.title }; $relevantIssues.Count | Out-File logs\%%r_issues_count.txt -Encoding ascii"
  set /p REPO_ISSUES=<logs\%%r_issues_count.txt
  set /a TOTAL_ISSUES+=REPO_ISSUES
  
  REM Check pull requests in the date range
  powershell -Command "$env:GH_TOKEN='%TOKEN%'; $prs = Invoke-RestMethod -Headers @{Authorization = 'Bearer ' + $env:GH_TOKEN; Accept = 'application/vnd.github+json'} -Uri 'https://api.github.com/repos/Faturrachman-dev/%%r/pulls?state=all'; $prs | ConvertTo-Json -Depth 10 | Out-File logs\%%r_prs.json -Encoding ascii; $relevantPRs = @(); if ($prs -is [array]) { foreach ($pr in $prs) { $created = [datetime]$pr.created_at; $updated = [datetime]$pr.updated_at; $sinceDate = [datetime]'%SINCE_WIDE%'; $untilDate = [datetime]'%UNTIL_WIDE%'; if (($created -ge $sinceDate -and $created -le $untilDate) -or ($updated -ge $sinceDate -and $updated -le $untilDate)) { $relevantPRs += $pr } } }; Write-Host '  Pull requests activity:' $relevantPRs.Count; foreach ($pr in $relevantPRs) { Write-Host '  - ' $pr.created_at $pr.title }; $relevantPRs.Count | Out-File logs\%%r_prs_count.txt -Encoding ascii"
  set /p REPO_PRS=<logs\%%r_prs_count.txt
  set /a TOTAL_PRS+=REPO_PRS
  
  REM Check code reviews in the date range (less reliable as review comments API is limited)
  powershell -Command "$env:GH_TOKEN='%TOKEN%'; $reviews = Invoke-RestMethod -Headers @{Authorization = 'Bearer ' + $env:GH_TOKEN; Accept = 'application/vnd.github+json'} -Uri 'https://api.github.com/repos/Faturrachman-dev/%%r/pulls/comments'; $reviews | ConvertTo-Json -Depth 10 | Out-File logs\%%r_reviews.json -Encoding ascii; $relevantReviews = @(); if ($reviews -is [array]) { foreach ($r in $reviews) { $created = [datetime]$r.created_at; $sinceDate = [datetime]'%SINCE_WIDE%'; $untilDate = [datetime]'%UNTIL_WIDE%'; if ($created -ge $sinceDate -and $created -le $untilDate) { $relevantReviews += $r } } }; Write-Host '  Code reviews activity:' $relevantReviews.Count; $relevantReviews.Count | Out-File logs\%%r_reviews_count.txt -Encoding ascii"
  set /p REPO_REVIEWS=<logs\%%r_reviews_count.txt
  set /a TOTAL_REVIEWS+=REPO_REVIEWS
  
  echo.
  timeout /t 1 /nobreak >nul
)

echo.
echo ========== RESULTS SUMMARY ========== [%time%]
echo.
echo COMMITS:
echo - Approach 1 (WIB): Found %TOTAL_COMMITS_WIB% total commits
echo - Approach 2 (UTC): Found %TOTAL_COMMITS_UTC% total commits
echo - Approach 3 (WIDE): Found %TOTAL_COMMITS_WIDE% total commits
echo   * Default branch commits: %TOTAL_DEFAULT_BRANCH_COMMITS%
echo   * Other branch commits: %TOTAL_OTHER_BRANCH_COMMITS%
echo.
echo OTHER CONTRIBUTIONS:
echo - Issues created/updated: %TOTAL_ISSUES%
echo - Pull requests created/updated: %TOTAL_PRS%
echo - Code reviews: %TOTAL_REVIEWS%
echo.
powershell -Command "$total = %TOTAL_DEFAULT_BRANCH_COMMITS% + %TOTAL_ISSUES% + %TOTAL_PRS% + %TOTAL_REVIEWS%; Write-Host 'TOTAL CONTRIBUTIONS FOUND: ' $total; $total | Out-File logs\total_contributions.txt -Encoding ascii"
set /p TOTAL_CONTRIBUTIONS=<logs\total_contributions.txt
echo TOTAL CONTRIBUTIONS COUNTED BY GITHUB API: %TOTAL_CONTRIBUTIONS%

REM Create a consolidated list of all contributions in the wider time range
echo.
echo Generating a timeline of all contributions in the wider time range...
powershell -Command "$files = Get-ChildItem logs\*_commits_wide.json; $allCommits = @(); foreach ($file in $files) { $commits = Get-Content $file | ConvertFrom-Json; if ($commits -is [array] -and $commits.Count -gt 0) { $allCommits += $commits } }; $allCommits | Sort-Object { [datetime]$_.commit.author.date } | ForEach-Object { $date = [datetime]$_.commit.author.date; Write-Output \"{0:yyyy-MM-dd HH:mm:ss} - COMMIT - {1} - {2}\" -f $date, $_.repository.name, $_.commit.message.Split(\"`n\")[0] } | Out-File -FilePath logs\contribution_timeline.txt -Encoding ascii"

REM Add issues to the timeline
powershell -Command "$files = Get-ChildItem logs\*_issues.json; foreach ($file in $files) { $issues = Get-Content $file | ConvertFrom-Json; if ($issues -is [array] -and $issues.Count -gt 0) { foreach ($issue in $issues) { $date = [datetime]$issue.created_at; if ($date -ge [datetime]'%SINCE_WIDE%' -and $date -le [datetime]'%UNTIL_WIDE%') { Write-Output \"{0:yyyy-MM-dd HH:mm:ss} - ISSUE - {1} - {2}\" -f $date, $issue.repository_url.Split('/')[-1], $issue.title } } } } | Out-File -FilePath logs\contribution_timeline.txt -Encoding ascii -Append"

REM Add PRs to the timeline
powershell -Command "$files = Get-ChildItem logs\*_prs.json; foreach ($file in $files) { $prs = Get-Content $file | ConvertFrom-Json; if ($prs -is [array] -and $prs.Count -gt 0) { foreach ($pr in $prs) { $date = [datetime]$pr.created_at; if ($date -ge [datetime]'%SINCE_WIDE%' -and $date -le [datetime]'%UNTIL_WIDE%') { Write-Output \"{0:yyyy-MM-dd HH:mm:ss} - PR - {1} - {2}\" -f $date, $pr.base.repo.name, $pr.title } } } } | Out-File -FilePath logs\contribution_timeline.txt -Encoding ascii -Append"

echo Timeline saved to logs\contribution_timeline.txt

REM Check GitHub user events directly
echo.
echo Checking GitHub user events directly...
powershell -Command "$env:GH_TOKEN='%TOKEN%'; $events = Invoke-RestMethod -Headers @{Authorization = 'Bearer ' + $env:GH_TOKEN; Accept = 'application/vnd.github+json'} -Uri 'https://api.github.com/users/Faturrachman-dev/events?per_page=100'; $events | ConvertTo-Json -Depth 10 | Out-File logs\github_events.json -Encoding ascii; $relevantEvents = @(); foreach ($e in $events) { $date = [datetime]$e.created_at; $sinceDate = [datetime]'%SINCE_WIDE%'; $untilDate = [datetime]'%UNTIL_WIDE%'; if ($date -ge $sinceDate -and $date -le $untilDate) { $relevantEvents += $e } }; Write-Host 'Events in date range:' $relevantEvents.Count; $relevantEvents | Group-Object type | ForEach-Object { Write-Host $_.Name ':' $_.Count }; $relevantEvents | ForEach-Object { Write-Output \"{0:yyyy-MM-dd HH:mm:ss} - {1} - {2}\" -f [datetime]$_.created_at, $_.type, $_.repo.name } | Out-File -FilePath logs\github_events.txt -Encoding ascii"

echo.
echo =====================================================
echo All output files saved to "logs" directory for inspection
echo.
echo FINDINGS:
echo 1. Total commits found: %TOTAL_COMMITS_WIDE% (Default: %TOTAL_DEFAULT_BRANCH_COMMITS%, Other: %TOTAL_OTHER_BRANCH_COMMITS%)
echo 2. Other activity: Issues: %TOTAL_ISSUES%, PRs: %TOTAL_PRS%, Reviews: %TOTAL_REVIEWS%
echo 3. Total API-counted contributions: %TOTAL_CONTRIBUTIONS%
echo.
echo Possible reasons for discrepancy between API and contribution graph:
echo 1. Commits to repositories not under your direct ownership (organizations, etc.)
echo 2. Commits in non-default branches not counting in the API but showing in contribution graph
echo 3. GitHub uses internal heuristics for contribution counting not exposed through the API
echo 4. Timezone differences in how commits are counted
echo 5. Activities that aren't captured by our specific API calls
echo.
echo Files to examine:
echo - logs\contribution_timeline.txt - Chronological timeline of all contributions
echo - logs\github_events.txt - Raw events from GitHub's events API
echo - logs\all_repos_list.txt - List of all repositories checked

pause