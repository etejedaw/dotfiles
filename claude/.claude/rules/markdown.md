Never hard-wrap Markdown. Each paragraph, list item and table cell goes on a single line, however long it is.

Line width does not matter in Markdown: the editor soft-wraps it in code view, and in preview the Markdown reflows to the screen width on its own (MarkText, for example). Nobody ever sees the file's width, so breaking the line solves nothing — and it costs you clean diffs, because touching one word reflows the whole paragraph. Manual breaks at a fixed width also show up as broken lines in viewers that render every newline as a line break.

Do not count columns while writing Markdown. Write the paragraph straight through and let the editor wrap it visually.

- Applies to every `.md` file you write, whatever it is for.
- Line breaks are only for real structure: between paragraphs, list items, headings, table rows and inside code blocks.
- When editing a file that already has hard-wrapped text, join the lines of the block you touch.
