from __future__ import annotations

from typing import Any

from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.models.responsable import Responsable
from app.services.responsable_import_service import clean_text, normalize_value


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

    def get_responsable(self, responsable_id: str) -> dict[str, Any] | None:
        responsable = self.db.get(Responsable, responsable_id)
        if responsable is None:
            return None
        return _responsable_to_dict(responsable)

    def create_responsable(
        self,
        *,
        nom_complet: str,
        fonction: str,
        grande_residence: str,
    ) -> dict[str, Any]:
        nom_complet = clean_text(nom_complet)
        fonction = clean_text(fonction)
        grande_residence = clean_text(grande_residence)
        normalized_name = normalize_value(nom_complet)
        normalized_fonction = normalize_value(fonction)
        normalized_residence = normalize_value(grande_residence)

        self._ensure_no_duplicate(
            normalized_name=normalized_name,
            normalized_fonction=normalized_fonction,
            normalized_grande_residence=normalized_residence,
        )

        responsable = Responsable(
            nom_complet=nom_complet,
            fonction=fonction,
            grande_residence=grande_residence,
            normalized_name=normalized_name,
            normalized_fonction=normalized_fonction,
            normalized_grande_residence=normalized_residence,
            source_file="manual",
            source_sheet="admin-dashboard",
            source_row=0,
        )
        self.db.add(responsable)
        self.db.commit()
        self.db.refresh(responsable)
        return _responsable_to_dict(responsable)

    def update_responsable(
        self,
        responsable_id: str,
        *,
        nom_complet: str,
        fonction: str,
        grande_residence: str,
    ) -> dict[str, Any] | None:
        responsable = self.db.get(Responsable, responsable_id)
        if responsable is None:
            return None

        nom_complet = clean_text(nom_complet)
        fonction = clean_text(fonction)
        grande_residence = clean_text(grande_residence)
        normalized_name = normalize_value(nom_complet)
        normalized_fonction = normalize_value(fonction)
        normalized_residence = normalize_value(grande_residence)

        self._ensure_no_duplicate(
            normalized_name=normalized_name,
            normalized_fonction=normalized_fonction,
            normalized_grande_residence=normalized_residence,
            exclude_id=responsable_id,
        )

        responsable.nom_complet = nom_complet
        responsable.fonction = fonction
        responsable.grande_residence = grande_residence
        responsable.normalized_name = normalized_name
        responsable.normalized_fonction = normalized_fonction
        responsable.normalized_grande_residence = normalized_residence
        responsable.source_file = responsable.source_file or "manual"
        responsable.source_sheet = responsable.source_sheet or "admin-dashboard"
        self.db.commit()
        self.db.refresh(responsable)
        return _responsable_to_dict(responsable)

    def delete_responsable(self, responsable_id: str) -> bool:
        responsable = self.db.get(Responsable, responsable_id)
        if responsable is None:
            return False
        self.db.delete(responsable)
        self.db.commit()
        return True

    def _ensure_no_duplicate(
        self,
        *,
        normalized_name: str,
        normalized_fonction: str,
        normalized_grande_residence: str,
        exclude_id: str | None = None,
    ) -> None:
        query = select(Responsable).where(
            Responsable.normalized_name == normalized_name,
            Responsable.normalized_fonction == normalized_fonction,
            Responsable.normalized_grande_residence == normalized_grande_residence,
        )
        if exclude_id:
            query = query.where(Responsable.id != exclude_id)
        existing = self.db.scalar(query)
        if existing is not None:
            raise ValueError("A responsable with the same identity already exists.")


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
