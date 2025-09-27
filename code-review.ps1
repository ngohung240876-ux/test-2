param(
    [string]$BaseBranch = "main",
    [switch]$CleanupPatchFiles = $false,
    [switch]$Verbose = $false,
    [switch]$Help = $false
)

if ($Help) {
    @"
PowerShell Code Review Script

USAGE:
    .\code-review.ps1 [OPTIONS]

OPTIONS:
    -BaseBranch <string>     Base branch to compare against (default: main)
    -CleanupPatchFiles       Remove old patch files before generating new ones
    -Verbose                 Show detailed output during execution
    -Help                    Show this help message

EXAMPLES:
    .\code-review.ps1                           # Basic review against main
    .\code-review.ps1 -BaseBranch develop       # Review against develop branch
    .\code-review.ps1 -Verbose -CleanupPatchFiles  # Verbose output with cleanup

REQUIREMENTS:
    - Git repository
    - GitHub Copilot CLI (optional, for AI-powered reviews)
    - .pr/review-rules.md file (recommended)

OUTPUT:
    - .pr/REVIEW.md: Main review report
    - .pr/diff-*.patch: Individual file diffs
"@
    exit 0
}

$ErrorActionPreference = "Stop"

function Write-Info {
    param([string]$Message)
    Write-Host "INFO: $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "WARNING: $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "ERROR: $Message" -ForegroundColor Red
}

try {
    # Validate git repository
    if (-not (Test-Path ".git")) {
        throw "Not in a git repository. Please run this script from the root of a git repository."
    }

    # Check if GitHub Copilot CLI is available
    $copilotAvailable = Get-Command "copilot" -ErrorAction SilentlyContinue
    if (-not $copilotAvailable) {
        Write-Warning "GitHub Copilot CLI not found. Install with: npm install -g @github/copilot-cli"
        Write-Warning "Continuing without AI review - will only generate diff files."
    }

    # Create .pr directory if it doesn't exist
    if (-not (Test-Path ".pr")) {
        New-Item -ItemType Directory -Path ".pr" | Out-Null
        Write-Info "Created .pr directory"
    }

    # Check if review rules exist
    $reviewRulesFile = ".pr/review-rules.md"
    if (-not (Test-Path $reviewRulesFile)) {
        Write-Warning "Review rules file not found at $reviewRulesFile"
    }

    # Clean up old patch files if requested
    if ($CleanupPatchFiles) {
        Get-ChildItem ".pr" -Filter "diff-*.patch" | Remove-Item -Force
        Write-Info "Cleaned up old patch files"
    }

    # Initialize review output file
    $reviewFile = ".pr/REVIEW.md"
    if (Test-Path $reviewFile) { 
        Remove-Item $reviewFile 
        Write-Info "Removed existing review file"
    }

    # Create header for review file
    @"
# Code Review Report
Generated on: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Base branch: $BaseBranch
Reviewer: PowerShell Script + GitHub Copilot CLI

---

"@ | Out-File -FilePath $reviewFile -Encoding UTF8

    Write-Info "Getting list of changed files..."
    
    # Get changed files - handle the case where there might be no changes
    $changedFiles = @()
    try {
        $gitOutput = git diff --name-only "origin/$BaseBranch..HEAD" 2>&1
        if ($LASTEXITCODE -eq 0 -and $gitOutput) {
            $changedFiles = $gitOutput | Where-Object { $_.Trim() -ne "" }
        }
    }
    catch {
        Write-Error "Failed to get git diff: $_"
        throw
    }

    if ($changedFiles.Count -eq 0) {
        $message = "No files changed between origin/$BaseBranch and HEAD"
        Write-Warning $message
        "## No Changes Found`n`n$message" | Add-Content -Path $reviewFile
        return
    }

    Write-Info "Found $($changedFiles.Count) changed file(s)"
    if ($Verbose) {
        $changedFiles | ForEach-Object { Write-Host "  - $_" }
    }

    foreach ($file in $changedFiles) {
        Write-Info "Processing: $file"
        
        # Create safe filename for patch
        $safeFileName = $file -replace '[\\/:*?"<>|]', '_'
        $patchFile = ".pr/diff-$safeFileName.patch"

        try {
            # Generate diff for the file
            $diffContent = git diff "origin/$BaseBranch..HEAD" -- $file
            if ($diffContent) {
                $diffContent | Out-File -FilePath $patchFile -Encoding UTF8
                
                if ($Verbose) {
                    Write-Host "  Generated patch: $patchFile"
                }

                # Add file header to review
                "`n## File: $file`n" | Add-Content -Path $reviewFile

                # Use Copilot CLI if available
                if ($copilotAvailable) {
                    try {
                        Write-Info "Running AI review for $file..."
                        $prompt = "Review the code changes in $patchFile following the guidelines in $reviewRulesFile. Focus on code quality, maintainability, and potential issues. Provide specific, actionable feedback."
                        
                        $reviewResult = & copilot $prompt 2>&1
                        if ($LASTEXITCODE -eq 0) {
                            $reviewResult | Add-Content -Path $reviewFile
                        } else {
                            "**AI Review Failed:** $reviewResult" | Add-Content -Path $reviewFile
                        }
                    }
                    catch {
                        "**AI Review Error:** $_" | Add-Content -Path $reviewFile
                    }
                } else {
                    @"
**Manual Review Required** (GitHub Copilot CLI not available)

Diff file: $patchFile
Please review this file manually using the guidelines in $reviewRulesFile

``````diff
$diffContent
``````

"@ | Add-Content -Path $reviewFile
                }
            } else {
                Write-Warning "No diff content found for $file"
            }
        }
        catch {
            Write-Error "Failed to process ${file}: $($_.Exception.Message)"
            "**Error processing ${file}:** $($_.Exception.Message)`n" | Add-Content -Path $reviewFile
        }
    }

    Write-Info "Review completed successfully!"
    Write-Info "Results saved to: $reviewFile"
    
    if ($changedFiles.Count -gt 0) {
        Write-Info "Generated patch files in .pr/ directory"
        if ($CleanupPatchFiles) {
            Write-Info "Use -CleanupPatchFiles to remove patch files after review"
        }
    }
}
catch {
    Write-Error "Script failed: $($_.Exception.Message)"
    exit 1
}
