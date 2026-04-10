# agent-skills

Personal collection of AI agent definitions, skills, and templates — packaged for [APM](https://github.com/microsoft/apm).

## Contents

### Agents

| Agent | Description |
|-------|-------------|
| [research-assistant](agents/research-assistant.agent.md) | Automates ML experiments and the scientific process — hypothesis generation, literature grounding, experiment execution, and result interpretation. |

### Skills

| Skill | Description |
|-------|--------------|
| [research-project-init](skills/research-project-init/SKILL.md) | Scaffold a new ML research project repo with standardized structure, MLflow tracking, and research-assistant integration. |
| [research-assistant](skills/research-assistant/SKILL.md) | Scientific loop workflow for automated ML experimentation with MLflow tracking and NotebookLM literature grounding. |
| [idea-to-speckit](skills/idea-to-speckit/SKILL.md) | Transform fuzzy ideas into well-crafted prompts for spec-driven development using Spec Kit. |

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
│   └── research-assistant.agent.md          # Agent definition
├── prompts/
│   └── AutoSpecKit.prompt.md                # SpecKit end-to-end orchestration
├── skills/
│   ├── research-project-init/
│   │   └── SKILL.md                         # Scaffold new research repos
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
│   └── idea-to-speckit/
│       └── SKILL.md
```
