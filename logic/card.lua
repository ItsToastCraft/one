local card = {}
local cardSets = require("networking.cardSets")
local allCards = {}

local defaultBackground = textures["background"]
---@enum Color
local colors = {
    red = 0xd4362b,
    yellow = 0xf7cf33,
    blue = 0x57c436, 
    green = 0x00d4ff 
}
local colorKeys = {"red", "yellow", "blue", "green", red = 1, yellow = 2, blue = 3, green = 4}

---comment
---@param number? number
---@param color? Color | number
function card:generate(number, color)
    
    self = {}
    local set = cardSets.getCurrentSet()
    self.number = number or math.random(0,9)
    local colNum = math.random(4)

    self.color = type(color) == "string" and colorKeys[color] or type(color) == "number" and color or colNum
    
    
    color = set and set.colors and set.colors[color] or colors[color] --, set.background or defaultBackground
    --local newCard = models.card:copy("Card" .. #allCards + 1)
    --newCard.primary:setColor(self.color)
    --newCard.background:setPrimaryTexture("CUSTOM")
    --self.card = newCard
    allCards[#allCards+1] = self
    return self
end

return card