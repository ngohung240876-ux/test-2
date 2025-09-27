# Generate consolidated diff file
$BaseBranch = "main"
git diff origin/$BaseBranch..HEAD > .pr/diff.patch

# Run Copilot review once with consolidated diff
$prompt = Get-Content ".pr/prompt.txt" -Raw
$reviewResult = & copilot -p $prompt --allow-all-tools 2>&1
$reviewResult | Out-File -FilePath ".pr/REVIEW.md" -Encoding UTF8
