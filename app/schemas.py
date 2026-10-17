from pydantic import BaseModel, ConfigDict, Field


class RoomCreate(BaseModel):
    """Lo que el cliente manda en POST /rooms. Pydantic lo valida antes de entrar."""

    nombre: str
    edificio: str
    capacidad: int = Field(gt=0)
    equipamiento: list[str] = []


class Room(RoomCreate):
    """Lo que la API devuelve: lo mismo que RoomCreate más el id."""

    model_config = ConfigDict(from_attributes=True)

    id: int
