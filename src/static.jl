#TODO: Document interface to support static size
# Define maybestaticsize, maybestaticlength, and maybestaticfirstindex



@eval struct Static{N} <: Number
    (f::Type{<:Static})() = $(Expr(:new,:f))
end
Base.@pure Static(N) = Static{N}()
@inline Static(::Val{N}) where {N} = Static{N}()
@inline Base.Val(::Static{N}) where {N} = Val{N}()
@generated function static_sizeof(::Type{T}) where {T}
    Expr(:block, Expr(:meta, :inline), Expr(:call, Expr(:curly, :Static, sizeof(T))))
end

Base.CartesianIndex(I::Tuple{<:Static,Vararg}) = CartesianVIndex(I)
Base.CartesianIndex(I::Tuple{<:Integer,<:Static,Vararg}) = CartesianVIndex(I)
Base.CartesianIndex(I::Tuple{<:Integer,<:Integer,<:Static,Vararg}) = CartesianVIndex(I)
Base.CartesianIndex(I::Tuple{<:Integer,<:Integer,<:Integer,<:Static,Vararg}) = CartesianVIndex(I)
Base.CartesianIndex(I::Tuple{<:Integer,<:Integer,<:Integer,<:Integer,<:Static,Vararg}) = CartesianVIndex(I)

abstract type AbstractStaticUnitRange <: AbstractUnitRange{Int} end
# rank 2, but 3 unknowns; 5 types can express all different posibilities
# 1: all unknown, UnitRange; 2: all three known (only two must be made explicit):
struct StaticUnitRange{L,U} <: AbstractStaticUnitRange end
Base.@pure StaticUnitRange(L,U) = StaticUnitRange{L,U}() # Do I use this definition anywhere?
# Then each specifying one of the three parameters
struct StaticLowerUnitRange{L} <: AbstractStaticUnitRange
    U::Int
end
struct StaticUpperUnitRange{U} <: AbstractStaticUnitRange
    L::Int
end
struct StaticLengthUnitRange{N} <: AbstractStaticUnitRange
    L::Int
end



@inline Base.first(::StaticUnitRange{L}) where {L} = L
@inline Base.first(::StaticLowerUnitRange{L}) where {L} = L
@inline Base.first(r::StaticUpperUnitRange) = r.L
@inline Base.first(r::StaticLengthUnitRange) = r.L
@inline Base.last(::StaticUnitRange{L,U}) where {L,U} = U
@inline Base.last(r::StaticLowerUnitRange) = r.U
@inline Base.last(::StaticUpperUnitRange{U}) where {U} = U
@inline Base.last(r::StaticLengthUnitRange{N}) where {N} = vadd(r.L, N - 1)

Base.show(io::IO, r::AbstractStaticUnitRange) = print(io, "$(first(r)):$(last(r))")

@inline Base.iterate(x::AbstractStaticUnitRange) = (i = unwrap(first(x)); (i,i))

@inline Base.:(:)(::Static{L}, ::Static{U}) where {L,U} = StaticUnitRange{L,U}()
@inline Base.:(:)(::Static{L}, U::Int) where {L} = StaticLowerUnitRange{L}(U)
@inline Base.:(:)(L::Int, ::Static{U}) where {U} = StaticUpperUnitRange{U}(L)
@inline unwrap(x) = x
@inline unwrap(::Val{N}) where {N} = N
@inline unwrap(::Type{Val{N}}) where {N} = N
@inline unwrap(::Static{N}) where {N} = N
@inline unwrap(::Type{Static{N}}) where {N} = N

@inline StaticLowerUnitRange{L}(::Static{U}) where {L,U} = StaticUnitRange{L,U}()
@inline StaticUpperUnitRange{U}(::Static{L}) where {L,U} = StaticUnitRange{L,U}()
@generated StaticLengthUnitRange{N}(::Static{L}) where {L,N} = StaticUnitRange{L,L+N-1}()

@inline maybestaticsize(A, ::Val{I}) where {I} = size(A, I)
@inline maybestaticsize(A::AbstractArray{<:Any,0}, ::Val{1:2}) = (1, 1)
@inline maybestaticsize(A::AbstractVector, ::Val{1:2}) = (length(A), 1)
@inline maybestaticsize(A::AbstractMatrix, ::Val{1:2}) = size(A)
@inline maybestaticsize(A::AbstractArray, ::Val{1:2}) = (size(A,1),size(A,2))
# Former is not type stable
# @inline maybestaticsize(A::AbstractArray{<:Any,N}) where {N} = ntuple(n -> maybestaticsize(A, Val{n}()), Val{N}())
@generated function maybestaticsize(A::AbstractArray{<:Any,N}) where {N}
    out = Expr(:tuple)
    foreach(n -> push!(out.args, :(maybestaticsize(A, Val{$n}()))), 1:N)
    out
end
@inline maybestaticlength(A) = length(A)

@inline maybestaticfirstindex(A::AbstractArray, ::Val{I}) where {I} = firstindex(A, I)
@inline maybestaticfirstindex(A::Array, ::Val{I}) where {I} = Static{1}()
                  

# @inline maybestaticeachindex(A::AbstractArray) = maybestaticrange(eachindex(A))

@inline maybestaticrange(r::Base.OneTo) = StaticLowerUnitRange{1}(last(r))
@inline maybestaticrange(r::UnitRange) = r
@inline maybestaticrange(r::AbstractStaticUnitRange) = r
@inline maybestaticrange(r) = maybestaticfirst(r):maybestaticlast(r)
# @inline maybestaticaxis(A::AbstractArray, ::Val{I}) where {I} = maybestaticfirstindex(A, Val{I}()):maybestaticsize(A, Val{I}())

@inline maybestaticsize(::NTuple{N}, ::Val{1}) where {N} = Static{N}() # should we assert that i == 1?
@inline maybestaticlength(::NTuple{N}) where {N} = Static{N}()
@inline maybestaticsize(::Adjoint{T,V}, ::Val{1}) where {T,V<:AbstractVector{T}} = Static{1}()
@inline maybestaticsize(::Transpose{T,V}, ::Val{1}) where {T,V<:AbstractVector{T}} = Static{1}()
@inline maybestaticlength(B::Adjoint) = maybestaticlength(parent(B))
@inline maybestaticlength(B::Transpose) = maybestaticlength(parent(B))
@inline maybestaticsize(B::Adjoint{T,A}, ::Val{1}) where {T,A<:AbstractMatrix{T}} = maybestaticsize(parent(B), Val{2}())
@inline maybestaticsize(B::Adjoint{T,A}, ::Val{2}) where {T,A<:AbstractMatrix{T}} = maybestaticsize(parent(B), Val{1}())
@inline maybestaticsize(B::Transpose{T,A}, ::Val{1}) where {T,A<:AbstractMatrix{T}} = maybestaticsize(parent(B), Val{2}())
@inline maybestaticsize(B::Transpose{T,A}, ::Val{2}) where {T,A<:AbstractMatrix{T}} = maybestaticsize(parent(B), Val{1}())

@inline Base.iszero(::Static{0}) = true
@inline Base.iszero(::Static) = false
@generated function Base.divrem(N::Integer, ::Static{L}) where {L}
    if ispow2(L)
        quote
            $(Expr(:meta,:inline))
            d = N >>> $(intlog2(L))
            r = N & $(L-1)
            d, r
        end
    else
        quote
            $(Expr(:meta,:inline))
            divrem(N, $L)
        end
    end
end
@generated Base.divrem(::Static{N}, ::Static{D}) where {N,D} = divrem(N, D)

for f ∈ [:(Base.:(&)), :(Base.:(>)), :(Base.:(<)), :(Base.:(≥)), :(Base.:(≤)), :(Base.div), :(Base.cld), :vadd, :vsub, :vmul]
    @eval @inline $f(::Static{M}, n::Number) where {M} = $f(M, n)
    @eval @inline $f(m::Number, ::Static{N}) where {N} = $f(m, N)
    @eval @inline $f(::Static{M}, ::Static{N}) where {M, N} = Static{$f(M, N)}()
end
for f ∈ [:(Base.:(>>)), :(Base.:(>>>))]
    @eval @inline $f(::Static{M}, n::Number) where {M} = shr(M, n)
    @eval @inline $f(m::Number, ::Static{N}) where {N} = shr(m, N)
    @eval @inline $f(::Static{M}, ::Static{N}) where {M, N} = Static{$f(M, N)}()
end

@inline vadd(::Static{N}, ::Static{0}) where {N} = Static{N}()
@inline vadd(::Static{0}, ::Static{N}) where {N} = Static{N}()
@inline vmul(::Static{N}, ::Static{0}) where {N} = Static{0}()
@inline vmul(::Static{0}, ::Static{N}) where {N} = Static{0}()
@inline vmul(::Static{N}, ::Static{1}) where {N} = Static{N}()
@inline vmul(::Static{1}, ::Static{N}) where {N} = Static{N}()
@inline vmul(::Static{N}, i) where {N} = vmul(N, i)
@inline vmul(i, ::Static{N}) where {N} = vmul(i, N)
@inline Base.:+(::Static{N}, i) where {N} = vadd(N, i)
@inline Base.:+(::Static{N}, i::Number) where {N} = vadd(N, i)
@inline Base.:+(i, ::Static{N}) where {N} = vadd(N, i)
@inline Base.:+(i::Number, ::Static{N}) where {N} = vadd(N, i)
@inline Base.:+(::Static{M}, ::Static{N}) where {M,N} = vadd(M, N)
@inline Base.:*(::Static{N}, i) where {N} = vmul(N, i)
@inline Base.:*(::Static{N}, i::Number) where {N} = vmul(N, i)
@inline Base.:*(i, ::Static{N}) where {N} = vmul(N, i)
@inline Base.:*(i::Number, ::Static{N}) where {N} = vmul(N, i)
@inline Base.:*(::Static{M}, ::Static{N}) where {M,N} = vmul(M, N)
@inline Base.:-(::Static{N}, i) where {N} = vsub(N, i)
@inline Base.:-(::Static{N}, i::Number) where {N} = vsub(N, i)
@inline Base.:-(i, ::Static{N}) where {N} = vsub(i, N)
@inline Base.:-(i::Number, ::Static{N}) where {N} = vsub(i, N)
@inline Base.:-(::Static{M}, ::Static{N}) where {M,N} = vsub(M, N)
@inline Base.checked_add(::Static{N}, i) where {N} = Base.checked_add(N, i)
@inline Base.checked_add(i, ::Static{N}) where {N} = Base.checked_add(i, N)
@generated Base.checked_add(::Static{M}, ::Static{N}) where {M,N} = Static{Base.checked_add(M, N)}()
@inline Base.checked_sub(::Static{N}, i) where {N} = Base.checked_sub(N, i)
@inline Base.checked_sub(i, ::Static{N}) where {N} = Base.checked_sub(i, N)
@generated Base.checked_sub(::Static{M}, ::Static{N}) where {M,N} = Static{Base.checked_sub(M, N)}()
@inline Base.:<<(::Static{N}, i) where {N} = shl(N, i)
@inline Base.:<<(i, ::Static{N}) where {N} = shl(i, N)
@inline Base.:<<(::Static{M}, ::Static{N}) where {M,N} = shl(M, N)
@inline Base.:(%)(::Static{M}, ::Type{I}) where {M,I<:Integer} = M % I

@inline Base.:(==)(::Static{M}, i) where {M} = M == i
@inline Base.:(==)(i, ::Static{M}) where {M} = M == i
@inline Base.:(==)(::Static{M}, ::Static{N}) where {M,N} = false
@inline Base.:(==)(::Static{M}, ::Static{M}) where {M} = true

@inline vadd(::Tuple{}, ::Tuple{}) = tuple()
@inline vadd(a::Tuple{I1,Vararg}, b::Tuple{}) where {I1} = a
@inline vadd(a::Tuple{}, b::Tuple{I2,Vararg}) where {I2} = b
@inline vadd(a::Tuple{I1}, b::Tuple{I2}) where {I1,I2} = (vadd(a[1],b[1]),)
@inline vadd(a::Tuple{I1,I3}, b::Tuple{I2,I4}) where {I1,I2,I3,I4} = (vadd(a[1],b[1]),vadd(a[2],b[2]),)
@inline vadd(a::Tuple{I1,Vararg}, b::Tuple{I2,Vararg}) where {I1,I2} = (vadd(a[1],b[1]),vadd(Base.tail(a),Base.tail(b))...)

function static_promote(i, j)
    i == j || throw("$i ≠ $j")
    i
end
function static_promote(::Static{M}, i) where {M}
    M == i || throw("$M ≠ $i")
    Static{M}()
end
function static_promote(i, ::Static{M}) where {M}
    M == i || throw("$M ≠ $i")
    Static{M}()
end
static_promote(::Static{M}, ::Static{N}) where {M, N} = throw("$M ≠ $N")
static_promote(::Static{M}, ::Static{M}) where {M} = Static{M}()

@generated staticp1(::Static{N}) where {N} = Static{N+1}()
@inline staticp1(N) = vadd(N, one(N))
@inline staticp1(i::Tuple{}) = tuple()
@inline staticp1(i::Tuple{I}) where {I} = @inbounds (staticp1(i[1]),)
@inline staticp1(i::Tuple{I1,I2}) where {I1,I2} = @inbounds (staticp1(i[1]), staticp1(i[2]))
@inline staticp1(i::Tuple{I1,I2,I3,Vararg}) where {I1,I2,I3} = @inbounds (staticp1(i[1]), staticp1(Base.tail(i))...)
@generated staticm1(::Static{N}) where {N} = Static{N-1}()
@inline staticm1(N) = vsub(N, one(N))
@inline staticm1(i::Tuple{}) = tuple()
@inline staticm1(i::Tuple{I}) where {I} = @inbounds (staticm1(i[1]),)
@inline staticm1(i::Tuple{I1,I2}) where {I1,I2} = @inbounds (staticm1(i[1]), staticm1(i[2]))
@inline staticm1(i::Tuple{I1,I2,I3,Vararg}) where {I1,I2,I3} = @inbounds (staticm1(i[1]), staticm1(Base.tail(i))...)
@generated staticmul(::Type{T}, ::Static{N}) where {T,N} = sizeof(T) * N
@generated staticmul(::Type{T}, ::Val{N}) where {T,N} = sizeof(T) * N
@inline staticmul(::Type{T}, N) where {T} = vmul(N, sizeof(T))
@inline staticmul(::Type{T}, i::Tuple{}) where {T} = tuple()
@inline staticmul(::Type{T}, i::Tuple{I}) where {T,I} = @inbounds (vmul(i[1], sizeof(T)),)
@inline staticmul(::Type{T}, i::Tuple{I1,I2}) where {T,I1,I2} = @inbounds (vmul(sizeof(T), i[1]), vmul(sizeof(T), i[2]))
@inline staticmul(::Type{T}, i::Tuple{I1,I2,I3,Vararg}) where {T,I1,I2,I3} = @inbounds (vmul(sizeof(T), i[1]), staticmul(T, Base.tail(i))...)
@inline Base.ntuple(f::F, ::Static{N}) where {F,N} = ntuple(f, Val{N}())


@inline maybestaticfirst(A) = first(A)
@inline maybestaticfirst(::StaticUnitRange{L}) where {L} = Static{L}()
@inline maybestaticfirst(::StaticLowerUnitRange{L}) where {L} = Static{L}()
@inline maybestaticfirst(::Base.OneTo) = Static{1}()

@inline _maybestaticfirst(A::Tuple{}) = tuple()
@inline _maybestaticfirst(A::Tuple{I}) where {I} = (maybestaticfirst(@inbounds(A[1])),)
@inline _maybestaticfirst(A::Tuple{I1,I2}) where {I1,I2} = @inbounds (maybestaticfirst(A[1]), maybestaticfirst(A[2]))
@inline _maybestaticfirst(A::Tuple{I1,I2,I3,Vararg}) where {I1,I2,I3} = (maybestaticfirst(@inbounds A[1]), _maybestaticfirst(Base.tail(A))...)
@inline maybestaticfirst(A::CartesianIndices) = CartesianVIndex(_maybestaticfirst(A.indices))


@inline maybestaticlast(A) = last(A)
@inline maybestaticlast(::StaticUnitRange{L,U}) where {L,U} = Static{U}()
@inline maybestaticlast(::StaticUpperUnitRange{U}) where {U} = Static{U}()
@inline _maybestaticlast(A::Tuple{}) = tuple()
@inline _maybestaticlast(A::Tuple{I}) where {I} = (maybestaticlast(@inbounds(A[1])),)
@inline _maybestaticlast(A::Tuple{I1,I2}) where {I1,I2} = @inbounds (maybestaticlast(A[1]), maybestaticlast(A[2]))
@inline _maybestaticlast(A::Tuple{I1,I2,I3,Vararg}) where {I1,I2,I3} = (maybestaticlast(@inbounds A[1]), _maybestaticlast(Base.tail(A))...)
@inline maybestaticlast(A::CartesianIndices) = CartesianVIndex(_maybestaticlast(A.indices))


# Static 0
const Zero = Static{0}
@inline vsub(::Zero, i) = vsub(i)
@inline vsub(i, ::Zero) = i
@inline vsub(::Zero, i::Number) = vsub(i)
@inline vsub(i::Number, ::Zero) = i
@inline vsub(::Zero, ::Zero) = Zero()
@inline vadd(::Zero, ::Zero) = Zero()
@inline vadd(::Zero, a) = a
@inline vadd(a, ::Zero) = a
@inline vadd(::Zero, a::Number) = a
@inline vadd(a::Number, ::Zero) = a
@inline vmul(::Zero, ::Any) = Zero()
@inline vmul(::Any, ::Zero) = Zero()
@inline vmul(::Zero, ::Number) = Zero()
@inline vmul(::Number, ::Zero) = Zero()
@inline vmul(::Zero, i::SVec{<:Any,<:Integer}) = Zero()
@inline vmul(i::SVec{<:Any,<:Integer}, ::Zero) = Zero()
for T ∈ [:Int,:SVec]
    @eval @inline vadd(::Zero, a::$T) = a
    @eval @inline vadd(a::$T, ::Zero) = a
    @eval @inline vsub(::Zero, a::$T) = vsub(a)
    @eval @inline vsub(a::$T, ::Zero) = a
    @eval @inline vmul(::Zero, ::$T) = Zero()
    @eval @inline vmul(::$T, ::Zero) = Zero()
end
@inline vadd(::Zero, a::_MM) = a
@inline vadd(a::_MM, ::Zero) = a
@inline vload(ptr::Ptr, ::Zero) = vload(ptr)
@inline vload(ptr::Ptr, ::_MM{W,Zero}) where {W} = vload(Val{W}(), ptr)
@inline vload(ptr::Ptr, ::_MM{W,Zero}, m::Mask) where {W} = vload(Val{W}(), ptr, m.u)
@inline vstore!(ptr::Ptr{T}, v::T, ::Zero) where {T} = vstore!(ptr, v)
@inline vnoaliasstore!(ptr::Ptr{T}, v::T, ::Zero) where {T} = vnoaliasstore!(ptr, v)
@inline vstore!(ptr::Ptr{T}, v, ::Zero) where {T} = vstore!(ptr, convert(T,v))
@inline vnoaliasstore!(ptr::Ptr{T}, v, ::Zero) where {T} = vnoaliasstore!(ptr, convert(T,v))
@inline vstore!(ptr::Ptr{T}, v::Integer, ::Zero) where {T <: Integer} = vstore!(ptr, v % T)
@inline vnoaliasstore!(ptr::Ptr{T}, v::Integer, ::Zero) where {T <: Integer} = vnoaliasstore!(ptr, v % T)
# @inline vstore!(ptr::Ptr{T}, v::T, ::Zero, m::Mask) where {T} = vstore!(ptr, v, m.u)
# @inline vnoaliasstore!(ptr::Ptr{T}, v::T, ::Zero, m::Mask) where {T} = vnoaliasstore!(ptr, v, m.u)
for V ∈ [:(NTuple{W,Core.VecElement{T}}), :(SVec{W,T})]
    @eval @inline vstore!(ptr::Ptr{T}, v::$V, ::Zero) where {W,T} = vstore!(ptr, v)
    @eval @inline vstore!(ptr::Ptr{T}, v::$V, ::_MM{W,Zero}) where {W,T} = vstore!(ptr, v)
    @eval @inline vnoaliasstore!(ptr::Ptr{T}, v::$V, ::Zero) where {W,T} = vnoaliasstore!(ptr, v)
    @eval @inline vnoaliasstore!(ptr::Ptr{T}, v::$V, ::_MM{W,Zero}) where {W,T} = vnoaliasstore!(ptr, v)
    for M ∈ [:(Mask{W}), :Unsigned]
        @eval @inline vstore!(ptr::Ptr{T}, v::$V, ::Zero, m::$M) where {W,T} = vstore!(ptr, v, m)
        @eval @inline vstore!(ptr::Ptr{T}, v::$V, ::_MM{W,Zero}, m::$M) where {W,T} = vstore!(ptr, v, m)
        @eval @inline vnoaliasstore!(ptr::Ptr{T}, v::$V, ::Zero, m::$M) where {W,T} = vnoaliasstore!(ptr, v, m)
        @eval @inline vnoaliasstore!(ptr::Ptr{T}, v::$V, ::_MM{W,Zero}, m::$M) where {W,T} = vnoaliasstore!(ptr, v, m)
    end
end

const One = Static{1}
@inline vmul(::One, a) = a
@inline vmul(a, ::One) = a
@inline vmul(::One, a::Number) = a
@inline vmul(a::Number, ::One) = a
@inline vmul(::One, ::One) = One()
@inline vmul(::One, ::Zero) = Zero()
@inline vmul(::Zero, ::One) = Zero()
@inline vmul(::One, i::SVec{<:Any,<:Integer}) = i
@inline vmul(i::SVec{<:Any,<:Integer}, ::One) = i

for T ∈ [:Int,:SVec]
    @eval @inline vmul(::One, a::$T) = a
    @eval @inline vmul(a::$T, ::One) = a
end

abstract type AbstractLazyMul end
struct LazyStaticMul{N,T} <: AbstractLazyMul
    data::T
end
struct LazyStaticMulAdd{N,M,T} <: AbstractLazyMul
    data::T
end
@inline LazyStaticMul{N}(data::T) where {N,T} = LazyStaticMul{N,T}(data)
@inline LazyStaticMulAdd{N,M}(data::T) where {N,M,T} = LazyStaticMulAdd{N,M,T}(data)
# @inline vmul(::Static{N}, i::I) where {N,I<:Union{Integer,_MM}} = LazyStaticMul{N,I}(i)
# @inline vmul(i::I, ::Static{N}) where {N,I<:Union{Integer,_MM}} = LazyStaticMul{N,I}(i)
@inline vmul(::Static{N}, i::I) where {N,I<:Integer} = LazyStaticMul{N,I}(i)
@inline vmul(i::I, ::Static{N}) where {N,I<:Integer} = LazyStaticMul{N,I}(i)
@inline vmul(::Static{N}, i::_Vec{_W,I}) where {N,_W,I<:Integer} = LazyStaticMul{N,_Vec{_W,I}}(i)
@inline vmul(i::_Vec{_W,I}, ::Static{N}) where {N,_W,I<:Integer} = LazyStaticMul{N,_Vec{_W,I}}(i)
@inline vmul(::Static{N}, i::SVec{W,I}) where {N,W,I<:Integer} = LazyStaticMul{N,Vec{W,I}}(extract_data(i))
@inline vmul(i::SVec{W,I}, ::Static{N}) where {N,W,I<:Integer} = LazyStaticMul{N,Vec{W,I}}(extract_data(i))
@inline extract_data(a::LazyStaticMul{N,I}) where {N,I<:Integer} = vmul(N, a.data)
@inline extract_data(a::LazyStaticMulAdd{N,M,I}) where {N,M,I<:Integer} = vadd(vmul(N, a.data), M)
@inline extract_data(a::LazyStaticMul{N,I}) where {N,W,I<:_MM{W}} = _MM{W}(vmul(N, a.data.i))
@inline extract_data(a::LazyStaticMulAdd{N,M,I}) where {N,M,W,I<:_MM{W}} = _MM{W}(vadd(vmul(N, a.data.i), M))
@inline vadd(a::LazyStaticMul{N}, b) where {N} = vadd(vmul(N, a.data), b)
@inline vadd(b, a::LazyStaticMul{N}) where {N} = vadd(b, vmul(N, a.data))
@inline vadd(a::LazyStaticMul, ::Static{0}) = a
@inline vadd(::Static{0}, a::LazyStaticMul) = a
@inline vadd(a::LazyStaticMul{N}, ::Static{M}) where {M,N} = LazyStaticMulAdd{N,M}(a.data)
@inline vadd(::Static{M}, a::LazyStaticMul{N}) where {M,N} = LazyStaticMulAdd{N,M}(a.data)
@inline vadd(a::LazyStaticMul{N}, b::LazyStaticMul{M}) where {M,N} = vadd(vmul(N, a.data), vmul(M, b.data))
@inline vadd(a::LazyStaticMul{N,T}, b::LazyStaticMul{N,T}) where {N,T} = LazyStaticMul{N}(vadd(a.data, b.data))
@inline vadd(a::LazyStaticMulAdd, ::Static{0}) = a
@inline vadd(::Static{0}, a::LazyStaticMulAdd) = a
@inline vadd(a::LazyStaticMulAdd, ::Static{M}) where {M} = vadd(extract_data(a),M)
@inline vadd(::Static{M}, a::LazyStaticMulAdd) where {M} = vadd(M,extract_data(a))
@inline vadd(a::LazyStaticMulAdd, b) = vadd(extract_data(a),b)
@inline vadd(b, a::LazyStaticMulAdd) = vadd(b,extract_data(a))

@inline vadd(a::LazyStaticMul{N,I}, ::_MM{W,Static{0}}) where {W,N,I<:Integer} = LazyStaticMul{N,_MM{W,I}}(_MM{W}(a.data))
@inline vadd(::_MM{W,Static{0}}, a::LazyStaticMul{N,I}) where {W,N,I<:Integer} = LazyStaticMul{N,_MM{W,I}}(_MM{W}(a.data))

@inline vadd(a::LazyStaticMul{N,I}, ::_MM{W,Static{M}}) where {W,M,N,I<:Integer} = LazyStaticMulAdd{N,M}(_MM{W}(a.data))
@inline vadd(::_MM{W,Static{M}}, a::LazyStaticMul{N,I}) where {W,M,N,I<:Integer} = LazyStaticMulAdd{N,M}(_MM{W}(a.data))

@inline vsub(a::Int, b::AbstractLazyMul) = vsub(a, extract_data(b))
@inline vsub(b::AbstractLazyMul, a::Int) = vsub(extract_data(b), a)
@inline vmul(a::Int, b::AbstractLazyMul) = vmul(a, extract_data(b))
@inline vmul(b::AbstractLazyMul, a::Int) = vmul(extract_data(b), a)

# @inline extract_data(a::LazyStaticMul{N}) where {N} = vmul(a.data, N)
# @inline vload(ptr, lsm::LazyStaticMul{N}) where {N} = vload(gep(ptr, lsm.data, Val{N}()))
# @inline vload(ptr, lsm::LazyStaticMul{N,_MM{W,I}}) where {N,W,I} = vload(Val{W}(), gep(ptr, lsm.data, Val{N}()))
# @inline vload(ptr, lsm::LazyStaticMul{N,SVec{W,I}}) where {N,W,I} = vload(Val{W}(), gep(ptr, lsm.data, Val{N}()))
# @inline vload(ptr::Ptr{T}, lsm::LazyStaticMul{N,_Vec{W,I}}) where {T,N,W,I} = vload(_Vec{W,T}, gep(ptr, lsm.data, Val{N}()))

@inline vload(ptr, lsm::AbstractLazyMul   ) = vload(ptr, extract_data(lsm)   )
@inline vload(ptr, lsm::AbstractLazyMul, m) = vload(ptr, extract_data(lsm), m)
@inline vstore!(ptr, v, lsm::AbstractLazyMul   ) = vstore!(ptr, v, extract_data(lsm)   )
@inline vstore!(ptr, v, lsm::AbstractLazyMul, m) = vstore!(ptr, v, extract_data(lsm), m)
@inline vnoaliasstore!(ptr, v, lsm::AbstractLazyMul   ) = vnoaliasstore!(ptr, v, extract_data(lsm)   )
@inline vnoaliasstore!(ptr, v, lsm::AbstractLazyMul, m) = vnoaliasstore!(ptr, v, extract_data(lsm), m)
for N ∈ [1,2,4,8,6,10]
    @eval @inline vload(ptr, lsm::LazyStaticMul{$N}) = vload(gep(ptr, lsm.data, Val{$N}()))
    @eval @inline vload(ptr, lsm::LazyStaticMul{$N}, m) = vload(gep(ptr, lsm.data, Val{$N}()), m)
    @eval @inline vstore!(ptr, v, lsm::LazyStaticMul{$N}) = vstore!(gep(ptr, lsm.data, Val{$N}()), v)
    @eval @inline vstore!(ptr, v, lsm::LazyStaticMul{$N}, m) = vstore!(gep(ptr, lsm.data, Val{$N}()), v, m)
    @eval @inline vnoaliasstore!(ptr, v, lsm::LazyStaticMul{$N}) = vnoaliasstore!(gep(ptr, lsm.data, Val{$N}()), v)
    @eval @inline vnoaliasstore!(ptr, v, lsm::LazyStaticMul{$N}, m) = vnoaliasstore!(gep(ptr, lsm.data, Val{$N}()), v, m)

    @eval @inline vload(ptr, lsm::LazyStaticMul{$N,_MM{W,I}}) where {W,I}  = vload(Val{W}(), gep(ptr, lsm.data.i, Val{$N}()))
    @eval @inline vload(ptr, lsm::LazyStaticMul{$N,_MM{W,I}}, m) where {W,I} = vload(Val{W}(), gep(ptr, lsm.data.i, Val{$N}()), m)
    @eval @inline vstore!(ptr, v, lsm::LazyStaticMul{$N,_MM{W,I}}) where {W,I} = vstore!(gep(ptr, lsm.data.i, Val{$N}()), v)
    @eval @inline vstore!(ptr, v, lsm::LazyStaticMul{$N,_MM{W,I}}, m) where {W,I} = vstore!(gep(ptr, lsm.data.i, Val{$N}()), v, m)
    @eval @inline vnoaliasstore!(ptr, v, lsm::LazyStaticMul{$N,_MM{W,I}}) where {W,I} = vnoaliasstore!(gep(ptr, lsm.data.i, Val{$N}()), v)
    @eval @inline vnoaliasstore!(ptr, v, lsm::LazyStaticMul{$N,_MM{W,I}}, m) where {W,I} = vnoaliasstore!(gep(ptr, lsm.data.i, Val{$N}()), v, m)


    @eval @inline vload(ptr, lsm::LazyStaticMulAdd{$N,M}) where {M} = vload(gepbyte(gep(ptr, lsm.data, Val{$N}()),M))
    @eval @inline vload(ptr, lsm::LazyStaticMulAdd{$N,M}, m) where {M} = vload(gepbyte(gep(ptr, lsm.data, Val{$N}()),M), m)
    @eval @inline vstore!(ptr, v, lsm::LazyStaticMulAdd{$N,M}) where {M} = vstore!(gepbyte(gep(ptr, lsm.data, Val{$N}()),M), v)
    @eval @inline vstore!(ptr, v, lsm::LazyStaticMulAdd{$N,M}, m) where {M} = vstore!(gepbyte(gep(ptr, lsm.data, Val{$N}()),M), v, m)
    @eval @inline vnoaliasstore!(ptr, v, lsm::LazyStaticMulAdd{$N,M}) where {M} = vnoaliasstore!(gepbyte(gep(ptr, lsm.data, Val{$N}()),M), v)
    @eval @inline vnoaliasstore!(ptr, v, lsm::LazyStaticMulAdd{$N,M}, m) where {M} = vnoaliasstore!(gepbyte(gep(ptr, lsm.data, Val{$N}()),M), v, m)

    @eval @inline vload(ptr, lsm::LazyStaticMulAdd{$N,M,_MM{W,I}}) where {M,W,I}  = vload(Val{W}(), gepbyte(gep(ptr, lsm.data.i, Val{$N}()), M))
    @eval @inline vload(ptr, lsm::LazyStaticMulAdd{$N,M,_MM{W,I}}, m) where {M,W,I} = vload(Val{W}(), gepbyte(gep(ptr, lsm.data.i, Val{$N}()), M), m)
    @eval @inline vstore!(ptr, v, lsm::LazyStaticMulAdd{$N,M,_MM{W,I}}) where {M,W,I} = vstore!(gepbyte(gep(ptr, lsm.data.i, Val{$N}()),M), v)
    @eval @inline vstore!(ptr, v, lsm::LazyStaticMulAdd{$N,M,_MM{W,I}}, m) where {M,W,I} = vstore!(gepbyte(gep(ptr, lsm.data.i, Val{$N}()),M), v, m)
    @eval @inline vnoaliasstore!(ptr, v, lsm::LazyStaticMulAdd{$N,M,_MM{W,I}}) where {M,W,I} = vnoaliasstore!(gepbyte(gep(ptr, lsm.data.i, Val{$N}()),M), v)
    @eval @inline vnoaliasstore!(ptr, v, lsm::LazyStaticMulAdd{$N,M,_MM{W,I}}, m) where {M,W,I} = vnoaliasstore!(gepbyte(gep(ptr, lsm.data.i, Val{$N}()),M), v, m)
end




