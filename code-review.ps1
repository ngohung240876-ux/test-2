# Gom toàn bộ diff một lần
$BaseBranch = "main"
git diff origin/$BaseBranch..HEAD > .pr/diff.patch

# Gọi Copilot duy nhất 1 lần
$prompt = Get-Content ".pr/prompt.txt" -Raw
copilot -p $prompt --allow-all-tools > .pr/REVIEW.md
