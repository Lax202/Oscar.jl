#####################################################
# 1 Basic attributes
#####################################################

@doc raw"""
    coordinate_ring(f::FamilyOfSpaces)

Return the coordinate ring of a generic member of the family of spaces.

```jldoctest
julia> ring, (f, g, Kbar, u) = QQ["f", "g", "Kbar", "u"]
(Multivariate polynomial ring in 4 variables over QQ, QQMPolyRingElem[f, g, Kbar, u])

julia> grading = [4 6 1 0; 0 0 0 1]
2×4 Matrix{Int64}:
 4  6  1  0
 0  0  0  1

julia> d = 3
3

julia> f = family_of_spaces(ring, grading, d)
A family of spaces of dimension d = 3

julia> coordinate_ring(f)
Multivariate polynomial ring in 4 variables f, g, Kbar, u
  over rational field
```
"""
coordinate_ring(f::FamilyOfSpaces) = f.coordinate_ring

# For convenience, so that this space behaves similar to a toric variety.
cox_ring(f::FamilyOfSpaces) = f.coordinate_ring


@doc raw"""
    weights(f::FamilyOfSpaces)

Return the grading of the coordinate ring of a generic member of the family of spaces.

```jldoctest
julia> ring, (f, g, Kbar, u) = QQ["f", "g", "Kbar", "u"]
(Multivariate polynomial ring in 4 variables over QQ, QQMPolyRingElem[f, g, Kbar, u])

julia> grading = [4 6 1 0; 0 0 0 1]
2×4 Matrix{Int64}:
 4  6  1  0
 0  0  0  1

julia> d = 3
3

julia> f = family_of_spaces(ring, grading, d)
A family of spaces of dimension d = 3

julia> weights(f)
2×4 Matrix{Int64}:
 4  6  1  0
 0  0  0  1
```
"""
weights(f::FamilyOfSpaces) = f.grading


@doc raw"""
    dim(f::FamilyOfSpaces)

Return the dimension of the generic member of the family of spaces.

```jldoctest
julia> ring, (f, g, Kbar, u) = QQ["f", "g", "Kbar", "u"]
(Multivariate polynomial ring in 4 variables over QQ, QQMPolyRingElem[f, g, Kbar, u])

julia> grading = [4 6 1 0; 0 0 0 1]
2×4 Matrix{Int64}:
 4  6  1  0
 0  0  0  1

julia> d = 3
3

julia> f = family_of_spaces(ring, grading, d)
A family of spaces of dimension d = 3

julia> dim(f)
3
```
"""
dim(f::FamilyOfSpaces) = f.dim


#####################################################
# 2 Advanced attributes
#####################################################

@doc raw"""
    stanley_reisner_ideal(f::FamilyOfSpaces)

Return the equivalent of the Stanley-Reisner ideal
for the generic member of the family of spaces.

```jldoctest
julia> coord_ring, (f, g, Kbar, u) = QQ["f", "g", "Kbar", "u"]
(Multivariate polynomial ring in 4 variables over QQ, QQMPolyRingElem[f, g, Kbar, u])

julia> grading = [4 6 1 0; 0 0 0 1]
2×4 Matrix{Int64}:
 4  6  1  0
 0  0  0  1

julia> d = 3
3

julia> f = family_of_spaces(coord_ring, grading, d)
A family of spaces of dimension d = 3

julia> stanley_reisner_ideal(f)
ideal(f*g*Kbar*u)
```
"""
@attr MPolyIdeal{QQMPolyRingElem} function stanley_reisner_ideal(f::FamilyOfSpaces)
  ring = coordinate_ring(f)
  variables = gens(ring)
  combis = Oscar.combinations(length(variables), dim(f)+1)
  ideal_generators = [prod([variables[i] for i in c]) for c in combis]
  return ideal(ideal_generators)
end


@doc raw"""
    irrelevant_ideal(f::FamilyOfSpaces)

Return the equivalent of the irrelevant ideal
for the generic member of the family of spaces.

```jldoctest
julia> coord_ring, (f, g, Kbar, u) = QQ["f", "g", "Kbar", "u"]
(Multivariate polynomial ring in 4 variables over QQ, QQMPolyRingElem[f, g, Kbar, u])

julia> grading = [4 6 1 0; 0 0 0 1]
2×4 Matrix{Int64}:
 4  6  1  0
 0  0  0  1

julia> d = 3
3

julia> f = family_of_spaces(coord_ring, grading, d)
A family of spaces of dimension d = 3

julia> irrelevant_ideal(f)
ideal(u, Kbar, g, f)
```
"""
@attr MPolyIdeal{QQMPolyRingElem} function irrelevant_ideal(f::FamilyOfSpaces)
  ring = coordinate_ring(f)
  variables = gens(ring)
  all_indices = collect(1:length(variables))
  combis = Oscar.combinations(length(variables), dim(f))
  combis = [setdiff(all_indices, c) for c in combis]
  ideal_generators = [prod([variables[i] for i in c]) for c in combis]
  return ideal(ideal_generators)
end


@doc raw"""
    ideal_of_linear_relations(f::FamilyOfSpaces)

Return the equivalent of the ideal of linear relations
for the generic member of the family of spaces.

```jldoctest
julia> coord_ring, (f, g, Kbar, u) = QQ["f", "g", "Kbar", "u"]
(Multivariate polynomial ring in 4 variables over QQ, QQMPolyRingElem[f, g, Kbar, u])

julia> grading = [4 6 1 0; 0 0 0 1]
2×4 Matrix{Int64}:
 4  6  1  0
 0  0  0  1

julia> f = family_of_spaces(coord_ring, grading, 3)
A family of spaces of dimension d = 3

julia> ideal_of_linear_relations(f)
ideal(-5*f + 3*g + 2*Kbar, -3*f + 2*g)
```
"""
@attr MPolyIdeal{QQMPolyRingElem} function ideal_of_linear_relations(f::FamilyOfSpaces)
  ring = coordinate_ring(f)
  variables = gens(ring)
  w = weights(f)
  ideal_gens = right_kernel(ZZMatrix(w))[2]
  ideal_gens = [sum([ideal_gens[l,k] * variables[l] for l in 1:nrows(ideal_gens)]) for k in 1:ncols(ideal_gens)]
  return ideal(ideal_gens)
end
