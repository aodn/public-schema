> **Superseded by [ADR-0005](./0005-execution-order-via-config-file.md).** After external review with
> other data engineers, we reverted to specifying execution order explicitly in a config file rather
> than inferring it from a dependency graph. Kept for historical context — the reasoning below no
> longer reflects the current design.

# Execution order determined by one unified dependency graph, not an external ordering list

`public_schema` bundles source table definitions and ~44 SQL transforms but declares no execution
order — historically this lived in the private `aodn/chef-private` repo, which this flow cannot read.
We considered porting that list into this repo (fragile, needs manual sync whenever `public_schema`
changes) versus inferring order from naming conventions (unreliable). Instead, the flow builds one
dependency graph spanning both source tables (edges from their foreign key references, see ADR-0002)
and transform outputs (edges from each transform's `FROM`/`JOIN` table references), then topologically
sorts the whole graph to decide the full create-load-transform execution order. This keeps the flow
correct automatically as `public_schema` evolves, at the cost of needing a (simple) SQL reference
parser.
