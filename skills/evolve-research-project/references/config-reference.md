# UnifiedConfig JSON Field Reference

All fields map 1:1 to JSON keys — no renaming needed.

## Minimal JSON config

```json
{
  "name": "my_experiment",
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
  "minimize": true,
  "seed": 42
}
```

## Complete field reference

### Core fields

| JSON Key | Type | Default | Validation |
|----------|------|---------|------------|
| `schema_version` | string | `"1.0"` | Auto-set, rarely needed |
| `name` | string | `""` | Experiment identifier |
| `description` | string | `""` | Documentation |
| `tags` | list of strings | `[]` | Converted to tuple internally |
| `seed` | int or null | `null` | `null` = random seed |
| `population_size` | int | `100` | Must be > 0 |
| `max_generations` | int | `100` | Must be > 0 |
| `elitism` | int | `1` | Must be in [0, population_size] |
| `minimize` | bool | `true` | `true` = lower fitness is better |

### Operator fields

| JSON Key | Type | Default | Notes |
|----------|------|---------|-------|
| `selection` | string | `"tournament"` | `"tournament"`, `"roulette"`, `"rank"`, `"crowded_tournament"` |
| `selection_params` | object | `{}` | e.g. `{"tournament_size": 5}` |
| `crossover` | string | `"uniform"` | `"uniform"`, `"single_point"`, `"two_point"`, `"blend"`, `"sbx"`, `"neat"` |
| `crossover_rate` | float | `0.9` | Must be in [0, 1] |
| `crossover_params` | object | `{}` | e.g. `{"eta": 20.0}` for sbx, `{"alpha": 0.5}` for blend |
| `mutation` | string | `"gaussian"` | `"gaussian"`, `"uniform"`, `"polynomial"`, `"creep"`, `"neat"` |
| `mutation_rate` | float | `1.0` | Must be in [0, 1] |
| `mutation_params` | object | `{}` | e.g. `{"sigma": 1.0}` for gaussian |

### Representation fields

| JSON Key | Type | Default | Notes |
|----------|------|---------|-------|
| `genome_type` | string | `"vector"` | `"vector"`, `"sequence"`, `"graph"`, `"embedding"` |
| `genome_params` | object | `{}` | For vector: `{"dimensions": N, "bounds": [lo, hi]}` |

### Evaluator fields (declarative, alternative to passing callable)

| JSON Key | Type | Default | Notes |
|----------|------|---------|-------|
| `evaluator` | string or null | `null` | Registry name; alternative to passing callable to create_engine |
| `evaluator_params` | object | `{}` | Params passed to evaluator factory |
| `decoder` | string or null | `null` | Decoder registry name |
| `decoder_params` | object | `{}` | Params passed to decoder factory |
| `custom_callbacks` | list of objects | `[]` | `[{"name": "callback_name", "params": {...}}]` |

### Nested config objects (null = disabled)

All nested configs are optional. Omit or set to `null` to disable.

#### `tracking` — MLflow/wandb experiment tracking

```json
{
  "tracking": {
    "enabled": true,
    "backend": "mlflow",
    "experiment_name": "my-experiment",
    "tracking_uri": "sqlite:///mlflow.db",
    "run_name": null,
    "log_interval": 1,
    "timing_breakdown": false,
    "system_metrics": false,
    "log_datasets": false
  }
}
```

#### `stopping` — Additional stopping criteria

`stopping.max_generations` overrides the top-level `max_generations` when the `stopping` block is present. If `null`, the top-level value is used.

```json
{
  "stopping": {
    "max_generations": null,
    "fitness_threshold": 0.001,
    "stagnation_generations": 50,
    "time_limit_seconds": 3600.0
  }
}
```

#### `erp` — Evolvable Reproductive Protocols (enables ERPEngine)

```json
{
  "erp": {
    "step_limit": 1000,
    "recovery_threshold": 0.1,
    "protocol_mutation_rate": 0.1,
    "enable_intent": true,
    "enable_recovery": true
  }
}
```

#### `meta` — Meta-evolution (outer loop optimizing config params)

```json
{
  "meta": {
    "evolvable_params": [
      {"path": "mutation_rate", "bounds": [0.01, 0.3]},
      {"path": "mutation_params.sigma", "bounds": [0.1, 2.0]},
      {"path": "crossover_rate", "param_type": "continuous", "bounds": [0.5, 1.0]}
    ],
    "outer_population_size": 20,
    "outer_generations": 10,
    "trials_per_config": 1,
    "aggregation": "mean",
    "inner_generations": null
  }
}
```

`evolvable_params` ParameterSpec fields:
- `path` (required): Dot-separated path to the UnifiedConfig field
- `param_type`: `"continuous"` (default), `"integer"`, `"categorical"`
- `bounds`: `[lo, hi]` for continuous/integer
- `choices`: list for categorical
- `log_scale`: `false` (default)

#### `multiobjective` — NSGA-II multi-objective optimization

```json
{
  "multiobjective": {
    "objectives": [
      {"name": "accuracy", "direction": "maximize", "weight": 1.0},
      {"name": "complexity", "direction": "minimize", "weight": 1.0}
    ],
    "reference_point": [1.0, 100.0],
    "constraints": [
      {"name": "max_params", "penalty_weight": 1.0}
    ],
    "constraint_handling": "dominance"
  }
}
```

#### `merge` — Symbiogenetic merge phase

```json
{
  "merge": {
    "operator": "graph_symbiogenetic",
    "merge_rate": 0.1
  }
}
```

#### `callbacks` — Built-in logging/checkpointing

```json
{
  "callbacks": {
    "enable_logging": true,
    "log_level": "INFO",
    "log_destination": "console",
    "enable_checkpointing": false,
    "checkpoint_dir": null,
    "checkpoint_frequency": 10
  }
}
```

#### `training_data` / `validation_data` — MLflow dataset logging

```json
{
  "training_data": {
    "name": "sst2-train",
    "path": "/data/sst2/train.csv",
    "context": "training"
  },
  "validation_data": {
    "name": "sst2-val",
    "path": "/data/sst2/val.csv",
    "context": "validation"
  }
}
```
