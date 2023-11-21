local Results = {
    Err = -1,
    Ok = 1
}

local Result = {}
Result.__index = Result

function Result:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Result:unwrap()
    return self.value
end

function Result:unwrap_or(v)
    return self.value or v
end

function Result:unwrap_or_else(f)
    return self.variant == Results.Err and f(self.value) or self.value
end

function Result:unwrap_or_error()
    return self.variant == Results.Ok and self.value or error(self.value)
end

function Ok(value)
    return Result:new{value = value, variant = Results.Ok}    
end

function Err(value) 
    return Result:new{value = value, variant = Results.Err}
end
