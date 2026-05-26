from fastapi import APIRouter

router = APIRouter()


@router.get("")
async def list_recipes():
    # TODO: implement with database
    return {"recipes": [], "total": 0}


@router.get("/{recipe_id}")
async def get_recipe(recipe_id: str):
    # TODO: implement with database
    return {"id": recipe_id}


@router.delete("/{recipe_id}", status_code=204)
async def delete_recipe(recipe_id: str):
    # TODO: implement with database
    pass
