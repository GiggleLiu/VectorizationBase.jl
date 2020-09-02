


# let
#     W = 2
#     for T ∈ [Float32, Float64, Int8, Int16, Int32, Int64, UInt8, UInt16, UInt32, UInt64]
#         Wmax = max_vector_width(T)
#         while W ≤ Wmax
            
#             W += W
#         end
#     end
# end
# function broadcast_str(W::Int, typ::String)
#     vtyp = "<$W x $typ>"
#     """
#         %ie = insertelement $vtyp undef, $typ %0, i32 0
#         %v = shufflevector $vtyp %ie, $vtyp undef, <$W x i32> zeroinitializer
#         ret $vtyp %v
#     """
# end
@generated function vzero(::Val{W}, ::Type{T}) where {W,T<:NativeTypes}
    instrs = "ret <$W x $typ> zeroinitializer"
    quote
        $(Expr(:meta,:inline))
        Vec(llvmcall($instrs, _Vec{$W,$T}, Tuple{}))
    end
end
@generated function vbroadcast(::Val{W}, s::T) where {W,T<:NativeTypes}
    typ = LLVM_TYPES[T]
    vtyp = vtype(W, typ)
    instrs = """
        %ie = insertelement $vtyp undef, $typ %0, i32 0
        %v = shufflevector $vtyp %ie, $vtyp undef, <$W x i32> zeroinitializer
        ret $vtyp %v
    """
    quote
        $(Expr(:meta,:pure,:inline))
        Vec(llvmcall($instrs, _Vec{$W,$T}, Tuple{$T}, s))
    end
end

# for T ∈ [Float32,Float64,Int8,Int16,Int32,Int64,UInt8,UInt16,UInt32,UInt64]#, Float16]
#     maxW = pick_vector_width(T)
#     typ = LLVM_TYPES[T]
#     W = 2
#     while W ≤ maxW
#         instrs = "ret <$W x $typ> zeroinitializer"
#         @eval @inline vzero(::Val{$W}, ::Type{$T}) = Vec(llvmcall($instrs, Vec{$W,$T}, Tuple{}, ))
#         instrs = broadcast_str(W, typ)
#         # vtyp = "<$W x $typ>"
#         # instrs = """
#         # %ie = insertelement $vtyp undef, $typ %0, i32 0
#         # %v = shufflevector $vtyp %ie, $vtyp undef, <$W x i32> zeroinitializer
#         # ret $vtyp %v
#         # """
#         @eval Base.@pure @inline vbroadcast(::Val{$W}, s::$T) = Vec(llvmcall($instrs, Vec{$W,$T}, Tuple{$T}, s))
#         W += W
#     end
# end

# @generated function vbroadcast(::Val{W}, s::Ptr{T}) where {W, T}
#     typ = JULIAPOINTERTYPE
#     instrs = broadcast_str(W, typ)
#     quote
#         $(Expr(:meta,:inline))
#         Vec(llvmcall( $instrs, _Vec{$W,Ptr{$T}}, Tuple{Ptr{$T}}, s ))
#     end
# end
# @generated function vbroadcast(::Val{W}, s::T) where {W, T <: NativeTypes}
#     typ = LLVM_TYPES[T]
#     instrs = broadcast_str(W, typ)
#     quote
#         $(Expr(:meta,:inline))
#         Vec(llvmcall( $instrs, _Vec{$W,$T}, Tuple{$T}, s))
#     end
# end
@generated function vbroadcast(::Val{W}, ptr::Ptr{T}) where {W, T}
    typ = LLVM_TYPES[T]
    ptyp = JuliaPointerType
    vtyp = "<$W x $typ>"
    alignment = Base.datatype_alignment(T)
    instrs = """
        %ptr = inttoptr $ptyp %0 to $typ*
        %res = load $typ, $typ* %ptr, align $alignment
        %ie = insertelement $vtyp undef, $typ %res, i32 0
        %v = shufflevector $vtyp %ie, $vtyp undef, <$W x i32> zeroinitializer
        ret $vtyp %v
    """
    quote
        $(Expr(:meta,:inline))
        Vec(llvmcall( $instrs, _Vec{$W,$T}, Tuple{Ptr{$T}}, ptr ))
    end
end
# @generated function Base.zero(::Type{Vec{W,T}}) where {W,T}
#     typ = LLVM_TYPES[T]
#     instrs = "ret <$W x $typ> zeroinitializer"
#     quote
#         $(Expr(:meta,:inline))
#         Vec(llvmcall($instrs, _Vec{$W,$T}, Tuple{}, ))
#     end
# end
# @inline vbroadcast(::Val{1}, s::T) where {T <: NativeTypes} = s
# @inline vbroadcast(::Val{1}, s::Ptr{T}) where {T <: NativeTypes} = s
@inline vzero(::Val{W}, ::Type{T}) where {W,T} = zero(Vec{W,T})
@inline Base.zero(::Vec{W,T}) where {W,T} = zero(Vec{W,T})
@inline Base.one(::Vec{W,T}) where {W,T} = vbroadcast(Val{W}(), one(T))

@inline Base.one(::Type{Vec{W,T}}) where {W,T} = vbroadcast(Val{W}(), one(T))
@inline Base.oneunit(::Type{Vec{W,T}}) where {W,T} = vbroadcast(Val{W}(), one(T))
@inline vzero(::Type{T}) where {T<:Number} = zero(T)
@inline vzero() = vzero(pick_vector_width_val(Float64), Float64)
# @inline sveczero(::Type{T}) where {T} = Svec(vzero(pick_vector_width_val(T)))
# @inline sveczero() = Svec(vzero(pick_vector_width_val(Float64)))

@inline Vec{W,T}(s::Integer) where {W,T<:Integer} = vbroadcast(Val{W}(), s % T)
@inline Vec{W,T}(s) where {W,T} = vbroadcast(Val{W}(), T(s))
@inline Vec{W}(s::T) where {W,T<:NativeTypes} = vbroadcast(Val{W}(), s)
@inline Vec(s::T) where {T<:NativeTypes} = vbroadcast(pick_vector_width_val(T), s)




    