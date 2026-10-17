from sqlalchemy import JSON, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class Room(Base):
    """Tabla de aulas en la base de datos."""

    __tablename__ = "rooms"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    nombre: Mapped[str] = mapped_column(String(100))
    edificio: Mapped[str] = mapped_column(String(100))
    capacidad: Mapped[int] = mapped_column(Integer)
    equipamiento: Mapped[list[str]] = mapped_column(JSON)
