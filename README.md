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

## Barcode Screen

Displays the **Barcode type** used, in a dropdown, alongside the barcode itself. This screen includes a few other elements. **Scan new
text** switches to the camera, the editable encoded-text box allows the user to edit the barcode's text, **Regenerate** will use the
changed text to generate a new barcode, and **Download** which saves the barcode in the device's gallery. 

Both this box and the one on the home screen carry a clear (×) button on
their right edge, which appears only while there is something to clear.

Editing the box and pressing Regenerate (or Enter in the box) re-encodes with
the new value: detection runs again, so the symbology can change, and any
manual override from the dropdown is dropped along with the content it
belonged to.

## Recent inputs

The **History** button beside *Generate barcode* lists the last
five strings that were generated into barcodes.

## Advanced options

Both the home screen and the scan screen carry an **Advanced Options** button
that drops down a panel of toggles. They are applied to the input (typed or
scanned) before detection runs, so they can change which symbology is chosen.

| Toggle | Default | Effect |
| --- | --- | --- |
| Remove Spaces | **on** | Strips all whitespace, including tabs and newlines |
| Alphanumeric only | **on** | Drops punctuation, symbols and non-ASCII letters; leaves whitespace alone |


