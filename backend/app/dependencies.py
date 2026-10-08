from dataclasses import dataclass

from fastapi import Depends, Header, HTTPException
from sqlalchemy.orm import Session

from .db import get_db
from .models import Role, User


@dataclass(frozen=True)
class Actor:
    id: str
    role: Role


def get_actor(
    x_user_id: str | None = Header(default=None),
    x_user_role: Role = Header(default=Role.PATIENT),
) -> Actor:
    if not x_user_id:
        raise HTTPException(status_code=401, detail="X-User-Id is required")
    return Actor(id=x_user_id, role=x_user_role)


def require_roles(*roles: Role):
    def dependency(actor: Actor = Depends(get_actor)) -> Actor:
        if actor.role not in roles:
            raise HTTPException(status_code=403, detail="Insufficient permissions")
        return actor

    return dependency


def require_user(actor: Actor, user_id: str) -> None:
    if actor.id != user_id and actor.role not in {Role.DOCTOR, Role.HOSPITAL_ADMIN}:
        raise HTTPException(status_code=403, detail="Access denied")


def get_existing_user(db: Session, user_id: str) -> User:
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    return user
