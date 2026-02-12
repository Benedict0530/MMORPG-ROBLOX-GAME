local Shops = {}

Shops["Grimleaf Entrance"] = {
    Items = {
        "Twig",
        "Wooden Sword",
        "Plastic Sword",
        "Stone Sword",
        "Iron Sword",
        -- Brown Armor
        "Brown Armor Helmet",
        "Brown Armor Suit",
        "Brown Armor Legs",
        "Brown Armor Shoes",
        -- Stone Armor
        "Stone Armor Helmet",
        "Stone Armor Suit",
        "Stone Armor Legs",
        "Stone Armor Shoes",
        -- Iron Armor
        "Iron Armor Helmet",
        "Iron Armor Suit",
        "Iron Armor Legs",
        "Iron Armor Shoes"
    }
}

Shops["Grimleaf 1"] = {
    Items = {
        "Twig",
        "Wooden Sword",
        "Plastic Sword",
        "Stone Sword",
        "Iron Sword",
        -- Brown Armor
        "Brown Armor Helmet",
        "Brown Armor Suit",
        "Brown Armor Legs",
        "Brown Armor Shoes",
        -- Stone Armor
        "Stone Armor Helmet",
        "Stone Armor Suit",
        "Stone Armor Legs",
        "Stone Armor Shoes",
        -- Iron Armor
        "Iron Armor Helmet",
        "Iron Armor Suit",
        "Iron Armor Legs",
        "Iron Armor Shoes"
    }
}

-- Utility: Get items for a map
function Shops.GetItemsForMap(mapName)
    local mapShop = Shops[mapName]
    return mapShop and mapShop.Items or {}
end

return Shops
