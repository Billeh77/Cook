from fastapi import APIRouter

router = APIRouter()


@router.get("")
async def list_inventory():
    # TODO: implement with database
    return {"items": [], "total": 0}


@router.post("", status_code=201)
async def add_inventory_item(item: dict):
    # TODO: implement with database
    return item


@router.patch("/{item_id}")
async def update_inventory_item(item_id: str, update: dict):
    # TODO: implement with database
    return {"id": item_id, **update}


@router.delete("/{item_id}", status_code=204)
async def delete_inventory_item(item_id: str):
    # TODO: implement with database
    pass
