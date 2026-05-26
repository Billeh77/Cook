import pytest
from app.services.ai.ingredient_normalizer import normalize_ingredients, _dict_lookup


def test_dict_lookup_peanut_butter():
    result = _dict_lookup("2 tbsp crunchy peanut butter (I like @manilife_)")
    assert result is not None
    assert result.canonical_name == "peanut butter"
    assert result.category == "pantry"


def test_dict_lookup_portuguese_potato():
    result = _dict_lookup("1 Batata pequena cozida")
    assert result is not None
    assert result.canonical_name == "potato"


def test_dict_lookup_mozzarella_portuguese():
    result = _dict_lookup("muçarela ralada")
    assert result is not None
    assert result.canonical_name == "mozzarella"
    assert result.category == "dairy"


def test_dict_lookup_olive_oil_portuguese():
    result = _dict_lookup("fio de azeite")
    assert result is not None
    assert result.canonical_name == "olive oil"


def test_dict_lookup_returns_none_for_unknown():
    result = _dict_lookup("some exotic ingredient xyz")
    assert result is None


@pytest.mark.asyncio
async def test_normalize_ingredients_uses_dict_for_known(monkeypatch):
    monkeypatch.setattr("app.services.ai.ingredient_normalizer.settings.anthropic_api_key", "")
    results = await normalize_ingredients(["2 tbsp soy sauce", "minced garlic", "spring onion"])
    names = [r.canonical_name for r in results]
    assert "soy sauce" in names
    assert "garlic" in names
    assert "spring onion" in names
