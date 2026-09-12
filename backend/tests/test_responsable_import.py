from pathlib import Path

from openpyxl import Workbook
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker

from app.db.base import Base
from app.models.responsable import Responsable
from app.services.responsable_import_service import ResponsableImportService


def test_responsable_import_reads_excel_and_upserts(tmp_path: Path):
    workbook_path = tmp_path / "responsables.xlsx"
    workbook = Workbook()
    sheet = workbook.active
    sheet.title = "Responsables"
    sheet.append(["Nom et Prénom", "Fonction", "Grande résidence"])
    sheet.append(["Nessrine Oggar", "Responsable RH", "CENTRALE DES RESEAUX (23691)"])
    sheet.append(["Nessrine Oggar", "Responsable RH", "DIRECTION CENTRALE DES SERVICES"])
    sheet.append(["", "", ""])
    workbook.save(workbook_path)

    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(bind=engine, tables=[Responsable.__table__])
    db = sessionmaker(bind=engine)()
    try:
        service = ResponsableImportService(db)

        first_summary = service.import_files([workbook_path])
        second_summary = service.import_files([workbook_path])
        rows = db.scalars(select(Responsable).order_by(Responsable.grande_residence)).all()

        assert first_summary.parsed_count == 2
        assert first_summary.inserted_count == 2
        assert second_summary.inserted_count == 0
        assert second_summary.updated_count == 2
        assert len(rows) == 2
        assert rows[0].nom_complet == "Nessrine Oggar"
        assert rows[0].fonction == "Responsable RH"
        assert rows[0].normalized_name == "nessrine oggar"
        assert rows[1].grande_residence == "DIRECTION CENTRALE DES SERVICES"
    finally:
        db.close()
