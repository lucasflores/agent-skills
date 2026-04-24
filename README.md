# agent-skills

Personal collection of AI agent definitions, skills, and templates — packaged for [APM](https://github.com/microsoft/apm).

## Contents

### Agents

| Agent | Description |
|-------|-------------|
| [research-assistant](agents/research-assistant.agent.md) | Automates ML experiments and the scientific process — hypothesis generation, literature grounding, experiment execution, and result interpretation. |
| [evolve-framework-research-assistant](agents/evolve-framework-research-assistant.agent.md) | Specialized research assistant for evolve-framework experiments. Composes the generic research workflow with UnifiedConfig, dry_run, and evolution-specific interpretation. |

### Skills

| Skill | Description |
|-------|--------------|
| [commit-pipeline](skills/commit-pipeline/SKILL.md) | Smart, context-aware commit pipeline: stage files, enforce atomic commits, commit with Conventional Commits format, resolve pre-commit pipeline changes, rebase on origin/main, open PR, wait for automated Copilot PR review, resolve comments, and commit fixes. Dev-stack aware. |
| [dev-stack-install](skills/dev-stack-install/SKILL.md) | Install and fully configure dev-stack in any Python repo — greenfield or brownfield. Produces a fully wired 9-stage pre-commit pipeline, all generated artifacts, and a passing first commit. |
| [dev-stack-update](skills/dev-stack-update/SKILL.md) | Update a repo previously set up with dev-stack when new artifacts, modules, or pipeline changes land in a newer CLI version. Handles module version diffs, deprecated module migration, conflict resolution, and safe rollback. |
| [evolve-research-project](skills/evolve-research-project/SKILL.md) | Set up a research project using evolve-framework for evolutionary optimization experiments. Handles dependency configuration, config-to-UnifiedConfig bridging, and MLflow tracking integration. |
| [idea-to-speckit](skills/idea-to-speckit/SKILL.md) | Transform fuzzy ideas into well-crafted prompts for spec-driven development using Spec Kit. |
| [research-assistant](skills/research-assistant/SKILL.md) | Scientific loop workflow for automated ML experimentation with MLflow tracking and NotebookLM literature grounding. |
| [research-project-init](skills/research-project-init/SKILL.md) | Scaffold a new ML research project repo with standardized structure, MLflow tracking, and research-assistant integration. |

### Prompts

| Prompt | Description |
|--------|-------------|
| [AutoSpecKit](prompts/AutoSpecKit.prompt.md) | One command to run SpecKit end-to-end. Creates constitution if missing, then ships the feature. |

## Installation

```bash
apm install lucasflores/agent-skills
```

## Layout

```
agent-skills/
├── apm.yml                                  # APM package manifest
├── agents/
│   ├── evolve-framework-research-assistant.agent.md
│   └── research-assistant.agent.md          # Agent definitions
├── prompts/
│   └── AutoSpecKit.prompt.md                # SpecKit end-to-end orchestration
├── skills/
│   ├── commit-pipeline/
│   │   ├── SKILL.md                         # Smart commit + PR pipeline
│   │   └── references/
│   │       ├── commit-format.md             # Conventional Commits format + trailers
│   │       ├── dev-stack-pipeline.md        # Stage artifact map + silent failure guide
│   │       └── file-staging-rules.md        # File classification: stage vs gitignore
│   ├── dev-stack-install/
│   │   └── SKILL.md                         # Install dev-stack in any Python repo
│   ├── dev-stack-update/
│   │   └── SKILL.md                         # Update dev-stack artifacts and modules
│   ├── evolve-research-project/
│   │   ├── SKILL.md                         # Set up evolve-framework research project
│   │   └── references/
│   │       ├── config-pattern.md
│   │       ├── config-reference.md
│   │       └── framework-api.md
│   ├── idea-to-speckit/
│   │   └── SKILL.md                         # Idea → SpecKit prompt
│   ├── research-assistant/
│   │   ├── SKILL.md                         # Core scientific loop skill
│   │   ├── references/                      # Detailed workflow docs
│   │   │   ├── batch-execution.md
│   │   │   ├── code-proposals.md
│   │   │   ├── experiment-execution.md
│   │   │   ├── git-integration.md
│   │   │   ├── hypothesis-generation.md
│   │   │   ├── notebooklm-integration.md
│   │   │   ├── project-bootstrap.md
│   │   │   ├── result-interpretation.md
│   │   │   └── status-reporting.md
│   │   └── templates/                       # State file templates
│   │       ├── config.yaml
│   │       ├── experiment-state.md
│   │       ├── framework-context.md
│   │       ├── proposal.md
│   │       ├── research-log.md
│   │       └── toolkit-context.md
│   └── research-project-init/
│       └── SKILL.md                         # Scaffold new research repos
```
