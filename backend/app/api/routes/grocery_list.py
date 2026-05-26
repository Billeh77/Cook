from fastapi import APIRouter

router = APIRouter()


@router.get("")
async def get_grocery_list():
    # TODO: implement with database
    return {"items": []}


@router.post("/generate", status_code=201)
async def generate_grocery_list(request: dict):
    # TODO: implement — takes recipe_ids, diffs against inventory
    return {"items": []}


@router.patch("/items/{item_id}/check")
async def check_grocery_item(item_id: str, update: dict):
    # TODO: implement — marks checked, updates inventory
    return {"id": item_id, "checked": update.get("checked", False)}
