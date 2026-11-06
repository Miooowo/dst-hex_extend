local M = {}

M.ID = "borrowed_time"
M.CHARACTER = "wanda"
M.AGE_COST = 4
M.SLOW_TIME_ID = "official_wanda_gold"
M.MIN_YEARS = 20
M.MAX_YEARS = 80
M.MIN_HEALTH = 1

local function Finite(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

function M.YearSpan()
    local min_years = M.MIN_YEARS
    local max_years = M.MAX_YEARS
    if TUNING ~= nil and Finite(TUNING.WANDA_MIN_YEARS_OLD) then
        min_years = TUNING.WANDA_MIN_YEARS_OLD
    end
    if TUNING ~= nil and Finite(TUNING.WANDA_MAX_YEARS_OLD) then
        max_years = TUNING.WANDA_MAX_YEARS_OLD
    end
    if max_years <= min_years then
        return M.MAX_YEARS - M.MIN_YEARS
    end
    return max_years - min_years
end

function M.Required(amount, mod, round_up)
    if not Finite(amount) then
        return 0
    end
    if not Finite(mod) or mod <= 0 then
        mod = 1
    end
    local scaled = amount * mod
    local rounded = scaled
    if type(round_up) == "function" then
        local ok, value = pcall(round_up, scaled)
        if ok and Finite(value) then
            rounded = value
        end
    end
    if rounded < 1 then
        rounded = 1
    end
    return rounded
end

function M.MissingUnits(rows)
    local total = 0
    for _, row in ipairs(rows or {}) do
        local need = row.need or 0
        local have = row.have or 0
        if need > have then
            total = total + (need - have)
        end
    end
    return total
end

function M.HealthLoss(maxhealth, units)
    if not Finite(maxhealth) or maxhealth <= 0 or not Finite(units) or units <= 0 then
        return 0
    end
    return units * M.AGE_COST * maxhealth / M.YearSpan()
end

function M.PayUnits(slow_time)
    if slow_time then
        return 0.5
    end
    return 1
end

function M.AgeCost(missing, slow_time)
    if not Finite(missing) or missing <= 0 then
        return 0
    end
    return missing * M.AGE_COST * M.PayUnits(slow_time)
end

function M.ShownHealthAmount(age, scale)
    if not Finite(age) or age <= 0 then
        return 0
    end
    if not Finite(scale) or scale <= 0 then
        scale = 60 / 150
    end
    -- Health costs passed to Ingredient() must be multiples of 5.
    local seg = 5
    local function displayed(amount)
        return math.ceil(amount * scale)
    end
    local amount = math.ceil((age / scale) / seg) * seg
    if amount < seg then
        amount = seg
    end
    local guard = 0
    while displayed(amount) < age and guard < 40 do
        amount = amount + seg
        guard = guard + 1
    end
    guard = 0
    while amount > seg and displayed(amount - seg) >= age and guard < 40 do
        amount = amount - seg
        guard = guard + 1
    end
    return amount
end

function M.SubstitutionPlan(rows, current, maxhealth, slow_time, scale)
    local missing = M.MissingUnits(rows)
    if missing <= 0 then
        return nil
    end
    local units = missing * M.PayUnits(slow_time)
    local ok, loss = M.CanPay(current, maxhealth, units)
    local totals = {}
    local order = {}
    for _, row in ipairs(rows or {}) do
        local use = math.min(row.have or 0, row.need or 0)
        if type(row.type) == "string" and use > 0 then
            if totals[row.type] == nil then
                totals[row.type] = 0
                order[#order + 1] = row.type
            end
            totals[row.type] = totals[row.type] + use
        end
    end
    local kept = {}
    for _, prefab in ipairs(order) do
        kept[#kept + 1] = { type = prefab, amount = totals[prefab] }
    end
    local age = M.AgeCost(missing, slow_time)
    return {
        missing = missing,
        age = age,
        units = units,
        loss = loss,
        enough = ok,
        kept = kept,
        health_amount = M.ShownHealthAmount(age, scale),
    }
end

function M.CanPay(current, maxhealth, units)
    local loss = M.HealthLoss(maxhealth, units)
    if not Finite(units) or units <= 0 then
        return false, 0
    end
    if not Finite(current) or not Finite(loss) or current - loss < M.MIN_HEALTH then
        return false, loss
    end
    return true, loss
end

return M
