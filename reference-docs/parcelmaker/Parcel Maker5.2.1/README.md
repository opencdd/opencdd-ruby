# `Parcel Maker5.2.1/` — ParcelMaker 5.2.1 MSI contents

This directory contains the OLE-storage stream dump of the
`Parcel Maker5.2.1.msi` installer in the parent directory. Each file
is one OLE stream written verbatim. The stream names — which include
leading numeric prefixes (`0Binary`, `0Component`, ...) — are the
raw MSI table-stream identifiers preserved byte-for-byte.

## About `0x05SummaryInformation`

The original OLE stream name is the 19-byte literal
`\x05SummaryInformation` (where `\x05` is the ASCII ENQ control
character). This is the canonical OLE compound-document stream name
for the SummaryInformation property set, defined by MSOLE spec.

It was committed that way historically. Git for Windows cannot
materialize a filename starting with `0x05` (Windows API rejects
control characters in filenames; `?` is substituted in the error
message), so CI checkout failed on Windows runners.

The file was renamed to `0x05SummaryInformation` — the leading
backslash-x-05 form preserves the original byte value in the
filename as printable text, while remaining Windows-safe. File
content is unchanged.

The MSI itself (`../Parcel Maker5.2.1.msi`) is the canonical source;
this directory is a derived extraction provided for diagnostic
convenience when reverse-engineering the ParcelMaker installer.
