istable(::Type{<:AbstractMatrix}) = false

rows(m::T) where {T <: AbstractMatrix} = throw(ArgumentError("a '$T' is not a table; see `?Tables.table` for ways to treat an AbstractMatrix as a table"))
columns(m::T) where {T <: AbstractMatrix} = throw(ArgumentError("a '$T' is not a table; see `?Tables.table` for ways to treat an AbstractMatrix as a table"))

struct MatrixTable{T <: AbstractMatrix} <: AbstractColumns
    names::Vector{Symbol}
    lookup::Dict{Symbol, Int}
    matrix::T
end

isrowtable(::Type{<:MatrixTable}) = true
names(m::MatrixTable) = getfield(m, :names)

# row interface
struct MatrixRow{T} <: AbstractRow
    row::Int
    source::MatrixTable{T}
end

getcolumn(m::MatrixRow, ::Type, col::Int, nm::Symbol) =
    getfield(getfield(m, :source), :matrix)[getfield(m, :row), col]
getcolumn(m::MatrixRow, i::Int) =
    getfield(getfield(m, :source), :matrix)[getfield(m, :row), i]
getcolumn(m::MatrixRow, nm::Symbol) =
    getfield(getfield(m, :source), :matrix)[getfield(m, :row), getfield(getfield(m, :source), :lookup)[nm]]
columnnames(m::MatrixRow) = names(getfield(m, :source))

schema(m::MatrixTable{T}) where {T} = Schema(Tuple(names(m)), NTuple{size(getfield(m, :matrix), 2), eltype(T)})
Base.eltype(m::MatrixTable{T}) where {T} = MatrixRow{T}
Base.length(m::MatrixTable) = size(getfield(m, :matrix), 1)

Base.iterate(m::MatrixTable, st=1) = st > length(m) ? nothing : (MatrixRow(st, m), st + 1)

# column interface
Columns(m::T) where {T <: MatrixTable} = Columns{T}(m)
columnaccess(::Type{<:MatrixTable}) = true
columns(m::MatrixTable) = m
getcolumn(m::MatrixTable, ::Type{T}, col::Int, nm::Symbol) where {T} = getfield(m, :matrix)[:, col]
getcolumn(m::MatrixTable, nm::Symbol) = getfield(m, :matrix)[:, getfield(m, :lookup)[nm]]
getcolumn(m::MatrixTable, i::Int) = getfield(m, :matrix)[:, i]
columnnames(m::MatrixTable) = names(m)

"""
    Tables.table(m::AbstractMatrix; [header::Vector{Symbol}])

Wrap an `AbstractMatrix` (`Matrix`, `Adjoint`, etc.) in a `MatrixTable`, which satisfies
the Tables.jl interface. This allows accesing the matrix via `Tables.rows` and
`Tables.columns`. An optional keyword argument `header` can be passed as a `Vector{Symbol}`
to be used as the column names. Note that no copy of the `AbstractMatrix` is made.
"""
function table(m::AbstractMatrix; header::Vector{Symbol}=[Symbol("Column$i") for i = 1:size(m, 2)])
    length(header) == size(m, 2) || throw(ArgumentError("provided column names `header` length must match number of columns in matrix ($(size(m, 2))"))
    lookup = Dict(nm=>i for (i, nm) in enumerate(header))
    return MatrixTable(header, lookup, m)
end

"""
    Tables.matrix(table; transpose::Bool=false)

Materialize any table source input as a `Matrix`. If the table column types are not homogenous,
they will be promoted to a common type in the materialized `Matrix`. Note that column names are
ignored in the conversion. By default, input table columns will be materialized as corresponding
matrix columns; passing `transpose=true` will transpose the input with input columns as matrix rows.
"""
function matrix(table; transpose::Bool=false)
    cols = columns(table)
    types = schema(cols).types
    T = reduce(promote_type, types)
    n, p = rowcount(cols), length(types)
    if !transpose
        mat = Matrix{T}(undef, n, p)
        for (i, col) in enumerate(Columns(cols))
            mat[:, i] = col
        end
    else
        mat = Matrix{T}(undef, p, n)
        for (i, col) in enumerate(Columns(cols))
            mat[i, :] = col
        end
    end
    return mat
end
