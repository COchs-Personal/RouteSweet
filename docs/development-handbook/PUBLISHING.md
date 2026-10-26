# Maintaining the formatted editions

The seven numbered Markdown chapters are the maintained source. `publication.json` records the edition title, chapter order, contents groups, and layout choice. `figures/` contains the original vector diagrams rendered from the Mermaid blocks; the same diagrams are embedded in the editable Word edition.

For a quick correction without an automated publisher, open `Development_Handbook.docx` in Word or LibreOffice, make the same correction in the relevant Markdown chapter, update document fields and the contents page, and export a fresh PDF. Keep the Word and PDF editions on the same revision. Do not edit only the PDF and leave the source and editable edition disagreeing. Preserve native heading/table styles, readable code, diagram captions, source references, and page-number fields.

A full regeneration uses a Markdown-to-Word publisher supporting the supplied manifest, then LibreOffice export. The current documents use 11-point Liberation Sans body text, native heading and table styles, DejaVu Sans/Mono for diagrams/code, linked contents, and embedded diagrams. Use a separate temporary build directory; do not install document tooling into the application's dependencies or commit page-image previews/caches. The maintained Markdown and editable Word edition remain usable without the original publishing environment.

After any content/layout change, render every page and inspect it at readable size. Check headings, contents page numbers, source links, table continuation headers, code wrapping, arrows and labels, margins, and footers. Review both what a proposed repair says and whether it is clearly distinguished from implemented behavior. Keep the source baseline explicit; a new documentation date does not qualify an unchanged runtime.

The Word, PDF, and vector figures are intentional final reference assets. Temporary render images, build logs, user paths, credentials, runtime state, and production data do not belong in the commit. Keep files within the repository's asset limits and update applicable attribution records when regenerating figures or embedded-font assets.
