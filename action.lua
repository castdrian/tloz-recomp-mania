local Action = {}

function Action.new(kind, combo, hitAudio, maxFrame, hitFrame)
  return {
    kind = kind,
    combo = combo,
    frame = 1,
    timer = 0,
    hit = false,
    hitAudio = hitAudio,
    maxFrame = maxFrame or 2,
    hitFrame = hitFrame or 2,
    chargeEligible = kind == "sword",
  }
end

function Action.trackButton(action, bHeld)
  if action.kind == "sword" and not bHeld then
    action.chargeEligible = false
  end
end

function Action.canCharge(action, bHeld)
  return action.kind == "sword" and bHeld and action.chargeEligible
end

return Action
