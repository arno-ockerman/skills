# Create a note

Create note lets a user save a titled note, cancel an unfinished draft, and confirm persistence from a second user-facing view.

## Sub-features

- `create-open` opens a blank editor.
- `create-save` persists a title and body.
- `create-cancel` discards an unfinished draft.
- `create-cli` creates the same note shape from the terminal.

## How to get to it (user POV)

- Choose `New note` in the browser.
- Press `n` while focus is outside an editable field.
- Run `notes create --title <title> --body <body>`.

## Driving it with control-notes

Preconditions:

- Notes is healthy at its expected URL.
- The test title does not already exist.
- `control-notes doctor` reports the expected disposable instance.

- **Open:** activate `New note` and verify the editor appears.
- **Enter:** fill a concrete title and body and verify save becomes available.
- **Save:** activate save and verify a visible acknowledgement.
- **Confirm:** reopen the saved note from another user-facing view and verify both values.
- **Cancel:** create a second draft, cancel it, and verify it is absent.
- **Proof:** capture the action, resulting state, and a second read of persisted data.

## Gotchas

- Keyboard shortcuts behave differently while an editable field has focus.
- A save notification alone is insufficient proof; reopen the record.
- Cleanup removes disposable records but preserves proof artifacts.
