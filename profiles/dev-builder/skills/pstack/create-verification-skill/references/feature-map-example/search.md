# Search notes

Search lets a user find notes by title or body, open a result, distinguish no matches, and clear the query.

## Sub-features

- `search-open` opens search from each supported entry point.
- `search-match` finds title and body matches.
- `search-open-result` opens a matching note.
- `search-empty` displays a complete no-results state.
- `search-clear` restores the default view.
- `search-cli` performs the same search through the CLI.

## How to get to it (user POV)

- Choose `Search` in the browser.
- Use the documented search keyboard shortcut.
- Run `notes search <query>`.

## Driving it with control-notes

Preconditions:

- The app is healthy in an owned disposable environment.
- Seed data contains a known title and body term.
- Doctor confirms the expected URL and data directory.

- **Open:** exercise every documented entry point.
- **Match:** search title and body terms and verify included and excluded records.
- **Open result:** select a result and verify the correct record appears.
- **Empty state:** search an absent value and verify the completed no-results state.
- **Clear:** clear the query and verify the default view returns.
- **CLI:** verify matching and absent queries with a stable machine-readable format.
- **Proof:** capture query, result state, app identity, and command exit information.

## Gotchas

- Wait for an observable result instead of a fixed sleep when search is debounced.
- Keyboard shortcuts may type text when an input owns focus.
- Opening a result changes state; reopen search before the next proof.
