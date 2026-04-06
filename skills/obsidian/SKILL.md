---
name: obsidian
description: Work with Obsidian vaults — read, search, create, and edit Markdown notes. Uses the Obsidian CLI when available, falls back to direct file operations otherwise.
homepage: https://help.obsidian.md
metadata:
  {
    "openclaw":
      {
        "emoji": "💎",
      },
  }
---

# Obsidian

An Obsidian vault is a plain folder on disk. Every note is a Markdown file.

## Vault structure

- Notes: `*.md` (plain Markdown, any editor can read/write them)
- Config: `.obsidian/` (app settings, plugins, themes — **do not modify** from scripts)
- Canvases: `*.canvas` (JSON-based visual layout)
- Attachments: configured folder (often `attachments/` or `assets/`; check `.obsidian/app.json` → `attachmentFolderPath`)
- Bases: `*.base` (structured data views)

## Obsidian Markdown syntax

Standard Markdown plus these extensions:

### Internal links (wikilinks)

```
[[Note Name]]                  → link to note
[[Note Name|display text]]     → aliased link
[[Note Name#Heading]]          → link to heading
[[Note Name#^block-id]]        → link to block
```

### Embeds

```
![[Note Name]]                 → embed entire note
![[Note Name#Heading]]         → embed section
![[image.png]]                 → embed image
![[file.pdf]]                  → embed PDF
```

### Tags

```
#tag                           → inline tag
#nested/tag                    → nested tag
```

Tags can also appear in frontmatter:

```yaml
---
tags: [meeting, project/alpha]
---
```

### Callouts

```markdown
> [!info] Title
> Callout body text.

> [!warning]
> Another callout.
```

Types: `note`, `abstract`, `info`, `tip`, `success`, `question`, `warning`, `failure`, `danger`, `bug`, `example`, `quote`.

### Task lists

```markdown
- [ ] Incomplete task
- [x] Completed task
- [-] Cancelled task
- [?] Question
```

### Frontmatter (properties)

YAML block at the very start of the file:

```yaml
---
title: My Note
date: 2026-04-06
tags: [research, ai]
aliases: [my-note, alternate-name]
last-edited-by: agent-name
---
```

Standard properties: `tags`, `aliases`, `cssclasses`, `date`, `publish`.

## Mode selection

Check whether the `obsidian` binary is available:

```bash
command -v obsidian
```

- **Available** → use CLI commands (faster, vault-aware search and link updates).
- **Not available** → use direct file operations (works in any environment).

The Obsidian CLI requires the desktop app to be running. If the app is not running, the first CLI command launches it.

## CLI mode

Reference: <https://obsidian.md/help/cli>

### Targeting vaults and files

```bash
# Target a specific vault (must be first parameter)
obsidian vault=Notes <command>
obsidian vault="My Vault" <command>

# Target a file by name (link resolution, no extension needed)
obsidian read file=Recipe

# Target a file by exact path from vault root
obsidian read path="Folder/Recipe.md"

# Default: the currently active file
obsidian read
```

### Search

```bash
# Search vault — returns matching file paths
obsidian search query="meeting notes"
obsidian search query="TODO" path=Projects limit=20

# Search with line context (grep-style path:line: output)
obsidian search:context query="meeting notes"
obsidian search:context query="deadline" format=json
```

### Read

```bash
obsidian read                              # active file
obsidian read file=Recipe                  # by name
obsidian read path="Projects/Roadmap.md"   # by path
```

### Create

```bash
obsidian create name="New Note" content="# Title\n\nBody text"
obsidian create path="Projects/Idea.md" content="..." open
obsidian create name="From Template" template=Meeting
```

Parameters: `name`, `path`, `content`, `template`. Flags: `overwrite`, `open`, `newtab`.

### Append and prepend

```bash
obsidian append content="- New item" file=TODO
obsidian prepend content="## Update" path="Log.md"
obsidian daily:append content="- [ ] Buy groceries"
```

Flag `inline` appends without a leading newline.

### Move, rename, and delete

```bash
obsidian move file=Recipe to="Archive/Cooking"    # updates internal links
obsidian rename file=Recipe name="Best Recipe"     # updates internal links
obsidian delete file="Old Note"                    # moves to trash
obsidian delete file="Old Note" permanent          # permanent delete
```

### Daily notes

```bash
obsidian daily                                    # open today's daily note
obsidian daily:path                               # get daily note path
obsidian daily:read                               # read daily note content
obsidian daily:append content="- [ ] New task"    # append to daily note
obsidian daily:prepend content="## Morning"       # prepend to daily note
```

### Tags

```bash
obsidian tags                          # list all tags
obsidian tags counts sort=count        # list with counts, sorted
obsidian tag name=project              # get tag info
obsidian tags active                   # tags for active file
```

### Tasks

```bash
obsidian tasks                         # list all tasks
obsidian tasks todo                    # incomplete tasks only
obsidian tasks done                    # completed tasks only
obsidian tasks daily                   # tasks from daily note
obsidian task ref="Recipe.md:8" toggle # toggle task status
obsidian task file=Recipe line=8 done  # mark done
```

### Properties (frontmatter)

```bash
obsidian properties                                 # list all properties
obsidian properties active                          # properties of active file
obsidian property:read name=tags file=Recipe        # read a property
obsidian property:set name=status value=done file=Recipe
obsidian property:remove name=draft file=Recipe
```

### Links and backlinks

```bash
obsidian backlinks file=Recipe             # files linking TO this note
obsidian links file=Recipe                 # outgoing links FROM this note
obsidian unresolved                        # broken links in vault
obsidian orphans                           # files with no incoming links
```

### Outline

```bash
obsidian outline file=Recipe               # heading tree
obsidian outline file=Recipe format=md     # as Markdown list
```

### Templates

```bash
obsidian templates                        # list templates
obsidian template:read name=Meeting       # read template content
obsidian create name="Standup" template=Meeting
```

### Vault info

```bash
obsidian vault                            # show vault info
obsidian vaults verbose                   # list all vaults with paths
obsidian files total                      # total file count
obsidian folders                          # list folders
```

### Copy output

Append `--copy` to any command to copy output to the clipboard:

```bash
obsidian read file=Recipe --copy
obsidian search query="TODO" --copy
```

## File mode

When the CLI is not available, work with vault files directly.

### Read

```bash
cat "vault-path/Note.md"
```

### Search

```bash
# Search content (prefer rg if available, grep as fallback)
rg "pattern" --type md "vault-path/"
grep -r "pattern" --include="*.md" "vault-path/"

# Search file names
find "vault-path/" -name "*.md" | grep -i "query"

# List all tags in vault
rg -o '#[a-zA-Z0-9/_-]+' --type md --no-filename "vault-path/" | sort -u
```

### Create

Write a new `.md` file with frontmatter:

```bash
cat > "vault-path/Folder/New Note.md" << 'EOF'
---
date: 2026-04-06
tags: [topic]
---

# New Note

Content here.
EOF
```

### Edit

Read the file, modify, write back. **Prefer append** over full rewrites for existing notes:

```bash
echo -e "\n## New Section\n\nAdditional content." >> "vault-path/Note.md"
```

### Move and rename

Moving or renaming requires updating all wikilinks that reference the file:

```bash
# 1. Find all files linking to the note
rg -l '\[\[Old Name' --type md "vault-path/"

# 2. Update references in those files
sed -i '' 's/\[\[Old Name/[[New Name/g' file1.md file2.md

# 3. Move the file
mv "vault-path/Old Name.md" "vault-path/Folder/New Name.md"
```

### Properties (frontmatter)

Read frontmatter by extracting the YAML block between `---` delimiters at the start of the file. Set properties by editing that block directly.

### Backlinks

```bash
# Find all notes linking to a specific note
rg '\[\[Target Note' --type md "vault-path/"

# Find all notes linking to a note (including aliased links)
rg '\[\[Target Note(\||\]\])' --type md "vault-path/"
```

## Multi-agent conventions

When multiple agents share a vault:

- **Read freely** — all agents may read any file.
- **Prefer append** over full file rewrites to reduce conflicts.
- **Check before editing** — before a major edit, check the last author:
  ```bash
  git log -1 --format="%an %ai" -- "path/to/note.md"
  ```
- **Mark edits** — set frontmatter property `last-edited-by: <agent-id>` when editing a note.
- **Unique names** — use date prefixes (`2026-04-06 Topic.md`) or topic folders to avoid naming collisions.
- **No concurrent writes** — do not write to a file another agent is currently editing.
