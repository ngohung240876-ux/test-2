param(
    [string]$BaseBranch = "main"
)

$ErrorActionPreference = "Stop"

# Tạo folder .pr nếu chưa có
if (-not (Test-Path ".pr")) {
    New-Item -ItemType Directory -Path ".pr" | Out-Null
}

# File kết quả review tổng hợp
$reviewFile = ".pr/REVIEW.md"
if (Test-Path $reviewFile) { Remove-Item $reviewFile }
New-Item -ItemType File -Path $reviewFile | Out-Null

Write-Host "=== Step 1: Lấy danh sách file thay đổi ==="
$changedFiles = git diff --name-only origin/$BaseBranch..HEAD

foreach ($file in $changedFiles) {
    Write-Host ">>> Review file: $file"
    $patchFile = ".pr/diff-$($file -replace '[\\/]', '_').patch"

    # Xuất diff của từng file
    git diff origin/$BaseBranch..HEAD -- $file > $patchFile

    # Gọi Copilot CLI để review patch và append vào REVIEW.md
    copilot "Review patch in $patchFile using review-rules.md. Append results with clear heading '### $file'." `
        >> $reviewFile
}

Write-Host "=== Review xong, lưu kết quả vào $reviewFile ==="
