
function validate(value::AbstractString; rule::Regex=Config.VALIDATION_RULE_GENERAL)
    occursin(rule, value)
end
