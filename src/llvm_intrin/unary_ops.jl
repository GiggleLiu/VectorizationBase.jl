
function sub_quote(W, @nospecialize(T), fast::Bool)
    vtyp = vtype(W, T)
    instrs = "%res = fneg $(fast_flags(fast)) $vtyp %0\nret $vtyp %res"
    quote
        $(Expr(:meta, :inline))
        Vec(llvmcall($instrs, _Vec{$W,$T}, Tuple{_Vec{$W,$T}}, data(v)))
    end
end

@generated vsub(v::Vec{W,T}) where {W, T <: Union{Float32,Float64}} = sub_quote(W, T, false)
@generated vsub_fast(v::Vec{W,T}) where {W, T <: Union{Float32,Float64}} = sub_quote(W, T, true)

@inline vsub(v::Vec{<:Any,<:NativeTypes}) = vsub(zero(v), v)
@inline vsub_fast(v::Vec{<:Any,<:NativeTypes}) = vsub_fast(zero(v), v)
@inline vsub(x::NativeTypes) = Base.FastMath.sub_fast(x)
@inline vsub_fast(x::NativeTypes) = Base.FastMath.sub_fast(x)

@inline vinv(v::AbstractSIMD{W,<:FloatingTypes}) where {W} = vfdiv(one(v), v)
@inline vinv(v::AbstractSIMD{W,<:IntegerTypesHW}) where {W} = inv(float(v))

@inline vabs(v::AbstractSIMD{W,<:Unsigned}) where {W} = v
@inline vabs(v::AbstractSIMD{W,<:Signed}) where {W} = ifelse(v > 0, v, -v)

@inline vround(v::AbstractSIMD{W,<:Integer}) where {W} = v
@inline vround(v::AbstractSIMD{W,<:Integer}, ::RoundingMode) where {W} = v

