# PowerShell script to count GitHub contributions locally
# This is equivalent to the GitHub Actions workflow but runs in PowerShell

# Load GitHub token from .env file or prompt user
$EnvFile = ".env"
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        if ($_ -match "GITHUB_TOKEN=(.*)") {
            $GITHUB_TOKEN = $matches[1]
        }
    }
}

if (-not $GITHUB_TOKEN) {
    $GITHUB_TOKEN = Read-Host "Enter your GitHub personal access token"
}

# Set up dates
$yesterday = (Get-Date).AddDays(-1).ToString("yyyy-MM-dd")
$yesterdayStartUTC = [DateTime]::ParseExact("$yesterday 00:00:00", "yyyy-MM-dd HH:mm:ss", $null).AddHours(-7).ToString("yyyy-MM-ddTHH:mm:ssZ")
$yesterdayEndUTC = [DateTime]::ParseExact("$yesterday 23:59:59", "yyyy-MM-dd HH:mm:ss", $null).AddHours(-7).ToString("yyyy-MM-ddTHH:mm:ssZ")

$monthStart = (Get-Date).ToString("yyyy-MM-01")
$monthStartUTC = [DateTime]::ParseExact("$monthStart 00:00:00", "yyyy-MM-dd HH:mm:ss", $null).AddHours(-7).ToString("yyyy-MM-ddTHH:mm:ssZ")
$currentMonth = (Get-Date).ToString("yyyy-MM")

$lastDayOfMonth = [DateTime]::DaysInMonth((Get-Date).Year, (Get-Date).Month)
$monthEnd = (Get-Date).ToString("yyyy-MM-$lastDayOfMonth")
$monthEndUTC = [DateTime]::ParseExact("$monthEnd 23:59:59", "yyyy-MM-dd HH:mm:ss", $null).AddHours(-7).ToString("yyyy-MM-ddTHH:mm:ssZ")

Write-Host "Counting yesterday's contributions since: $($yesterdayStartUTC) (00:00 WIB yesterday)"
Write-Host "Counting this month's contributions since: $($monthStartUTC) (start of $currentMonth)"

# Function to count GitHub events directly using the GitHub API
function Count-Contributions {
    param(
        [string]$sinceDate,
        [string]$untilDate,
        [string]$dayKey
    )
    
    Write-Host "Fetching contributions from $($sinceDate) to $($untilDate)..."
    
    # Initialize counters
    $pushEvents = 0
    $totalCommits = 0
    $createEvents = 0
    $issuesEvents = 0
    $issueComments = 0
    $prEvents = 0
    $prReviews = 0
    $prReviewComments = 0
    $commitComments = 0
    $forkEvents = 0
    $watchEvents = 0
    $releaseEvents = 0
    $publicEvents = 0
    
    # Fetch and process GitHub events (up to 3 pages)
    for ($page = 1; $page -le 3; $page++) {
        Write-Host "Fetching events page $page..."
        
        # Set up headers for the API request
        $headers = @{
            "Authorization" = "Bearer $GITHUB_TOKEN"
            "Accept" = "application/vnd.github+json"
        }
        
        # Make the API request
        try {
            $response = Invoke-RestMethod -Uri "https://api.github.com/users/Faturrachman-dev/events?per_page=100&page=$page" -Headers $headers -Method Get
        }
        catch {
            Write-Host "Error fetching events: $_"
            break
        }
        
        # Check if array is empty
        if ($response.Count -eq 0) {
            Write-Host "No more events found."
            break
        }
        
        # Process each event
        $eventCount = $response.Count
        Write-Host "Processing $eventCount events from page $page..."
        
        foreach ($event in $response) {
            # Extract event properties
            $eventType = $event.type
            $eventDate = $event.created_at
            
            # Debug output for the first event of each page
            if ($event -eq $response[0]) {
                Write-Host "Sample event: type=$eventType, date=$($eventDate)"
            }
            
            # Skip events outside our date range
            if ([string]::IsNullOrEmpty($eventDate) -or 
                ([DateTime]$eventDate -lt [DateTime]$sinceDate) -or 
                ([DateTime]$eventDate -gt [DateTime]$untilDate)) {
                continue
            }
            
            # Count by event type
            switch ($eventType) {
                "PushEvent" {
                    $pushEvents++
                    if ($event.payload.PSObject.Properties.Name -contains "size" -and $event.payload.size -match "^\d+$") {
                        $totalCommits += [int]$event.payload.size
                    }
                }
                "CreateEvent" { $createEvents++ }
                "IssuesEvent" { $issuesEvents++ }
                "IssueCommentEvent" { $issueComments++ }
                "PullRequestEvent" { $prEvents++ }
                "PullRequestReviewEvent" { $prReviews++ }
                "PullRequestReviewCommentEvent" { $prReviewComments++ }
                "CommitCommentEvent" { $commitComments++ }
                "ForkEvent" { $forkEvents++ }
                "WatchEvent" { $watchEvents++ }
                "ReleaseEvent" { $releaseEvents++ }
                "PublicEvent" { $publicEvents++ }
            }
        }
        
        # Check if there are more pages
        if ($eventCount -lt 100) {
            Write-Host "No more pages to fetch."
            break
        }
        
        # Add a small delay to avoid rate limiting
        Start-Sleep -Seconds 1
    }
    
    # Calculate total contributions
    $otherContributions = $createEvents + $issuesEvents + $issueComments + $prEvents + $prReviews + 
                       $prReviewComments + $commitComments + $forkEvents + $watchEvents + 
                       $releaseEvents + $publicEvents
    $totalContributions = $totalCommits + $otherContributions
    
    # Output result summary
    Write-Host "Contribution summary for period $($sinceDate) to $($untilDate):"
    Write-Host "  Push events: $pushEvents (with $totalCommits commits)"
    Write-Host "  Create events: $createEvents"
    Write-Host "  Issues events: $issuesEvents"
    Write-Host "  Issue comments: $issueComments"
    Write-Host "  PR events: $prEvents"
    Write-Host "  PR reviews: $prReviews"
    Write-Host "  PR review comments: $prReviewComments"
    Write-Host "  Commit comments: $commitComments"
    Write-Host "  Fork events: $forkEvents"
    Write-Host "  Watch events: $watchEvents"
    Write-Host "  Release events: $releaseEvents"
    Write-Host "  Public events: $publicEvents"
    Write-Host "  Total contributions: $totalContributions"
    
    # Create and return a result object
    $result = @{
        "TotalContributions" = $totalContributions
        "TotalCommits" = $totalCommits
        "OtherContributions" = $otherContributions
    }
    
    return $result
}

# Count yesterday's contributions
Write-Host "Counting yesterday's contributions from $($yesterdayStartUTC) to $($yesterdayEndUTC)"
$yesterdayResults = Count-Contributions -sinceDate $yesterdayStartUTC -untilDate $yesterdayEndUTC -dayKey "TODAY_CONTRIBUTIONS"

# Count the entire month's contributions
Write-Host "Counting contributions for the entire month..."
$monthResults = Count-Contributions -sinceDate $monthStartUTC -untilDate $monthEndUTC -dayKey "MONTH_ALL"

# Display final summary
Write-Host "`nFinal Summary:"
Write-Host "  Yesterday's commits: $($yesterdayResults.TotalCommits)"
Write-Host "  Yesterday's other contributions: $($yesterdayResults.OtherContributions)"
Write-Host "  Yesterday's total contributions: $($yesterdayResults.TotalContributions)"
Write-Host "  This month's commits: $($monthResults.TotalCommits)"
Write-Host "  This month's total contributions: $($monthResults.TotalContributions)"

# Ask if user wants to update the README
$updateReadme = Read-Host "Do you want to update your README with these statistics? (y/n)"
if ($updateReadme -eq "y") {
    
    # Path to your README file (change this if needed)
    $readmePath = "README.md"
    
    if (Test-Path $readmePath) {
        $readmeContent = Get-Content $readmePath -Raw
        
        # Update TODAY_COMMITS
        if ($readmeContent -match "<!-- TODAY_COMMITS: \d+ -->") {
            $readmeContent = $readmeContent -replace "<!-- TODAY_COMMITS: \d+ -->", "<!-- TODAY_COMMITS: $($yesterdayResults.TotalCommits) -->"
        }
        else {
            $readmeContent += "`n<!-- TODAY_COMMITS: $($yesterdayResults.TotalCommits) -->`n"
            $readmeContent += "![Yesterday's Commits](https://img.shields.io/badge/Yesterday's%20Commits-$($yesterdayResults.TotalCommits)-blue)`n"
        }
        
        # Update badge for yesterday's commits
        if ($readmeContent -match "Yesterday's%20Commits-\d+-blue") {
            $readmeContent = $readmeContent -replace "(Yesterday's%20Commits-)\d+(-blue)", "`$1$($yesterdayResults.TotalCommits)`$2"
        }
        
        # Update TODAY_CONTRIBUTIONS
        if ($readmeContent -match "<!-- TODAY_CONTRIBUTIONS: \d+ -->") {
            $readmeContent = $readmeContent -replace "<!-- TODAY_CONTRIBUTIONS: \d+ -->", "<!-- TODAY_CONTRIBUTIONS: $($yesterdayResults.TotalContributions) -->"
        }
        else {
            $readmeContent += "`n<!-- TODAY_CONTRIBUTIONS: $($yesterdayResults.TotalContributions) -->`n"
            $readmeContent += "![Yesterday's Contributions](https://img.shields.io/badge/Yesterday's%20Contributions-$($yesterdayResults.TotalContributions)-purple)`n"
        }
        
        # Update badge for yesterday's contributions
        if ($readmeContent -match "Yesterday's%20Contributions-\d+-purple") {
            $readmeContent = $readmeContent -replace "(Yesterday's%20Contributions-)\d+(-purple)", "`$1$($yesterdayResults.TotalContributions)`$2"
        }
        
        # Update MONTH_COMMITS
        if ($readmeContent -match "<!-- MONTH_COMMITS: \d+ [\d\-]+ -->") {
            $readmeContent = $readmeContent -replace "<!-- MONTH_COMMITS: \d+ [\d\-]+ -->", "<!-- MONTH_COMMITS: $($monthResults.TotalCommits) $currentMonth -->"
        }
        else {
            $readmeContent += "`n<!-- MONTH_COMMITS: $($monthResults.TotalCommits) $currentMonth -->`n"
            $readmeContent += "![This Month's Commits](https://img.shields.io/badge/This%20Month's%20Commits-$($monthResults.TotalCommits)-green)`n"
        }
        
        # Update badge for monthly commits
        if ($readmeContent -match "This%20Month's%20Commits-\d+-green") {
            $readmeContent = $readmeContent -replace "(This%20Month's%20Commits-)\d+(-green)", "`$1$($monthResults.TotalCommits)`$2"
        }
        
        # Update MONTH_CONTRIBUTIONS
        if ($readmeContent -match "<!-- MONTH_CONTRIBUTIONS: \d+ [\d\-]+ -->") {
            $readmeContent = $readmeContent -replace "<!-- MONTH_CONTRIBUTIONS: \d+ [\d\-]+ -->", "<!-- MONTH_CONTRIBUTIONS: $($monthResults.TotalContributions) $currentMonth -->"
        }
        else {
            $readmeContent += "`n<!-- MONTH_CONTRIBUTIONS: $($monthResults.TotalContributions) $currentMonth -->`n"
            $readmeContent += "![This Month's Contributions](https://img.shields.io/badge/This%20Month's%20Contributions-$($monthResults.TotalContributions)-orange)`n"
        }
        
        # Update badge for monthly contributions
        if ($readmeContent -match "This%20Month's%20Contributions-\d+-orange") {
            $readmeContent = $readmeContent -replace "(This%20Month's%20Contributions-)\d+(-orange)", "`$1$($monthResults.TotalContributions)`$2"
        }
        
        # Save the updated README
        $readmeContent | Set-Content $readmePath
        Write-Host "README updated successfully!"
    }
    else {
        Write-Host "README file not found at $readmePath"
    }
}

Write-Host "`nDone!" 