param(
    [string]$BaseBranch = "main",
    [switch]$Verbose = $false
)

$ErrorActionPreference = "Stop"

function Write-Info {
    param([string]$Message)
    if ($Verbose) { Write-Host "INFO: $Message" -ForegroundColor Green }
}

try {
    # Ensure we're in a git repository
    if (-not (Test-Path ".git")) {
        throw "Not in a git repository. Please run this script from the root of a git repository."
    }

    # Create .pr directory if it doesn't exist
    if (-not (Test-Path ".pr")) {
        New-Item -ItemType Directory -Path ".pr" | Out-Null
        Write-Info "Created .pr directory"
    }

    # Generate diff file
    Write-Info "Generating diff against origin/$BaseBranch..."
    git diff origin/$BaseBranch..HEAD > .pr/diff.patch
    
    if (-not (Test-Path ".pr/diff.patch") -or (Get-Content ".pr/diff.patch" -Raw).Length -eq 0) {
        Write-Warning "No changes found between origin/$BaseBranch and HEAD"
        return
    }

    # Create default prompt if it doesn't exist
    if (-not (Test-Path ".pr/prompt.txt")) {
        @"
Review the code changes in .pr/diff.patch following the rules in .pr/review-rules.md.
Provide a clear status: **APPROVED** if everything is fine, otherwise **REQUEST CHANGES**.
Focus on code quality, maintainability, and adherence to the review checklist.
"@ | Out-File -FilePath ".pr/prompt.txt" -Encoding UTF8
        Write-Info "Created default prompt file"
    }

    # Run Copilot review
    Write-Info "Running code review with Copilot..."
    $prompt = Get-Content ".pr/prompt.txt" -Raw
    $reviewResult = & copilot $prompt 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        $reviewResult | Out-File -FilePath ".pr/REVIEW.md" -Encoding UTF8
        Write-Info "Review completed successfully"
    } else {
        Write-Error "Copilot review failed: $reviewResult"
    }
}
catch {
    Write-Error "Script failed: $($_.Exception.Message)"
    exit 1
}
