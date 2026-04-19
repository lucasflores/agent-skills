# evolve-framework API Reference

Quick reference for the key classes and functions. Always import from the framework — never reimplement.

## evolve.config.UnifiedConfig

Frozen dataclass. All evolution parameters for a single experiment. Native JSON serialization — **no YAML needed**.

### Construction

```python
from evolve.config import UnifiedConfig

# From JSON file (preferred for experiments)
uc = UnifiedConfig.from_file("configs/experiment.json")

# From dict (e.g., from JSON loaded elsewhere)
uc = UnifiedConfig.from_dict(data)

# From JSON string
uc = UnifiedConfig.from_json(json_string)

# Direct construction
uc = UnifiedConfig(
    name="experiment-name",
    description="...",
    tags=("tag1", "tag2"),          # tuple, not list
    seed=42,
    population_size=100,
    max_generations=200,
    elitism=2,
    selection="tournament",
    selection_params={"tournament_size": 5},
    crossover="sbx",
    crossover_rate=0.9,
    crossover_params={"eta": 20.0},
    mutation="gaussian",
    mutation_rate=0.2,
    mutation_params={"sigma": 1.0},
    genome_type="vector",
    genome_params={"dimensions": 50, "bounds": (-10.0, 10.0)},
    minimize=True,
    tracking=TrackingConfig(
        enabled=True,
        backend="mlflow",
        experiment_name="my-experiment",
        tracking_uri="sqlite:///mlflow.db",
    ),
    # Optional nested configs (None = disabled):
    # stopping, callbacks, erp, multiobjective, meta, merge,
    # training_data, validation_data
    # Declarative evaluator (alternative to passing callable):
    # evaluator="benchmark", evaluator_params={"function_name": "sphere"}
    # decoder, decoder_params, custom_callbacks
)
```

### All fields (exact JSON keys)

| Field | Type | Default |
|-------|------|---------|
| `schema_version` | `str` | `"1.0"` |
| `name` | `str` | `""` |
| `description` | `str` | `""` |
| `tags` | `tuple[str,...]` | `()` |
| `seed` | `int\|None` | `None` |
| `population_size` | `int` | `100` |
| `max_generations` | `int` | `100` |
| `elitism` | `int` | `1` |
| `selection` | `str` | `"tournament"` |
| `selection_params` | `dict` | `{}` |
| `crossover` | `str` | `"uniform"` |
| `crossover_rate` | `float` | `0.9` |
| `crossover_params` | `dict` | `{}` |
| `mutation` | `str` | `"gaussian"` |
| `mutation_rate` | `float` | `1.0` |
| `mutation_params` | `dict` | `{}` |
| `genome_type` | `str` | `"vector"` |
| `genome_params` | `dict` | `{}` |
| `minimize` | `bool` | `True` |
| `evaluator` | `str\|None` | `None` |
| `evaluator_params` | `dict` | `{}` |
| `decoder` | `str\|None` | `None` |
| `decoder_params` | `dict` | `{}` |
| `custom_callbacks` | `tuple[dict,...]` | `()` |
| `stopping` | `StoppingConfig\|None` | `None` |
| `callbacks` | `CallbackConfig\|None` | `None` |
| `erp` | `ERPSettings\|None` | `None` |
| `multiobjective` | `MultiObjectiveConfig\|None` | `None` |
| `meta` | `MetaEvolutionConfig\|None` | `None` |
| `tracking` | `TrackingConfig\|None` | `None` |
| `merge` | `MergeConfig\|None` | `None` |
| `training_data` | `DatasetConfig\|None` | `None` |
| `validation_data` | `DatasetConfig\|None` | `None` |

Properties: `is_erp_enabled`, `is_multiobjective`, `is_meta_evolution`, `is_tracking_enabled`, `is_merge_enabled`.

Serialization: `to_dict()`, `to_json()`, `to_file(path)`, `compute_hash()`.

### Validation rules

- `population_size > 0`, `max_generations > 0`
- `0 <= elitism <= population_size`
- `0.0 <= crossover_rate <= 1.0`, `0.0 <= mutation_rate <= 1.0`
- `selection`, `crossover`, `mutation`, `genome_type` must be non-empty strings

## Nested Config Classes

### TrackingConfig

```python
from evolve.config import TrackingConfig

tc = TrackingConfig(
    enabled=True,                    # default: True
    backend="mlflow",                # "mlflow", "wandb", "local", "null"
    experiment_name="my-experiment", # default: "evolve"
    run_name=None,                   # auto-generated if None
    tracking_uri=None,               # e.g. "sqlite:///mlflow.db"
    # Advanced (rarely needed):
    # categories, log_interval, buffer_size, flush_interval,
    # timing_breakdown, diversity_sample_size, system_metrics, log_datasets
)
```

### ERPSettings

```python
from evolve.config.erp import ERPSettings

erp = ERPSettings(
    step_limit=1000,             # default: 1000
    recovery_threshold=0.1,      # default: 0.1
    protocol_mutation_rate=0.1,  # default: 0.1
    enable_intent=True,          # default: True
    enable_recovery=True,        # default: True
)
```

### MetaEvolutionConfig

```python
from evolve.config.meta import MetaEvolutionConfig, ParameterSpec

meta = MetaEvolutionConfig(
    evolvable_params=(
        ParameterSpec(path="mutation_rate", bounds=(0.01, 0.3)),
        ParameterSpec(path="mutation_params.sigma", bounds=(0.1, 2.0)),
        ParameterSpec(path="crossover_rate", bounds=(0.5, 1.0)),
    ),
    outer_population_size=20,  # default: 20
    outer_generations=10,      # default: 10
    trials_per_config=1,       # default: 1
    aggregation="mean",        # "mean", "median", "best"
    inner_generations=None,    # override config.max_generations for inner loop
)
```

### StoppingConfig

```python
from evolve.config.stopping import StoppingConfig

stopping = StoppingConfig(
    fitness_threshold=0.001,       # stop when fitness reaches this
    stagnation_generations=50,     # stop after N gens without improvement
    time_limit_seconds=3600.0,     # wall-clock timeout
)
```

### MergeConfig

```python
from evolve.config.merge import MergeConfig

merge = MergeConfig(
    operator="graph_symbiogenetic",
    merge_rate=0.1,  # 0.0 = disabled
)
```

### MultiObjectiveConfig

```python
from evolve.config.multiobjective import MultiObjectiveConfig, ObjectiveSpec

multi = MultiObjectiveConfig(
    objectives=(
        ObjectiveSpec(name="accuracy", direction="maximize"),
        ObjectiveSpec(name="complexity", direction="minimize"),
    ),
    reference_point=(1.0, 100.0),
)
```

## Available Operators and Parameters

### Selection (work with any genome type)

| Name | Params | Notes |
|------|--------|-------|
| `tournament` | `{"tournament_size": int}` | Default size: 3 |
| `roulette` | `{}` | Fitness-proportionate |
| `rank` | `{}` | Rank-based |
| `crowded_tournament` | `{"tournament_size": int}` | For multi-objective (NSGA-II) |

### Crossover

| Name | Params | Compatible genomes |
|------|--------|--------------------|
| `uniform` | `{}` | vector, sequence |
| `single_point` | `{}` | vector, sequence |
| `two_point` | `{}` | vector, sequence |
| `blend` | `{"alpha": float}` | vector only |
| `sbx` | `{"eta": float}` | vector only |
| `neat` | `{}` | graph only |
| `token_single_point` | `{}` | embedding only |
| `token_two_point` | `{}` | embedding only |

**Typical values**: `blend` α=0.5, `sbx` η=20.0 (higher η = closer to parents).

### Mutation

| Name | Params | Compatible genomes |
|------|--------|--------------------|
| `gaussian` | `{"sigma": float}` | vector only |
| `uniform` | `{}` | vector only |
| `polynomial` | `{"eta": float}` | vector only |
| `creep` | `{}` | vector only |
| `neat` | `{}` | graph only |
| `token_gaussian` | `{}` | embedding only |

## evolve.factory.engine.create_engine()

```python
from evolve.factory.engine import create_engine

engine = create_engine(
    config=uc,                      # UnifiedConfig
    evaluator=fitness_fn,           # callable(genome) -> float, or Evaluator instance
    seed=None,                      # override config.seed
    callbacks=[my_callback],        # additional callbacks (merged with framework's)
)
```

What it does internally:
1. Wraps callable evaluators in `FunctionEvaluator` automatically
2. Resolves selection/crossover/mutation operators from registries
3. Builds stopping criteria from config
4. Builds callbacks including `TrackingCallback` when tracking is enabled
5. Stores callbacks in `engine._creation_callbacks`
6. Returns `EvolutionEngine` (or `ERPEngine` when `erp` config is set)

## evolve.factory.engine.create_initial_population()

```python
from evolve.factory.engine import create_initial_population

pop = create_initial_population(
    config=uc,                      # UnifiedConfig
    seed=None,                      # override config.seed
)
```

Uses `config.genome_type` + `config.genome_params` to create a `Population` of the correct size.

For `genome_type="vector"`, `genome_params` must have `dimensions` (int) and `bounds` (tuple/list of two floats).

## evolve.core.engine.EvolutionEngine.run()

```python
# Callbacks are auto-merged — creation-time + run-time callbacks
result = engine.run(pop)

# Or pass additional run-time callbacks
result = engine.run(pop, callbacks=[extra_callback])
```

Returns `EvolutionResult`.

Callback lifecycle during `run()`:
1. `on_run_start(config)` — once at start
2. Loop: `on_generation_start(gen, pop)` → evolve → `on_generation_end(gen, pop, metrics)`
3. `on_run_end(population, stop_reason)` — once at end

## EvolutionResult

```python
result.best            # Individual — best individual found
result.best.fitness    # Fitness object
result.best.fitness.values[0]  # float — primary fitness value
result.population      # final Population
result.history         # list[dict] — per-generation metrics
result.generations     # int — number of generations completed
result.stop_reason     # str — why evolution stopped
```

## Fitness

```python
from evolve.core.types import Fitness

# Single-objective (preferred)
f = Fitness.scalar(0.5)
f.values[0]  # 0.5

# Multi-objective
f = Fitness(values=np.array([0.5, 0.3]))

# WRONG — do NOT use keyword `value`
f = Fitness(value=1.0)  # TypeError!
```

## Meta-evolution

```python
from evolve.meta.evaluator import run_meta_evolution

# Runs outer loop evolving config params, inner loop evaluating fitness
result = run_meta_evolution(config, fitness_fn, seed=42)
```

## Dry-run cost estimation

```python
from evolve.experiment.dry_run import dry_run
from evolve.evaluation.evaluator import FunctionEvaluator

report = dry_run(config, evaluator=FunctionEvaluator(sphere), seed=42)
print(report.summary())
# Shows per-phase timing breakdown, total estimate, memory, bottleneck
```

## Callback Protocol

Any object with these methods (all optional, checked via `hasattr`):

```python
class MyCallback:
    def on_run_start(self, config) -> None: ...
    def on_generation_start(self, generation: int, population) -> None: ...
    def on_generation_end(self, generation: int, population, metrics: dict) -> None: ...
    def on_run_end(self, population, reason: str) -> None: ...
```

The framework's `TrackingCallback` (built automatically by `create_engine`) handles:
- MLflow run start/end lifecycle
- Logging all `UnifiedConfig` params
- Logging per-generation metrics: best_fitness, mean_fitness, std_fitness, generation timing, evaluation timing

Custom callbacks only need to add experiment-specific data.
