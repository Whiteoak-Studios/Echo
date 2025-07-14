return function (sound: Sound, state: boolean?)
    if
        state == nil
        or typeof(state) ~= "boolean"
    then
        return warn(`Failed to run action {script.Name}, please check to make {
            "sure that the state is a boolean value only."
        }`)
    end

    if state then
        sound:Play()
    else
        sound:Stop()
    end
end