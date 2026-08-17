# Documents

This folder is the default location for new Huawei Cloud documents created
with the templates in this project.

## Creating a new document

1. Run the skill for the template you want to use:
   ```
   /skill huawei-template-guide
   ```
2. The skill will create a subfolder here, e.g. `documents/my-guide/`,
   with all necessary files (`.tex`, `.latexmkrc`, `assets/`).
3. Compile from inside the project folder:
   ```
   cd documents/my-guide
   latexmk main.tex
   ```

## Structure

Each document is self-contained in its own subfolder:

```
documents/
+-- my-guide/
    +-- main.tex           # the document
    +-- .latexmkrc         # XeLaTeX + TEXINPUTS → templates/guide/
    +-- assets/            # project-specific images
```

The `documents/` folder is gitignored by default (only `documents/README.md`
is tracked). To force-track a document in version control, use
`git add -f <path>`.
