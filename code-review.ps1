param(
    [string]$BaseBranch = "main",
    [switch]$CleanupPatchFiles = $false,
    [switch]$Verbose = $false,
    [switch]$Help = $false,
    [switch]$AutoFix = $true
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
    -AutoFix                 Automatically fix issues found in review (default: true)
    -Help                    Show this help message

EXAMPLES:
    .\code-review.ps1                           # Basic review against main with auto-fix
    .\code-review.ps1 -BaseBranch develop       # Review against develop branch
    .\code-review.ps1 -Verbose -CleanupPatchFiles  # Verbose output with cleanup
    .\code-review.ps1 -AutoFix:$false           # Review only, no auto-fix

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
                        
                        $reviewResult = & copilot -p $prompt --allow-all-tools 2>&1
                        if ($LASTEXITCODE -eq 0) {
                            # Clean up encoding issues and format the output
                            $cleanedResult = $reviewResult -replace '[^\x00-\x7F]', '' -replace 'Γ[^A-Za-z0-9\s]*', '✅' -replace 'Γ[^A-Za-z0-9\s]*', '⚠️'
                            $cleanedResult | Add-Content -Path $reviewFile -Encoding UTF8
                        } else {
                            "**AI Review Failed:** $reviewResult" | Add-Content -Path $reviewFile
                        }
                    }
                    catch {
                        "**AI Review Error:** $($_.Exception.Message)" | Add-Content -Path $reviewFile
                    }
                }else {
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
        
        # Step 2: Auto-fix issues if review recommendation is not APPROVE
        if ($AutoFix) {
            Write-Info "Checking if auto-fix is needed based on review recommendations..."
            $reviewContent = Get-Content $reviewFile -Raw
            
            if ($reviewContent -match "APPROVE WITH CHANGES|REQUEST CHANGES|REJECT" -and $reviewContent -notmatch "^\*\*APPROVE\*\*(?!\s+WITH)") {
            Write-Info "Review found issues that need fixing. Running auto-fix..."
            
            # Use Copilot CLI to generate fixes
            if ($copilotAvailable) {
                try {
                    $fixPrompt = @"
Based on the code review report in $reviewFile, automatically fix the identified issues in the source files. 
Focus on:
1. Extracting magic numbers to named constants
2. Improving code structure and maintainability
3. Addressing performance concerns where possible
4. Following the review rules in $reviewRulesFile

Apply the fixes directly to the source files and provide a summary of changes made.
"@
                    
                    Write-Info "Running AI-powered auto-fix..."
                    $fixResult = & copilot -p $fixPrompt --allow-all-tools 2>&1
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-Info "Auto-fix completed successfully!"
                        
                        # Append fix summary to review file
                        "`n---`n`n## Auto-Fix Summary`n" | Add-Content -Path $reviewFile -Encoding UTF8
                        "Generated on: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")`n" | Add-Content -Path $reviewFile -Encoding UTF8
                        
                        # Clean up encoding issues in fix result
                        $cleanedFixResult = $fixResult -replace '[^\x00-\x7F\r\n]', '' -replace 'Γ[^A-Za-z0-9\s]*', '✅'
                        $cleanedFixResult | Add-Content -Path $reviewFile -Encoding UTF8
                        
                        # Check if any files were modified
                        $modifiedAfterFix = git status --porcelain 2>$null
                        if ($modifiedAfterFix) {
                            Write-Info "Files were modified during auto-fix:"
                            Write-Host $modifiedAfterFix -ForegroundColor Yellow
                            
                            # Re-run review on fixed files
                            Write-Info "Re-running review on fixed files..."
                            $postFixReviewFile = ".pr/REVIEW-AFTER-FIX.md"
                            
                            # Create header for post-fix review
                            @"
# Post-Fix Code Review Report
Generated on: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Base branch: $BaseBranch
Reviewer: PowerShell Script + GitHub Copilot CLI (After Auto-Fix)

---

"@ | Out-File -FilePath $postFixReviewFile -Encoding UTF8

                            # Quick review of changes after fix
                            $postFixPrompt = @"
Review the current state of the modified files after auto-fix has been applied. 
Check if the previously identified issues have been resolved:
1. Are magic numbers now properly extracted to constants?
2. Have performance concerns been addressed?
3. Is the code following the review rules in $reviewRulesFile?

Provide a brief assessment of whether the fixes were successful.
"@
                            
                            $postFixReview = & copilot -p $postFixPrompt --allow-all-tools 2>&1
                            if ($LASTEXITCODE -eq 0) {
                                $cleanedPostFix = $postFixReview -replace '[^\x00-\x7F\r\n]', ''
                                $cleanedPostFix | Add-Content -Path $postFixReviewFile -Encoding UTF8
                                Write-Info "Post-fix review saved to: $postFixReviewFile"
                            }
                        } else {
                            Write-Warning "No files were modified during auto-fix. Manual intervention may be required."
                        }
                    } else {
                        Write-Warning "Auto-fix failed: $fixResult"
                        "**Auto-Fix Failed:** $fixResult" | Add-Content -Path $reviewFile -Encoding UTF8
                    }
                }
                catch {
                    Write-Error "Auto-fix error: $($_.Exception.Message)"
                    "**Auto-Fix Error:** $($_.Exception.Message)" | Add-Content -Path $reviewFile -Encoding UTF8
                }
            } else {
                Write-Warning "Auto-fix requires GitHub Copilot CLI. Please install it to enable automatic issue resolution."
                "`n## Auto-Fix Not Available`nGitHub Copilot CLI is required for automatic issue resolution." | Add-Content -Path $reviewFile -Encoding UTF8
            }
            } else {
                Write-Info "Review approved! No auto-fix needed."
            }
        } else {
            Write-Info "Auto-fix disabled. Use -AutoFix to enable automatic issue resolution."
        }
    }
}
catch {
    Write-Error "Script failed: $($_.Exception.Message)"
    exit 1
}
