# Lessons

## Communication
- Report the fix, not the autopsy. One line on what changed, then what to do
  next. No ranking of my own wrong turns unless asked.

## Debugging someone else's device
- Ask for a screenshot before shipping a fix for a cause I have only inferred.
- Desktop Chrome is not a proxy for Android WebView. Limits that only exist on
  the device (data: URL size, older CSS support) are invisible from here.
- Never `catch` into a silent fallback. If it can fail on a phone I cannot see,
  it has to say so on screen.
