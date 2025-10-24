# Workspaces Management Plugin

Oh My Zsh plugin for managing git worktrees across multiple microservices with integrated specification templates for Claude Code.

## Features

- **Worktree Management**: Create and manage git worktrees across multiple projects
- **Automatic Template Integration**: Automatically create spec documents for Claude Code
- **Multi-Project Support**: Work on features across multiple repositories simultaneously
- **Smart Branch Management**: Consistent branch naming and tracking
- **IntelliJ Integration**: Automatic project opening
- **Java Version Management**: Automatically creates `.java-version` files from `pom.xml`
- **Safety Features**: Preflight checks and validation

## Installation

1. Create the plugin directory:
```bash
mkdir -p ~/.oh-my-zsh/custom/plugins/workspaces
```

2. Copy the plugin file:
```bash
cp workspaces.plugin.zsh ~/.oh-my-zsh/custom/plugins/workspaces/workspaces.plugin.zsh
```

3. Add the plugin to your `~/.zshrc`:
```bash
# Find the plugins line and add 'workspaces' to the list
plugins=(git ... workspaces)
```

4. Reload your shell:
```bash
source ~/.zshrc
```

5. **(Optional)** Set up spec templates:
```bash
mkdir -p ~/Work/templates
# Copy your template files to ~/Work/templates/
```

## Configuration

You can customize the plugin by editing these variables at the top of `workspaces.plugin.zsh`:

```bash
WORK_DIR="$HOME/Work"                  # Base work directory
PROJECTS_DIR="$WORK_DIR/projects"      # Where main repos live
WORKTREES_DIR="$WORK_DIR/worktrees"    # Where worktrees are created
TEMPLATES_DIR="$WORK_DIR/templates"    # Where spec templates are stored
MAIN_BRANCH="master"                   # Main branch name
```

## Template System

The plugin automatically creates specification documents when you create new worktrees. These specs are designed to work seamlessly with Claude Code.

### Available Templates

Place these templates in `~/Work/templates/`:

- `template-feature-implementation.md` - For new features (default for `nf`)
- `template-bug-fix.md` - For bug fixes (default for `nb`)
- `template-api-integration.md` - For API integrations
- `template-quick-task.md` - For quick tasks
- `template-refactoring.md` - For refactoring work
- `template-system-design.md` - For system design

### How It Works

1. **Automatic Creation**: When you run `nf` or `nb`, a spec is automatically created
2. **Smart Defaults**: 
   - `nf` (new-feature) → uses `template-feature-implementation.md`
   - `nb` (new-bug) → uses `template-bug-fix.md`
3. **Pre-filled Information**: Templates are automatically customized with:
   - Feature/bug name
   - Branch name
   - Creation date
   - Project names
4. **Location**: Spec is created as `SPEC.md` in the worktree root

### Using Spec Templates

**Basic usage (automatic):**
```bash
# Creates feature with feature template
nf payment-flow

# Creates bug with bug template  
nb null-pointer-fix
```

**Override template type:**
```bash
# Create feature but use API integration template
nf payment-gateway --spec api

# Create bug but use quick task template
nb typo-fix --spec quick
```

**Available spec types for --spec flag:**
- `feature` - Feature implementation template
- `bug` / `bugfix` - Bug fix template
- `api` - API integration template
- `quick` / `task` - Quick task template
- `refactor` / `refactoring` - Refactoring template
- `system` / `design` - System design template

### Workflow with Claude Code

1. **Create worktree with spec**:
   ```bash
   nf user-authentication
   ```

2. **Edit the generated SPEC.md**:
   - Fill in requirements
   - Add acceptance criteria
   - Define technical details

3. **Hand off to Claude Code**:
   ```bash
   cd ~/Work/worktrees/user-authentication
   # Open SPEC.md in your editor, then use Claude Code
   ```

## Commands

### `new-feature <feature-name> [type] [--spec <template-type>]`
Create a new workspace with worktrees across multiple projects.

**Alias:** `nf`

**Examples:**
```bash
# Basic feature creation (uses feature template)
nf payment-flow

# With specific type
nf payment-flow hotfix

# Override template
nf payment-flow --spec api

# Chore with refactoring template
nf cleanup-logging chore --spec refactor
```

**What it does:**
1. Prompts you to select the work type (feature, bugfix, hotfix, or chore)
2. Creates a worktree directory at `~/Work/worktrees/payment-flow/`
3. Prompts you to select which projects to include
4. **Preflight check:** Validates all selected repositories
5. For each selected project:
   - Checks out and pulls the latest `master` branch
   - Creates a worktree with branch `<type>/payment-flow`
   - Pushes the branch to remote with upstream tracking
   - **Creates `.java-version`** file from `pom.xml` if one doesn't exist
6. **Creates SPEC.md** from appropriate template with pre-filled information
7. Asks which project to open in IntelliJ IDEA

### `new-bug <bug-name> [--spec <template-type>]`
Convenience command for creating bug-related worktrees (automatically uses `bugfix/` branch prefix).

**Alias:** `nb`

**Examples:**
```bash
# Basic bug fix (uses bug template)
nb null-pointer-checkout

# Override template
nb typo-in-header --spec quick
```

This skips the type selection prompt and directly creates a `bugfix/` branch with the bug fix template.

### `checkout-worktree <branch-name> [project1 project2 ...] [--all]`
Checkout an existing remote branch into worktrees (for reviewing or collaborating on colleague's work).

**Alias:** `cw`

**Usage patterns:**
```bash
# Fast: Only check specified projects (recommended)
cw feature/payment-flow arrakis wallet

# Slower: Search all projects when you're not sure where the branch is
cw feature/payment-flow --all

# Interactive: Prompt which projects to check
cw feature/payment-flow
```

**Note:** When checking out existing branches, specs are not automatically created since they should already exist.

### `switch-worktree [feature-name]`
Quickly switch to a worktree directory with tab completion.

**Alias:** `sw`

**Features:**
- Tab completion for worktree names
- Interactive list if no name provided
- Choose which project to cd into
- Optionally open in IntelliJ

**Example:**
```bash
# Tab complete to see available worktrees
sw <TAB>

# Switch to specific worktree
sw payment-flow

# Or just run without arguments for interactive selection
sw
```

### `list-worktrees`
List all active worktrees and their projects.

**Alias:** `lw`

**Example:**
```bash
list-worktrees
# or
lw
```

### `sync-worktree [feature-name] [merge|rebase]`
Sync a worktree with the latest changes from master branch.

**Alias:** `sync`

**Features:**
- Auto-detects current worktree if you're inside one
- Tab completion for worktree names and strategies
- Choice between merge or rebase (default: merge)
- Checks for uncommitted changes before syncing
- Syncs all projects in the worktree
- Optionally pushes changes to remote

**Examples:**
```bash
# Sync current worktree (auto-detected)
sync

# Sync specific worktree with merge
sync payment-flow

# Sync specific worktree with rebase
sync payment-flow rebase

# Tab completion works
sync <TAB>               # Shows worktree names
sync payment-flow <TAB>  # Shows merge/rebase
```

### `remove-worktree [feature-name]`
Remove a worktree and optionally clean up branches.

**Alias:** `rw`

**Features:**
- Tab completion for worktree names
- Interactive list if no name provided
- Smart branch cleanup options
- Removes SPEC.md along with worktree

**Example:**
```bash
# Tab complete to see available worktrees
rw <TAB>

# Remove specific worktree
rw payment-flow

# Or run interactively to see list
rw
```

### `check-repos`
Check the status of all main repositories and identify which ones have uncommitted changes.

**Alias:** `cr`

Use this before running `new-feature` to ensure your repositories are ready.

### `cleanup-empty`
Remove empty worktree directories (directories that have no project subdirectories).

**Alias:** `ce`

This is useful for cleaning up failed worktree creations or partially deleted worktrees.

### `check-intellij`
Check if IntelliJ IDEA is properly installed and can be launched automatically.

**Alias:** `ci`

Use this command to troubleshoot if projects aren't opening automatically.

### `switch-to-ssh`
Convert all repositories from HTTPS to SSH to avoid username/password prompts.

## Workflow Examples

### Creating a feature with spec:
```bash
$ nf user-authentication

What type of work is this?
  1) Feature
  2) Bug/Bugfix
  3) Hotfix
  4) Chore

Enter number [1]: 1

🚀 Setting up workspace for: user-authentication
Branch type: feature
Spec template: feature

Available projects:
  1) arrakis
  2) hermes
  3) wallet

Enter project numbers to include (space-separated): 1 3

Selected projects: arrakis wallet

🔍 Preflight check: validating all repositories...

✓  arrakis - ready
✓  wallet - ready

✓ All repositories ready!

━━━ Processing arrakis ━━━
  📥 Updating master branch...
  🌳 Creating worktree with branch feature/user-authentication...
  📤 Pushing branch to remote...
    ✓ Branch pushed and tracking set
  ☕ Checking Java version...
    ✓ Created .java-version (11)
  ✓ arrakis worktree created successfully

━━━ Processing wallet ━━━
  ...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Workspace setup complete!

Worktree location: ~/Work/worktrees/user-authentication
Branch name: feature/user-authentication
Projects created: arrakis wallet

📄 Creating specification document...
  ✓ Created spec from template: template-feature-implementation.md
    Location: ~/Work/worktrees/user-authentication/SPEC.md

Which project would you like to open in IntelliJ?
  1) arrakis
  2) wallet
  0) None

Enter number: 1
🚀 Opening in IntelliJ IDEA...
```

### Creating a bug fix with spec:
```bash
$ nb null-pointer-checkout

🚀 Setting up workspace for: null-pointer-checkout
Branch type: bugfix
Spec template: bug

# ... creates worktree with bug fix template
```

### Using a custom template:
```bash
$ nf api-integration --spec api

# Creates feature worktree with API integration template
```

### Complete development cycle:
```bash
# 1. Create feature with spec
nf payment-gateway

# 2. Edit SPEC.md with requirements
cd ~/Work/worktrees/payment-gateway
vim SPEC.md

# 3. Hand off to Claude Code
# (Use Claude Code with the SPEC.md file)

# 4. Sync with master periodically
sync

# 5. When done, clean up
rw payment-gateway
```

## Directory Structure

After running the command, your structure will look like:

```
Work/
├── projects/
│   ├── arrakis/          (main repo - unchanged)
│   ├── wallet/           (main repo - unchanged)
│   └── mercury/          (main repo - unchanged)
├── templates/
│   ├── template-feature-implementation.md
│   ├── template-bug-fix.md
│   ├── template-api-integration.md
│   ├── template-quick-task.md
│   ├── template-refactoring.md
│   └── template-system-design.md
└── worktrees/
    └── user-authentication/
        ├── SPEC.md       (generated from template)
        ├── arrakis/      (worktree with feature/user-authentication branch)
        └── wallet/       (worktree with feature/user-authentication branch)
```

## Quick Reference

```bash
# Create worktrees with specs
nf payment-flow              # Feature with feature template
nb payment-crash             # Bug with bug template
nf api-setup --spec api      # Feature with API template
nb typo --spec quick         # Bug with quick task template

# Navigate and sync
sw <TAB>                     # Switch to worktree (tab completion)
sync                         # Sync current worktree with master
sync feature rebase          # Sync with rebase

# Review and cleanup
lw                           # List worktrees
cw feature/xyz arrakis       # Fast checkout of colleague's work
rw <TAB>                     # Remove worktree (tab completion)

# Maintenance
cr                           # Check repo status
ce                           # Cleanup empty directories
ci                           # Check IntelliJ installation
switch-to-ssh                # Convert repos to SSH
```

## Tips

- **Templates are optional**: If templates directory doesn't exist or template not found, worktrees are created normally without spec
- **Edit templates**: Customize the templates in `~/Work/templates/` to match your team's standards
- **Spec location**: `SPEC.md` is always created in the worktree root, not in individual project directories
- **Pre-filled fields**: Templates automatically include feature name, branch name, date, and project names
- **Claude Code integration**: The specs are designed to provide Claude Code with all context needed for implementation
- **Version control**: Commit `SPEC.md` to git along with your code for documentation
- Feature names are automatically sanitized (lowercased, spaces replaced with hyphens)
- Branch types available: `feature/`, `bugfix/`, `hotfix/`, `chore/`
- Use `nb` (new-bug) for a quick way to create bugfix branches without the type prompt
- **All or nothing**: `nf`/`nb` validates ALL repos before creating ANY worktrees
- Run `switch-to-ssh` once to avoid username/password prompts when pulling from GitHub
- **Quick navigation**: Use `sw` with tab completion to jump between worktrees instantly
- **Stay in sync**: Run `sync` regularly to incorporate master changes into your feature branches
- **Merge vs Rebase**: Use `sync` for merge (safe) or `sync <name> rebase` for cleaner history

## IntelliJ IDEA Integration

The plugin automatically detects and opens projects in IntelliJ IDEA using multiple methods:

1. **Command-line launcher** (if installed via Tools → Create Command-line Launcher)
2. **macOS application** (if installed in /Applications/)

### Setup Options

**Option 1: Install in /Applications/ (easiest)**
- Install IntelliJ IDEA to `/Applications/IntelliJ IDEA.app`
- No additional setup needed

**Option 2: Create command-line launcher**
1. Open IntelliJ IDEA
2. Go to **Tools** → **Create Command-line Launcher...**
3. Keep the default location and click OK

### Troubleshooting

If projects aren't opening automatically, run:
```bash
ci
# or
check-intellij
```

This will show you what's detected and help diagnose issues.

## Java Version Management

The plugin automatically creates `.java-version` files for Java microservices to ensure consistent Java versions across team members. This feature works with tools like `jenv`, `sdkman`, and other Java version managers.

### How It Works

When creating worktrees (`nf`, `nb`, `cw`), the plugin:

1. **Checks for existing `.java-version`** - Skips creation if file already exists
2. **Scans `pom.xml`** for Java version using multiple patterns:
   - `<java.version>11</java.version>`
   - `<maven.compiler.source>11</maven.compiler.source>`
   - `<maven.compiler.target>11</maven.compiler.target>`
   - `<source>11</source>` in maven-compiler-plugin
   - Properties section version definitions
3. **Creates `.java-version`** file with the detected version

### Supported Patterns

The plugin recognizes these common Maven configurations:

```xml
<!-- Pattern 1: Properties -->
<properties>
    <java.version>11</java.version>
</properties>

<!-- Pattern 2: Compiler plugin properties -->
<properties>
    <maven.compiler.source>11</maven.compiler.source>
    <maven.compiler.target>11</maven.compiler.target>
</properties>

<!-- Pattern 3: Maven compiler plugin configuration -->
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-compiler-plugin</artifactId>
    <configuration>
        <source>11</source>
        <target>11</target>
    </configuration>
</plugin>
```

### Benefits

- **Consistent Development Environment**: All team members use the same Java version
- **IDE Integration**: IDEs automatically detect and use the correct Java version
- **CI/CD Compatibility**: Build systems can read `.java-version` for version selection
- **Tool Integration**: Works with `jenv`, `sdkman`, `asdf`, and other version managers

## Template Customization

### Creating Your Own Templates

1. Create a new markdown file in `~/Work/templates/`
2. Use placeholders that will be replaced:
   - `[Feature Name]` - Will be replaced with the feature name
   - `[Brief Description]` - Will be replaced with feature name for bugs
3. Add header metadata (will be auto-inserted):
   - **Created**: Date
   - **Branch**: Branch name
   - **Projects**: List of projects

### Example Custom Template

```markdown
# [Feature Name] Implementation

**Type**: Custom Workflow

## Overview
[Description of what needs to be done]

## Requirements
- [ ] Requirement 1
- [ ] Requirement 2

## Implementation Notes
[Technical details]

## Testing
- [ ] Unit tests
- [ ] Integration tests

## Deployment
[Deployment notes]
```

Save this as `template-custom.md` and use it with:
```bash
nf my-feature --spec custom
```

## FAQ

**Q: What if I don't have templates set up?**
A: The plugin will show a warning but continue creating worktrees normally. Templates are optional.

**Q: Can I modify the templates after they're created?**
A: Yes! Edit `~/Work/templates/*` files anytime. Changes will apply to new worktrees.

**Q: Does checkout-worktree create specs?**
A: No, specs are only created for new work (`nf`, `nb`). Existing branches should already have specs.

**Q: What if the template doesn't exist?**
A: The plugin shows a warning and skips spec creation. The worktree is still created normally.

**Q: Can I use templates without Claude Code?**
A: Absolutely! The templates are useful for any development workflow as documentation.

**Q: Where should I commit the SPEC.md file?**
A: Commit it to the branch you're working on. It serves as living documentation for your feature.

## License

MIT
