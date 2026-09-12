from __future__ import annotations

from typing import Any

from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.models.responsable import Responsable


class ResponsableDirectoryService:
    def __init__(self, db: Session) -> None:
        self.db = db

    def list_responsables(
        self,
        *,
        search: str | None = None,
        fonction: str | None = None,
        grande_residence: str | None = None,
        limit: int = 20,
        offset: int = 0,
    ) -> dict[str, Any]:
        filters = []
        search_term = (search or "").strip()
        if search_term:
            pattern = f"%{search_term}%"
            filters.append(
                or_(
                    Responsable.nom_complet.ilike(pattern),
                    Responsable.fonction.ilike(pattern),
                    Responsable.grande_residence.ilike(pattern),
                )
            )
        if fonction:
            filters.append(Responsable.fonction.ilike(f"%{fonction.strip()}%"))
        if grande_residence:
            filters.append(
                Responsable.grande_residence.ilike(f"%{grande_residence.strip()}%")
            )

        total = self.db.scalar(select(func.count()).select_from(Responsable).where(*filters))
        rows = self.db.scalars(
            select(Responsable)
            .where(*filters)
            .order_by(
                Responsable.grande_residence.asc(),
                Responsable.fonction.asc(),
                Responsable.nom_complet.asc(),
            )
            .limit(limit)
            .offset(offset)
        ).all()

        return {
            "total": int(total or 0),
            "count": len(rows),
            "limit": limit,
            "offset": offset,
            "responsables": [_responsable_to_dict(row) for row in rows],
        }

    def list_all_for_planning(self) -> list[dict[str, Any]]:
        rows = self.db.scalars(
            select(Responsable).order_by(
                Responsable.grande_residence.asc(),
                Responsable.fonction.asc(),
                Responsable.nom_complet.asc(),
            )
        ).all()
        return [_responsable_to_dict(row) for row in rows]


def _responsable_to_dict(responsable: Responsable) -> dict[str, Any]:
    return {
        "id": responsable.id,
        "nom_complet": responsable.nom_complet,
        "fonction": responsable.fonction,
        "grande_residence": responsable.grande_residence,
        "source_file": responsable.source_file,
        "source_sheet": responsable.source_sheet,
        "source_row": responsable.source_row,
        "created_at": responsable.created_at.isoformat() if responsable.created_at else "",
        "updated_at": responsable.updated_at.isoformat() if responsable.updated_at else "",
    }
