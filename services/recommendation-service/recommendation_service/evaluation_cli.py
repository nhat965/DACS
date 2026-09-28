from __future__ import annotations

import argparse
from pathlib import Path

from .catalog import DEFAULT_CATALOG_PATH, CatalogRepository
from .engine import RecommendationEngine
from .evaluation import evaluate_fixture, export_evaluation_report, load_fixture


def main() -> int:
    repo_root = Path(__file__).resolve().parents[3]
    parser = argparse.ArgumentParser(description="Run offline recommendation evaluation")
    parser.add_argument(
        "--fixture",
        type=Path,
        default=repo_root / "services" / "recommendation-service" / "evaluation" / "fixtures" / "offline_expert_fixture.json",
    )
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG_PATH)
    parser.add_argument("--output-dir", type=Path, default=repo_root / "datasets" / "reports")
    args = parser.parse_args()

    catalog = CatalogRepository.from_csv(args.catalog)
    report = evaluate_fixture(RecommendationEngine(catalog), catalog, load_fixture(args.fixture))
    export_evaluation_report(
        report,
        args.output_dir / "recommendation_evaluation_report.json",
        args.output_dir / "recommendation_evaluation_report.csv",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
