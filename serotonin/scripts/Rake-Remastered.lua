local function findRake()
    local rakeModel = game.Workspace:FindFirstChild("Rake")
    if rakeModel and rakeModel:IsA("Model") then
        local humanoid = rakeModel:FindFirstChildOfClass("Humanoid")
        if humanoid then
            local rake_data = {
                Character = rakeModel,
                PrimaryPart = rakeModel.PrimaryPart or rakeModel.Head,
                Name = "Rake",
                DisplayName = "Rake",
                Team = "Rake",
                Humanoid = humanoid
            }

            entity.AddModel("rake", rake_data)
        end
    else
        entity.RemoveModel("rake")
    end
end

cheat.Register("onSlowUpdate", findRake)