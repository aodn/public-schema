# Architecture — water_sampling_db ETL flow

End-to-end pipeline design (not yet implemented past Export/Validate — see
[`water_sampling_db.md`](./water_sampling_db.md) and [`docs/adr/`](./adr/) for the decisions
behind it). Per [ADR-0004](./adr/0004-flow-logic-packaged-in-public-schema.md), this package (`public_schema`) implements
most of the pipeline logic. Orchestration and deployment to AODN's infrastructure
is handled elsewhere, using Prefect to handle scheduling, observability, retries, 
and uploading products to S3.


```mermaid
flowchart TD
    subgraph PublicSchema["public_schema package resources"]
      direction TB
      R[Source data descriptors<br/>+ transform SQL files]
      CFG[Runsheet]
      CFG --> ORDER[Ordered list of<br/>source tables + transforms]
      R --> ORDER
    end

    subgraph SourceLoad["Export/validate source tables"]
        direction LR
        DL[Download CSV via WFS URL] --> VAL[Validate against<br/>Frictionless schema]
        VAL --> DDL[CREATE TABLE<br/>based on source data desriptors + FK .sql files]
        DDL --> LOAD[Load CSV into DuckDB table,<br/>following config order]
        LOAD -->|PK/FK violation| SKIP1[Block dependent transforms]
    end

    subgraph Transform["Transforms"]
        direction TB
        EXEC["Execute one SQL file at a time,<br/>following config order"]
        EXEC -->|success| NEXT[Run dependents]
        EXEC -->|failure| SKIP2[Skip dependents,<br/>continue independent branches]
        CTD[(CTD Parquet<br/>aodn-cloud-optimised via httpfs)] -.-> EXEC
    end

    subgraph Publish["Publish"]
        PROD{"Name ends in _data?"}
        PROD -->|yes: Product| CSVOUT[Export CSV]
        PROD -->|no: Intermediate _map etc.| DROP[Not published]
    end

    ORDER --> SourceLoad
    SourceLoad --> Transform
    Transform --> Publish

    style SKIP1 fill:#f99,color:#000
    style SKIP2 fill:#f99,color:#000
    style DROP fill:#ccc,color:#000
```

## Notes

- Reflects [ADR-0004](./adr/0004-flow-logic-packaged-in-public-schema.md) (pipeline logic lives in
  this package; the other repo holds only a thin wrapper flow),
  [ADR-0005](./adr/0005-execution-order-via-config-file.md) (execution order comes from an
  explicit config file, superseding the dependency-graph approach in
  [ADR-0001](./adr/0001-execution-order-via-unified-dependency-graph.md)),
  [ADR-0002](./adr/0002-pk-fk-constraints-via-create-table-ddl.md) (PK/FK enforced via generated
  `CREATE TABLE` DDL), and [ADR-0003](./adr/0003-ephemeral-duckdb-per-run.md) (DuckDB rebuilt fresh
  every run).
- Domain terms (Resource, Source table, Transform, Product, Intermediate table) are defined in
  [`CONTEXT.md`](../CONTEXT.md).
- `SKIP1`/`SKIP2` (red) both apply the same "block dependents" failure policy, whether the failure
  originates from a Frictionless validation error, a PK/FK constraint violation, or a transform SQL
  error — "dependents" here is read directly from the config order, not derived.
- This package exposes plain Python functions (e.g. `load_source_tables`, `run_transforms`) with no
  Prefect dependency; the wrapper flow imports it as a library and owns all S3/Prefect concerns.
