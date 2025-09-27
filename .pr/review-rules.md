## C# Code Review Checklist

### General
- [ ] Access modifiers are made as private as possible

### Maintainence
- [ ] All names are clear, descriptive and accurate. Clear naming is preferred over comments
- [ ] Well-named enums are used instead of magic strings and numbers
- [ ] Functions avoid side effects
- [ ] Conditionals should be positive, not negative
- [ ] Methods do not accept more than 3 parameters
- [ ] All methods and classes do just one thing / follow SRP
- [ ] SOLID principles are adhered to
- [ ] All code has passed linting

### Performance and Scalability
- [ ] Reviewer has stepped through all modified code paths using a performance data set to look for performance / memory / CPU usage issues
- [ ] Appropriate data structures have been used
- [ ] async / await is used for I/O bound code paths

## REVIEW.md Format Requirements

The generated REVIEW.md must follow this exact format:

### File Header
```markdown
# Code Review Report
Generated on: YYYY-MM-DD HH:MM:SS
Base branch: [branch_name]
Reviewer: PowerShell Script + GitHub Copilot CLI

---
```

### For Each File
```markdown
## File: [filename]

### Summary
Brief description of changes

### Issues Found
- **CRITICAL**: Use for blocking issues that must be fixed
- **WARNING**: Use for issues that should be fixed
- **SUGGESTION**: Use for optional improvements

### Recommendations
Provide specific, actionable code examples using:
```csharp
// Example code here
```

### Review Checklist
| Rule | Status | Notes |
|------|--------|--------|
| Clear naming | ✅ or ❌ | Comments |
| No magic numbers | ✅ or ❌ | Comments |
| Performance | ✅ or ❌ | Comments |

### Final Recommendation
**APPROVE** / **APPROVE WITH CHANGES** / **REQUEST CHANGES** / **REJECT**
```

### Encoding Requirements
- Use UTF-8 encoding only
- No special Unicode characters beyond basic emojis (✅ ❌ ⚠️)
- Clean ASCII text for compatibility