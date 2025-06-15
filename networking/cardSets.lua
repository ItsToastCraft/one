local cardSet = {}

function cardSet.new(name, author, imageData, cardColors)
    local self = setmetatable({
        name = name,
        author = author,
        imageData = imageData,
        colors = cardColors
    }, cardSet)

    return self
end

function cardSet:save()
    config:setName("uno/sets")
    config:save(self.name, toJson(self))
end

function cardSet.load(name)
    config:setName("uno/sets")
    cardSet.current = config:load(name)
end

function cardSet.getCurrentSet()
    return cardSet.current
end
return cardSet