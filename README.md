# Barcode Deluxe

Flutter app that turns text into a barcode. Input via textbox or camera (OCR).
The barcode type is auto-detected from the content, with a manual override dropdown.

## Detection rules (in order)

1. 8 digits + valid checksum -> EAN-8
2. 12 digits + valid checksum -> UPC-A
3. 13 digits + valid checksum -> EAN-13 (labeled ISBN for 978/979 prefix)
4. 14 digits + valid checksum -> ITF-14
5. Digits only, even length, 4-30 long -> ITF
6. Printable ASCII up to 48 chars -> Code 128
7. Everything else (URLs, long text, unicode) -> QR code

## Result screen

Top to bottom: the **Barcode type** dropdown, the barcode itself, **Scan new
text**, the editable encoded-text box, and a last row of **Regenerate** and
**Download**. The two share that row evenly, so they are always the same size.
Download writes the rendered barcode to the photo gallery.

Editing the box and pressing Regenerate (or Enter in the box) re-encodes with
the new value: detection runs again, so the symbology can change, and any
manual override from the dropdown is dropped along with the content it
belonged to. Regenerate is disabled whenever the box already matches the
barcode on screen, so it can never redraw what is already there — surrounding
whitespace, and an emptied box, do not count as a change.

The box holds the *encoded* string, so an edit made here is taken literally:
the Advanced Options are not re-applied to it. Regenerating records the new
string in the recent inputs like any other barcode.

Tapping any empty part of the screen dismisses the keyboard.

## Recent inputs

The **History** button beside *Generate barcode* — icon only — lists the last
five strings that were actually encoded, newest first. It is disabled until
there is something to list. Tapping an entry pastes it into the text box and
closes the list; pressing History again, tapping empty space, or opening
Advanced Options also closes it. Re-encoding a string moves it back to the
front rather than duplicating it.

Focusing the text box does not open the list.

What is stored is the *encoded* string, i.e. after the Advanced Options have
been applied, so tapping an entry reproduces exactly the barcode you saw. The
list is saved to `shared_preferences` and reloaded in `main()`, so it survives
a restart.

Everything that becomes a barcode is recorded, including a scan started from
**Scan new text** on the result screen. That path replaces the result route
without returning through the home screen, so the home screen tracks
`RecentInputsStore.listenable` rather than only the entries it records itself.

Like the Advanced Options panel it renders into the app `Overlay`, anchored
under the text box, so showing it costs no layout space and the buttons
beneath never move — it does float over them while visible. Opening it drops
keyboard focus, so the two never compete for the same space.

## Advanced options

Both the home screen and the scan screen carry an **Advanced Options** button
that drops down a panel of toggles. They are applied to the input (typed or
scanned) before detection runs, so they can change which symbology is chosen.

| Toggle | Default | Effect |
| --- | --- | --- |
| Remove Spaces | **on** | Strips all whitespace, including tabs and newlines |
| Alphanumeric only | **on** | Drops punctuation, symbols and non-ASCII letters; leaves whitespace alone |


