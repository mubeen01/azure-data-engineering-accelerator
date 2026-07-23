"""CLI entry point: python -m generator.cli --domain banking --rows 1000

`banking`, `healthcare`, and `retail` are implemented (Milestone 3.1 and
3.2). Adding a new domain means writing a
`generate(rows, seed) -> dict[str, DataFrame]` function in
generator/domains/<name>.py and registering it in DOMAIN_GENERATORS below —
`insurance` is the one domain still open, same pattern.
"""

import argparse
from pathlib import Path

from generator.domains import banking, healthcare, retail

DOMAIN_GENERATORS = {
    "banking": banking.generate,
    "healthcare": healthcare.generate,
    "retail": retail.generate,
}

REPO_ROOT = Path(__file__).resolve().parents[3]


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate synthetic ADEA sample data.")
    parser.add_argument("--domain", required=True, choices=sorted(DOMAIN_GENERATORS))
    parser.add_argument(
        "--rows", type=int, default=1000, help="Base row count (e.g. customer count for banking)."
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=None,
        help="Defaults to datasets/<domain>/ at the repo root.",
    )
    parser.add_argument("--seed", type=int, default=None, help="Optional seed for reproducible output.")
    args = parser.parse_args()

    output_dir = args.output_dir or (REPO_ROOT / "datasets" / args.domain)
    output_dir.mkdir(parents=True, exist_ok=True)

    tables = DOMAIN_GENERATORS[args.domain](args.rows, args.seed)
    for table_name, df in tables.items():
        out_path = output_dir / f"{table_name}.csv"
        df.to_csv(out_path, index=False)
        print(f"Wrote {len(df):,} rows to {out_path}")


if __name__ == "__main__":
    main()
