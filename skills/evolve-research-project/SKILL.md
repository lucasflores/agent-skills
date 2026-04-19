---
name: evolve-research-project
description: "Set up a research project that uses evolve-framework for evolutionary optimization experiments. Handles dependency configuration, config-to-UnifiedConfig bridging, MLflow tracking integration, and experiment script scaffolding. Use when: creating a new evolve-framework research project, setting up ESPO/soft-prompt evolution experiments, integrating evolve-framework into a research repo, or debugging evolve-framework integration issues. Triggers: 'evolve-framework project', 'evolutionary optimization experiment', 'soft prompt evolution', 'ESPO experiment', 'use evolve-framework'."
---

# Evolve-Framework Research Project Setup

Set up research projects that use `evolve-framework` for evolutionary optimization.

## Critical Knowledge

Hard-won lessons. Violating any wastes significant debugging time.

### 1. Do NOT reimplement framework classes

`evolve-framework` provides these — use them directly, never rewrite:

| Need | Use | Import |
|------|-----|--------|
| Evolution config | `UnifiedConfig` | `from evolve.config import UnifiedConfig` |
| Tracking config | `TrackingConfig` | `from evolve.config import TrackingConfig` |
| Build engine | `create_engine()` | `from evolve.factory.engine import create_engine` |
| Build population | `create_initial_population()` | `from evolve.factory.engine import create_initial_population` |
| Wrap a callable | pass directly to `create_engine()` | — (auto-wrapped in `FunctionEvaluator`) |
| Cost estimation | `dry_run()` | `from evolve.experiment.dry_run import dry_run` |
| MLflow tracking | `TrackingCallback` | Built automatically by `create_engine()` when `tracking.enabled=True` |

If you find yourself writing a class named `UnifiedConfig`, `TrackingConfig`, or a function named `create_engine` — **STOP**. You are reinventing the framework.

### 2. Fitness construction

`Fitness` is a frozen dataclass wrapping a NumPy array. **Do not** use `Fitness(value=1.0)` — that field doesn't exist.

```python
import numpy as np
from evolve.core.types import Fitness

# CORRECT — single-objective
f = Fitness.scalar(1.0)

# CORRECT — multi-objective
f = Fitness(values=np.array([0.5, 0.3]))

# WRONG — will raise TypeError
f = Fitness(value=1.0)
```

### 3. create_engine() accepts plain callables

No need to wrap your fitness function in `FunctionEvaluator` — `create_engine()` does it automatically:

```python
import numpy as np

def sphere(genes):
    return float(np.sum(genes**2))

# CORRECT — callable passed directly
engine = create_engine(config, sphere, seed=42)

# ALSO CORRECT — explicit FunctionEvaluator
from evolve.evaluation.evaluator import FunctionEvaluator
engine = create_engine(config, FunctionEvaluator(sphere), seed=42)
```

### 4. Use JSON configs, not YAML

`UnifiedConfig` has native JSON support — `from_file()`, `from_json()`, `to_file()`, `to_json()`. All field names match exactly (no renaming needed). YAML adds an unnecessary parsing + field-mapping layer.

```python
# Load config from JSON file
config = UnifiedConfig.from_file("configs/experiment.json")

# Or construct in Python and save
config.to_file("configs/experiment.json")
```

### 5. ExperimentConfig: only when necessary

If your experiment just needs standard evolution (population, operators, fitness function), use `UnifiedConfig` directly — no wrapper class needed.

Only create an `ExperimentConfig` composite class when you have **experiment-specific parameters** that don't belong in `UnifiedConfig` (e.g., model config, dataset config, prompt template config for LLM experiments).

```python
# SIMPLE EXPERIMENT — just use UnifiedConfig directly
config = UnifiedConfig.from_file("configs/sphere.json")
engine = create_engine(config, sphere_fn, seed=42)
pop = create_initial_population(config, seed=42)
result = engine.run(pop)

# COMPLEX EXPERIMENT — composite config justified
@dataclass(frozen=True)
class ExperimentConfig:
    unified: UnifiedConfig
    model: ModelConfig        # experiment-specific
    dataset: DatasetConfig    # experiment-specific
```

### 6. macOS x86_64 dependency pins

On macOS Intel, these upper bounds are required in `pyproject.toml`:

```toml
"torch<2.3",         # torch >=2.3 dropped x86_64 macOS wheels
"numpy<2",           # torch 2.2 incompatible with numpy 2
"transformers<4.46", # transformers >=4.46 requires torch >=2.3
```

On Apple Silicon or Linux these pins can be relaxed. Check `uname -m` — `x86_64` needs the pins, `arm64` does not.

### 7. Git dependency requires hatch metadata flag

```toml
[tool.hatch.metadata]
allow-direct-references = true
```

Without this, `uv sync` rejects `evolve-framework @ git+https://...` with a cryptic error.

### 8. MLflow tracking URI — absolute paths for the UI

`sqlite:///mlflow.db` (3 slashes = relative) works for experiment scripts but **fails silently** for `mlflow ui`:

```bash
# Experiment configs: relative is fine (resolves from cwd)
"tracking_uri": "sqlite:///mlflow.db"

# MLflow UI: must be absolute (4 slashes before the path)
mlflow ui --backend-store-uri sqlite:////absolute/path/to/mlflow.db --port 5000
```

## Workflow

### Step 1: Scaffold project

Use the `research-project-init` skill with these extra dependencies:

```
torch<2.3, transformers<4.46, numpy<2, datasets, accelerate,
evolve-framework @ git+https://github.com/lucasflores/evolve-framework.git
```

After scaffolding, add to `pyproject.toml`:

```toml
[tool.hatch.metadata]
allow-direct-references = true
```

Run `uv sync` and verify: `uv run python -c "from evolve.config import UnifiedConfig; print('OK')"`.

### Step 2: Create JSON config(s)

Write JSON configs that map **directly** to `UnifiedConfig` fields — no renaming, no intermediate parsing.

See [references/config-reference.md](references/config-reference.md) for the complete field reference with types and defaults.

**Minimal config (sphere optimization):**

```json
{
  "name": "sphere_optimization",
  "seed": 42,
  "population_size": 100,
  "max_generations": 200,
  "elitism": 2,
  "selection": "tournament",
  "selection_params": {"tournament_size": 5},
  "crossover": "sbx",
  "crossover_rate": 0.9,
  "crossover_params": {"eta": 20.0},
  "mutation": "gaussian",
  "mutation_rate": 0.2,
  "mutation_params": {"sigma": 1.0},
  "genome_type": "vector",
  "genome_params": {"dimensions": 50, "bounds": [-10.0, 10.0]},
  "minimize": true
}
```

**With tracking:**

```json
{
  "name": "tracked_experiment",
  "population_size": 200,
  "max_generations": 500,
  "elitism": 5,
  "selection": "tournament",
  "selection_params": {"tournament_size": 5},
  "crossover": "sbx",
  "crossover_rate": 0.9,
  "crossover_params": {"eta": 20.0},
  "mutation": "gaussian",
  "mutation_rate": 0.1,
  "mutation_params": {"sigma": 0.5},
  "genome_type": "vector",
  "genome_params": {"dimensions": 100, "bounds": [-5.0, 5.0]},
  "minimize": true,
  "seed": 42,
  "tracking": {
    "enabled": true,
    "backend": "mlflow",
    "experiment_name": "my-experiment",
    "tracking_uri": "sqlite:///mlflow.db"
  }
}
```

**With ERP (evolvable reproductive protocols):**

```json
{
  "name": "erp_experiment",
  "population_size": 500,
  "max_generations": 100,
  "elitism": 5,
  "selection": "tournament",
  "selection_params": {"tournament_size": 5},
  "crossover": "sbx",
  "crossover_rate": 0.9,
  "crossover_params": {"eta": 15.0},
  "mutation": "gaussian",
  "mutation_rate": 0.1,
  "mutation_params": {"sigma": 0.5},
  "genome_type": "vector",
  "genome_params": {"dimensions": 30, "bounds": [-5.0, 5.0]},
  "minimize": true,
  "seed": 42,
  "erp": {
    "step_limit": 1000,
    "recovery_threshold": 0.1,
    "protocol_mutation_rate": 0.1,
    "enable_intent": true,
    "enable_recovery": true
  }
}
```

**With meta-evolution:**

```json
{
  "name": "meta_experiment",
  "population_size": 50,
  "max_generations": 10,
  "elitism": 2,
  "selection": "tournament",
  "selection_params": {"tournament_size": 3},
  "crossover": "uniform",
  "crossover_rate": 0.9,
  "mutation": "gaussian",
  "mutation_rate": 0.1,
  "mutation_params": {"sigma": 0.5},
  "genome_type": "vector",
  "genome_params": {"dimensions": 10, "bounds": [-5.0, 5.0]},
  "minimize": true,
  "seed": 42,
  "meta": {
    "evolvable_params": [
      {"path": "mutation_rate", "bounds": [0.01, 0.3]},
      {"path": "mutation_params.sigma", "bounds": [0.1, 2.0]}
    ],
    "outer_population_size": 10,
    "outer_generations": 5,
    "trials_per_config": 2,
    "aggregation": "mean"
  }
}
```

If your experiment needs extra parameters beyond `UnifiedConfig`, see [references/config-pattern.md](references/config-pattern.md) for the composite config pattern.

### Step 3: Create tracking callback (if needed)

Only create a custom callback if you need to log **experiment-specific** params. The framework's `TrackingCallback` (built automatically by `create_engine()`) handles the full MLflow lifecycle and standard evolution metrics.

```python
import mlflow

class ExperimentParamsCallback:
    def __init__(self, params: dict):
        self._params = params

    def on_run_start(self, config):
        mlflow.log_params({k: str(v) for k, v in self._params.items()})

    # Only implement the methods you need — engine checks with hasattr
```

### Step 4: Write experiment script

```python
import numpy as np
from evolve.config import UnifiedConfig
from evolve.factory.engine import create_engine, create_initial_population

def sphere(genes):
    return float(np.sum(genes**2))

config = UnifiedConfig.from_file("configs/experiment.json")
engine = create_engine(config, sphere, seed=config.seed)
pop = create_initial_population(config, seed=config.seed)
result = engine.run(pop)

print(f"Best fitness: {result.best.fitness.values[0]:.6f}")
print(f"Generations: {result.generations}")
print(f"Stop reason: {result.stop_reason}")
```

### Step 5: Create two configs

1. **Quick-dev** — small model, pop=20, 10 generations. Must finish in seconds on CPU.
2. **Production** — real hyperparameters, full evaluation set.

Always test with quick-dev first.

### Step 6: Dry-run before long experiments

Use `dry_run()` to estimate wall-clock time before committing to expensive runs:

```python
from evolve.experiment.dry_run import dry_run
from evolve.evaluation.evaluator import FunctionEvaluator

config = UnifiedConfig.from_file("configs/production.json")
report = dry_run(config, evaluator=FunctionEvaluator(sphere), seed=42)
print(report.summary())
# Shows per-phase time breakdown, total estimate, memory, and bottleneck analysis
```

Dry-run accuracy: typically <10% error for runs >10s. Short runs (<1s) may have higher variance.

### Step 7: Verify tracking end-to-end

After the quick-dev run, verify MLflow captured data:

```python
import sqlite3
conn = sqlite3.connect("mlflow.db")
c = conn.cursor()
c.execute("SELECT experiment_id, name FROM experiments")
c.execute("SELECT run_uuid, status FROM runs WHERE experiment_id=?", (exp_id,))
c.execute("SELECT key, value FROM latest_metrics WHERE run_uuid=?", (run_id,))
```

Expect: FINISHED run with both framework params and experiment-specific params, plus per-generation metrics.

### Step 8: Launch MLflow UI

```bash
mlflow ui --backend-store-uri sqlite:////absolute/path/to/project/mlflow.db --port 5000
```

## Framework API Quick Reference

See [references/framework-api.md](references/framework-api.md) for full details.

### UnifiedConfig fields

All fields with types and defaults — these are the **exact JSON keys**:

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `schema_version` | `str` | `"1.0"` | Auto-set |
| `name` | `str` | `""` | Experiment identifier |
| `description` | `str` | `""` | Documentation |
| `tags` | `tuple[str,...]` | `()` | JSON: use list `["a","b"]` |
| `seed` | `int\|None` | `None` | `None` = random |
| `population_size` | `int` | `100` | Must be > 0 |
| `max_generations` | `int` | `100` | Must be > 0 |
| `elitism` | `int` | `1` | In `[0, population_size]` |
| `selection` | `str` | `"tournament"` | See operator table |
| `selection_params` | `dict` | `{}` | See operator table |
| `crossover` | `str` | `"uniform"` | See operator table |
| `crossover_rate` | `float` | `0.9` | In `[0, 1]` |
| `crossover_params` | `dict` | `{}` | See operator table |
| `mutation` | `str` | `"gaussian"` | See operator table |
| `mutation_rate` | `float` | `1.0` | In `[0, 1]` |
| `mutation_params` | `dict` | `{}` | See operator table |
| `genome_type` | `str` | `"vector"` | `"vector"`, `"sequence"`, `"graph"`, `"embedding"` |
| `genome_params` | `dict` | `{}` | For vector: `{"dimensions": N, "bounds": [lo, hi]}` |
| `minimize` | `bool` | `True` | `true` = lower is better |
| `evaluator` | `str\|None` | `None` | Registry name (or pass callable to `create_engine`) |
| `evaluator_params` | `dict` | `{}` | Params for registry evaluator |
| `decoder` | `str\|None` | `None` | Decoder registry name |
| `decoder_params` | `dict` | `{}` | Params for decoder |
| `custom_callbacks` | `tuple[dict,...]` | `()` | `[{"name": "...", "params": {...}}]` |
| `stopping` | `StoppingConfig\|None` | `None` | See nested configs |
| `callbacks` | `CallbackConfig\|None` | `None` | Logging/checkpointing |
| `erp` | `ERPSettings\|None` | `None` | Enables ERPEngine |
| `multiobjective` | `MultiObjectiveConfig\|None` | `None` | Enables NSGA-II |
| `meta` | `MetaEvolutionConfig\|None` | `None` | Enables outer loop |
| `tracking` | `TrackingConfig\|None` | `None` | MLflow/wandb tracking |
| `merge` | `MergeConfig\|None` | `None` | Symbiogenetic merge |
| `training_data` | `DatasetConfig\|None` | `None` | MLflow dataset logging |
| `validation_data` | `DatasetConfig\|None` | `None` | MLflow dataset logging |

Properties: `is_erp_enabled`, `is_multiobjective`, `is_meta_evolution`, `is_tracking_enabled`, `is_merge_enabled`.

### Available operators and their params

**Selection** (work with any genome type):

| Name | Params | Notes |
|------|--------|-------|
| `tournament` | `{"tournament_size": int}` | Default: 3 |
| `roulette` | `{}` | Fitness-proportionate |
| `rank` | `{}` | Rank-based |
| `crowded_tournament` | `{"tournament_size": int}` | For multi-objective |

**Crossover**:

| Name | Params | Genomes | Notes |
|------|--------|---------|-------|
| `uniform` | `{}` | vector, sequence | Gene-level coin flip |
| `single_point` | `{}` | vector, sequence | Single crossover point |
| `two_point` | `{}` | vector, sequence | Two crossover points |
| `blend` | `{"alpha": float}` | vector | BLX-α, default α=0.5 |
| `sbx` | `{"eta": float}` | vector | Simulated Binary, η=20.0 typical |
| `neat` | `{}` | graph | NEAT-style |
| `token_single_point` | `{}` | embedding | Token-level |
| `token_two_point` | `{}` | embedding | Token-level |

**Mutation**:

| Name | Params | Genomes | Notes |
|------|--------|---------|-------|
| `gaussian` | `{"sigma": float}` | vector | σ controls step size |
| `uniform` | `{}` | vector | Uniform random |
| `polynomial` | `{"eta": float}` | vector | Polynomial mutation |
| `creep` | `{}` | vector | Small perturbations |
| `neat` | `{}` | graph | NEAT-style |
| `token_gaussian` | `{}` | embedding | Token-aware |

### Nested config quick reference

**ERPSettings** (enables ERPEngine):
```json
{"step_limit": 1000, "recovery_threshold": 0.1, "protocol_mutation_rate": 0.1, "enable_intent": true, "enable_recovery": true}
```

**MetaEvolutionConfig** (enables outer loop):
```json
{
  "evolvable_params": [
    {"path": "mutation_rate", "bounds": [0.01, 0.3]},
    {"path": "crossover_rate", "param_type": "continuous", "bounds": [0.5, 1.0]}
  ],
  "outer_population_size": 20, "outer_generations": 10, "trials_per_config": 1, "aggregation": "mean"
}
```

**TrackingConfig** (enables MLflow/wandb):
```json
{"enabled": true, "backend": "mlflow", "experiment_name": "my-exp", "tracking_uri": "sqlite:///mlflow.db"}
```

**StoppingConfig** (additional stopping criteria):
```json
{"fitness_threshold": 0.001, "stagnation_generations": 50, "time_limit_seconds": 3600.0}
```

**MergeConfig** (symbiogenetic merge):
```json
{"operator": "graph_symbiogenetic", "merge_rate": 0.1}
```

**MultiObjectiveConfig** (NSGA-II):
```json
{
  "objectives": [{"name": "accuracy", "direction": "maximize"}, {"name": "complexity", "direction": "minimize"}],
  "reference_point": [1.0, 100.0]
}
```

### Key API signatures

```python
# Engine creation — evaluator can be callable or Evaluator instance
engine = create_engine(config, evaluator=sphere_fn, seed=42, callbacks=[my_cb])

# Population creation
pop = create_initial_population(config, seed=42)

# Run evolution — callbacks auto-merged (no need to pass engine._callbacks)
result = engine.run(pop)

# Result access
result.best.fitness.values[0]  # primary fitness value (float)
result.population              # final Population
result.history                 # list[dict] — per-generation metrics
result.generations             # int
result.stop_reason             # str

# Meta-evolution
from evolve.meta.evaluator import run_meta_evolution
result = run_meta_evolution(config, fitness_fn, seed=42)

# Dry-run cost estimation
from evolve.experiment.dry_run import dry_run
report = dry_run(config, evaluator=FunctionEvaluator(sphere), seed=42)
print(report.summary())
```
