local protocols = {list = {}}


function protocols.add(name, features)
    protocols.list[name] = features
end

protocols.add("0.1", 
{}
)
return protocols