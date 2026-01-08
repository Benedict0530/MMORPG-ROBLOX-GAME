local Shops = {}

Shops["Grimleaf Entrance"] = {
    Items = {
        "Wooden Sword",
        "Twig"
    }
}

Shops["Grimleaf 1"] = {
    Items = {
        "Twig",
        "Wooden Sword",
        "Plastic Sword",
        "Iron Sword"
    }
}

-- Utility: Get items for a map
function Shops.GetItemsForMap(mapName)
    local mapShop = Shops[mapName]
    return mapShop and mapShop.Items or {}
end

return Shops
