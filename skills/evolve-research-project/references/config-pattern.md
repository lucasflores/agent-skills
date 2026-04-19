# Config Pattern for evolve-framework Projects

## Principle: Use UnifiedConfig directly when possible

If your experiment only needs standard evolution (population, operators, fitness function), use `UnifiedConfig.from_file()` with a JSON config. **No wrapper class needed.**

```python
from evolve.config import UnifiedConfig
from evolve.factory.engine import create_engine, create_initial_population

config = UnifiedConfig.from_file("configs/experiment.json")
engine = create_engine(config, fitness_fn, seed=config.seed)
pop = create_initial_population(config, seed=config.seed)
result = engine.run(pop)
```

JSON field names match UnifiedConfig fields exactly — no renaming, no intermediate parsing.

## When to create an ExperimentConfig wrapper

Only when your experiment has parameters **outside** what UnifiedConfig covers (e.g., model selection, dataset paths, prompt templates for LLM experiments, projection settings).

## Composite Config Pattern (for complex experiments)

```python
"""Experiment configuration.

Composite config that holds:
  - evolve.config.UnifiedConfig  (evolution, tracking, operators)
  - Experiment-specific frozen dataclasses (model, dataset, etc.)
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from evolve.config import UnifiedConfig


# -------------------------------------------------------------------
# Experiment-specific dataclasses (NOT in evolve-framework)
# Only define what the framework doesn't provide.
# -------------------------------------------------------------------

@dataclass(frozen=True)
class ModelConfig:
    name: str = "roberta-large"
    pretrained: str = "roberta-large"
    frozen: bool = True


@dataclass(frozen=True)
class DatasetConfig:
    name: str = "sst2"
    source: str = "glue/sst2"
    n_shot: int = 16
    split_seed: int = 42
    max_test_samples: int | None = None


@dataclass(frozen=True)
class PromptConfig:
    n_tokens: int = 50
    init_strategy: str = "random_uniform"
    embed_dim: int = 1024
    prepend: bool = True


@dataclass(frozen=True)
class ProjectionConfig:
    enabled: bool = True
    intrinsic_dim: int = 500
    method: str = "random_linear"
    projection_seed: int = 0


@dataclass(frozen=True)
class EvaluatorConfig:
    metric: str = "accuracy"
    batch_size: int = 32


# -------------------------------------------------------------------
# Composite config: framework UnifiedConfig + experiment extras
# -------------------------------------------------------------------

@dataclass
class ExperimentConfig:
    unified: UnifiedConfig
    model: ModelConfig = field(default_factory=ModelConfig)
    dataset: DatasetConfig = field(default_factory=DatasetConfig)
    prompt: PromptConfig = field(default_factory=PromptConfig)
    projection: ProjectionConfig = field(default_factory=ProjectionConfig)
    evaluator: EvaluatorConfig = field(default_factory=EvaluatorConfig)

    @classmethod
    def from_json_file(cls, path: Path | str) -> ExperimentConfig:
        path = Path(path)
        with open(path) as f:
            raw: dict[str, Any] = json.load(f)

        # 1. Pop experiment-specific sections FIRST
        model = ModelConfig(**raw.pop("model", {}))
        dataset = DatasetConfig(**raw.pop("dataset", {}))
        prompt = PromptConfig(**raw.pop("prompt", {}))
        projection = ProjectionConfig(**raw.pop("projection", {}))
        evaluator_cfg = EvaluatorConfig(**raw.pop("evaluator", {}))

        # 2. Compute genome dimensions from experiment config
        search_dim = (
            projection.intrinsic_dim
            if projection.enabled
            else (prompt.n_tokens * prompt.embed_dim)
        )
        raw["genome_type"] = "vector"
        raw["genome_params"] = {
            "dimensions": search_dim,
            "bounds": [-1.0, 1.0],
        }
        raw.setdefault("minimize", False)

        # 3. Build UnifiedConfig from remaining fields
        #    UnifiedConfig.from_dict() handles nested configs (tracking,
        #    erp, meta, etc.) and type conversions (tags list → tuple)
        unified = UnifiedConfig.from_dict(raw)

        return cls(
            unified=unified,
            model=model,
            dataset=dataset,
            prompt=prompt,
            projection=projection,
            evaluator=evaluator_cfg,
        )

    @property
    def genome_dim(self) -> int:
        return self.prompt.n_tokens * self.prompt.embed_dim

    @property
    def search_dim(self) -> int:
        if self.projection.enabled:
            return self.projection.intrinsic_dim
        return self.genome_dim

    @property
    def experiment_mlflow_params(self) -> dict[str, Any]:
        """Experiment-specific params for MLflow (framework handles the rest)."""
        return {
            "model": self.model.pretrained,
            "model_frozen": self.model.frozen,
            "dataset": self.dataset.name,
            "dataset_source": self.dataset.source,
            "n_shot": self.dataset.n_shot,
            "n_tokens": self.prompt.n_tokens,
            "embed_dim": self.prompt.embed_dim,
            "init_strategy": self.prompt.init_strategy,
            "projection_enabled": self.projection.enabled,
            "intrinsic_dim": self.projection.intrinsic_dim,
            "projection_method": self.projection.method,
            "genome_dim": self.genome_dim,
            "search_dim": self.search_dim,
        }
```

## JSON Config Structure (composite experiment)

```json
{
  "name": "soft-prompt-evolution",
  "description": "Evolve soft prompts for SST-2 classification",
  "tags": ["sst2", "roberta"],
  "seed": 42,

  "population_size": 20,
  "max_generations": 400,
  "elitism": 2,
  "minimize": false,

  "selection": "tournament",
  "selection_params": {"tournament_size": 3},

  "crossover": "blend",
  "crossover_rate": 0.9,
  "crossover_params": {"alpha": 0.5},

  "mutation": "gaussian",
  "mutation_rate": 0.1,
  "mutation_params": {"sigma": 0.1},

  "tracking": {
    "enabled": true,
    "backend": "mlflow",
    "experiment_name": "soft-prompt-evolution",
    "tracking_uri": "sqlite:///mlflow.db"
  },

  "model": {
    "name": "roberta-large",
    "pretrained": "roberta-large",
    "frozen": true
  },

  "dataset": {
    "name": "sst2",
    "source": "glue/sst2",
    "n_shot": 16,
    "split_seed": 42
  },

  "prompt": {
    "n_tokens": 50,
    "init_strategy": "random_uniform",
    "embed_dim": 1024,
    "prepend": true
  },

  "projection": {
    "enabled": true,
    "intrinsic_dim": 500,
    "method": "random_linear",
    "projection_seed": 0
  },

  "evaluator": {
    "metric": "accuracy",
    "batch_size": 32
  }
}
```

Note: `genome_type` and `genome_params` are omitted from the JSON because `ExperimentConfig.from_json_file()` computes them from `prompt` and `projection` settings. For standard experiments using `UnifiedConfig.from_file()` directly, include them explicitly.
