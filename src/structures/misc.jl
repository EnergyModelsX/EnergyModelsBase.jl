


nt = Union{Nothing, TS.TimePeriod, TS.TimeStructure{T}} where {T}
struct PrevPeriods{S<:nt, T<:nt, U<:nt}
    sp::S
    rp::T
    op::U
    last::nt
end
