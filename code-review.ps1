# Gom toàn bộ diff một lần
$BaseBranch = "main"
git diff origin/$BaseBranch..HEAD > .pr/diff.patch
# Gọi Copilot duy nhất 1 lần
copilot -p "Review changes in .pr/diff.patch using .pr/review-rules.md. Summarize issues per file, actionable feedback, and overall status." --allow-all-tools > .pr/REVIEW.md