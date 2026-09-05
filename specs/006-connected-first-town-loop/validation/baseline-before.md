# Pre-change Baseline Provenance

No immutable pre-tuning roadless/connected 48-hour trace was captured before
milestone 006 implementation began. Reconstructing one from the current
working tree would mislabel post-change behavior as a baseline, so T001,
CHK016, and CHK023 intentionally remain open.

The post-change canonical roadless/connected/bridge evidence is preserved in
`last-run.json`; the 168-hour matched-layout results are in
`matrix-report.json`; and all repeated hashes are in
`determinism-report.json`. These artifacts must not be represented as the
missing pre-change baseline.
