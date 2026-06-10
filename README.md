# repoRuby
All Ruby scripts for
    1-Members_V25
    2-Private
    3-Web
## UI helpers (PrvDocuments_Updates.rb)
`PrvDocuments_Updates.rb` now includes lightweight UI helper methods to improve terminal readability:
- `ui_step(title)`: wraps a major phase in a visual frame (or plain text fallback).
- `ui_info(message)`: displays informational text with `cli-ui` styling when available.
- `ui_ok(message)`: displays success/confirmation messages in a consistent format.
- `ui_spin(title)`: runs long operations inside a spinner and prints elapsed duration at completion.

Notes:
- `cli-ui` is optional: if the gem is not installed, helpers fallback to standard `puts`.
- Current spinner usage covers database loading operations (`Dossiers`, `Tags`, `Types`, `Senders`, `FilesUpload`).
