from __future__ import annotations

import argparse
import sys
from pathlib import Path


BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

import app.models  # noqa: E402,F401
from app.db.base import Base  # noqa: E402
from app.db.session import SessionLocal, engine  # noqa: E402
from app.services.responsable_import_service import ResponsableImportService  # noqa: E402


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Import Tunisie Telecom responsables from Excel files into the "
            "responsable table."
        )
    )
    parser.add_argument("files", nargs="+", help="Excel .xlsx files to import.")
    args = parser.parse_args()

    paths = [Path(file_path).expanduser().resolve() for file_path in args.files]
    missing = [str(path) for path in paths if not path.exists()]
    if missing:
        print("Missing files:")
        for path in missing:
            print(f"- {path}")
        return 1

    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        summary = ResponsableImportService(db).import_files(paths)
    finally:
        db.close()

    print("Responsable import complete")
    for key, value in summary.to_dict().items():
        print(f"{key}: {value}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
