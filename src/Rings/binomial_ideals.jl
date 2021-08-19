import Oscar.Singular.lib4ti2_jll
export isbinomial, iscellular, isunital, binomial_primary_decomposition, 
       cellular_decomposition, cellular_associated_primes, cellular_minimal_associated_primes, cellular_hull, cellular_primary_decomposition
@doc Markdown.doc"""
    isbinomial(f::MPolyElem)

Return true if `f` consists of at most 2 terms,
false otherwise.
"""
function isbinomial(f::MPolyElem)
  return length(f) <= 2
end


@doc Markdown.doc"""
    isbinomial(I::MPolyIdeal)

Return true if `I` can be generated by polynomials consisting of at most 2 terms, false otherwise.
"""
function isbinomial(I::MPolyIdeal)
  if _isbinomial(gens(I))
    return true
  end
  return _isbinomial(groebner_basis(I, complete_reduction = true))
end

function _isbinomial(v::Vector{<: MPolyElem})
  return all(isbinomial, v)
end

@doc Markdown.doc"""
    iscellular(I::MPolyIdeal)

Given a binomial ideal `I`, return `true` together with the indices of the cellular variables if `I` is cellular.
Return `false` together with the index of a variable which is a zerodivisor but not nilpotent modulo `I`, otherwise.

# Examples
```jldoctest
julia> R, x = PolynomialRing(QQ, "x" => 1:6)
(Multivariate Polynomial Ring in 6 variables x[1], x[2], x[3], x[4], ..., x[6] over Rational Field, fmpq_mpoly[x[1], x[2], x[3], x[4], x[5], x[6]])

julia> I = ideal(R, [x[5]*(x[1]-x[2]), x[6]*(x[3]-x[4]), x[5]^2, x[6]^2, x[5]*x[6]])
ideal(x[1]*x[5] - x[2]*x[5], x[3]*x[6] - x[4]*x[6], x[5]^2, x[6]^2, x[5]*x[6])

julia> iscellular(I)
(true, [1, 2, 3, 4])

julia> R, (x,y,z) = PolynomialRing(QQ, ["x", "y", "z"])
(Multivariate Polynomial Ring in x, y, z over Rational Field, fmpq_mpoly[x, y, z])

julia> I = ideal(R, [x-y,x^3-1,z*y^2-z])
ideal(x - y, x^3 - 1, y^2*z - z)

julia> iscellular(I)
(false, [3])
```
"""
function iscellular(I::MPolyIdeal)
  if isbinomial(I) 
    return _iscellular(I)
  else
    error("Not yet implemented")
  end
end

function _iscellular(I::MPolyIdeal)
  #input: binomial ideal in a polynomial ring
  #output: the decision true/false whether I is cellular or not
  #if it is cellular, return true and the cellular variables, otherwise return the
  #index of a variable which is a zerodivisor but not nilpotent modulo I
  if iszero(I)
    return false, Int[-1]
  elseif isone(I)
    return false, Int[-1]
  end
  Delta = Int64[]
  Rxy = base_ring(I)
  variables = gens(Rxy)
  helpideal = ideal(Rxy, zero(Rxy))

  for i = 1:ngens(Rxy)
    J = ideal(Rxy, variables[i])
    sat = saturation(I, J)
    if !isone(sat)
      push!(Delta, i)
    end
  end

  #compute product of ring variables in Delta
  prodRingVar = reduce(*, variables[i] for i in Delta; init = one(Rxy))
  prodRingVarIdeal = ideal(Rxy, prodRingVar)
  J = saturation(I, prodRingVarIdeal)

  if issubset(J, I)
    #then I==J
    #in this case I is cellular with respect to Delta
    return true, Delta
  end

  for i in Delta
    J = quotient(I, ideal(Rxy, variables[i]))
    if !issubset(J, I)
      return false, Int[i]
    end
  end
  error("Something went wrong")
end

@doc Markdown.doc"""
    cellular_decomposition(I::MPolyIdeal)

Given a binomial ideal `I`, return a cellular decomposition of `I`.

# Examples
```jldoctest
julia> R, (x,y,z) =  PolynomialRing(QQ, ["x", "y", "z"])
(Multivariate Polynomial Ring in x, y, z over Rational Field, fmpq_mpoly[x, y, z])

julia> I = ideal(R, [x-y,x^3-1,z*y^2-z])
ideal(x - y, x^3 - 1, y^2*z - z)

julia> cellular_decomposition(I)
2-element Vector{MPolyIdeal{fmpq_mpoly}}:
 ideal(y - 1, x - 1)
 ideal(x - y, x^3 - 1, y^2*z - z, z)
```
"""
function cellular_decomposition(I::MPolyIdeal)
  #with less redundancies
  #input: binomial ideal I
  #output: a cellular decomposition of I
  #@assert !iszero(I) && !isone(I)
  @assert isbinomial(I)

  fl, v = _iscellular(I)
  if fl
    return typeof(I)[I]
  end
  #choose a variable which is a zero divisor but not nilptent modulo I -> A[2] (if not dummer fall)
  #determine the power s s.t. (I:x_i^s)==(I:x_i^infty)
  Rxy = base_ring(I)
  variables = gens(Rxy)
  J = ideal(Rxy, variables[v[1]])
  I1, ksat = saturation_with_index(I, J)
  #now compute the cellular decomposition of the binomial ideals (I:x_i^s) and I+(x_i^s)
  #by recursively calling the algorithm
  decomp = typeof(I)[]
  I2 = I+ideal(Rxy, variables[v[1]]^ksat)

  DecompI1 = cellular_decomposition(I1)
  DecompI2 = cellular_decomposition(I2)

  #now check for redundancies
  redTest = ideal(Rxy, one(Rxy))
  redTestIntersect = ideal(Rxy, one(Rxy))
  for i = 1:length(DecompI1)
    redTestIntersect = intersect(redTest, DecompI1[i])
    if !issubset(redTest, redTestIntersect)
      push!(decomp, DecompI1[i])
    end
    redTest = redTestIntersect
  end
  for i = 1:length(DecompI2)
    redTestIntersect = intersect(redTest, DecompI2[i])
    if !issubset(redTest, redTestIntersect)
      push!(decomp, DecompI2[i])
    end
    redTest = redTestIntersect
  end
  return decomp
end


function _isunital(gens::Vector{<: MPolyElem})
  R = base_ring(gens[1])
  for i = 1:length(gens)
    if length(gens[i]) <= 1
      continue
    end
    c = collect(coefficients(gens[i]))::Vector{elem_type(R)}
    if !iszero(c[1] + c[2])  
      return false
    end
  end
  return true
end

@doc Markdown.doc"""
    isunital(I::MPolyIdeal)

Given a binomial ideal `I`, return true if `I` can be generated by differences of monomials and monomials.

# Examples
```jldoctest
julia> R, (x, y, z) = PolynomialRing(QQ, ["x", "y", "z"])
(Multivariate Polynomial Ring in x, y, z over Rational Field, fmpq_mpoly[x, y, z])

julia> I = ideal(R, [x+y])
ideal(x + y)

julia> isunital(I)
false

julia> J = ideal(R, [x^2-y^3, z^2])
ideal(x^2 - y^3, z^2)

julia> isunital(J)
true
```
"""
function isunital(I::MPolyIdeal)
  #check if I is a unital ideal
  #(i.e. if it is generated by pure difference binomials and monomials)
  gI = gens(I)
  if _isbinomial(gI) && _isunital(gI)
    return true
  end
  gB = groebner_basis(I, complete_reduction = true)
  return _isbinomial(gB) && _isunital(gB)
end


function _remove_redundancy(A::Vector{Tuple{T, T}}) where T <: MPolyIdeal
  #input:two Array of ideals, the first are primary ideals, the second the corresponding associated primes
  #output:Arrays of ideals consisting of some ideals less which give the same interseciton as
  #all ideals before
  fa = _find_minimal([x[1] for x in A])
  return A[fa]
end

function inclusion_minimal_ideals(A::Vector{T}) where T <: MPolyIdeal
  #returns all ideals of A which are minimal with respect to inclusion
  fa = _find_minimal(A)
  return A[fa]
end

function _find_minimal(A::Vector{T}) where T <: MPolyIdeal
  isminimal = trues(length(A))
  for i = 1:length(A)
    if !isminimal[i]
      continue
    end
    for j = 1:length(A)
      if i == j || !isminimal[j]
        continue
      end
      if issubset(A[i], A[j])
        isminimal[j] = false
      elseif issubset(A[j], A[i])
        isminimal[i] = false
        break
      end
    end
  end
  fa = findall(isminimal)
  return fa
end

function cellular_decomposition_macaulay(I::MPolyIdeal)
  #algorithm after Macaulay2 implementation for computing a cellular decomposition of a binomial ideal
  #seems to be faster than cellularDecomp, but there are still examples which are really slow

  if !isbinomial(I)
    error("Input ideal is not binomial")
  end

  R = base_ring(I)
  n = nvars(R)
  intersectAnswer = ideal(R, one(R))
  res = typeof(I)[]
  todo = Tuple{Vector{elem_type(R)}, Vector{elem_type(R)}, typeof(I)}[(elem_type(R)[], gens(R), I)]
  #every element in the todo list has three dedicated data:
  #1: contains a list of variables w.r.t. which it is already saturated
  #2: conatains variables to be considered for cell variables
  #3: is the ideal to decompose

  while !isempty(todo)
    L = popfirst!(todo)
    if issubset(intersectAnswer, L[3])
      #found redundant component
      continue
    elseif isempty(L[2])
      #no variables remain to check -> we have an answer
      newone = L[3] #ideal
      push!(res, newone)
      intersectAnswer = intersect(intersectAnswer, newone)
      if issubset(intersectAnswer, I)
        return inclusion_minimal_ideals(res)
      end
    else
      #there are remaining variables
      L2 = copy(L[2])
      i = popfirst!(L2) #variable under consideration
      J, k = saturation_with_index(L[3], ideal(R, i))
      if k > 0
        #if a division was needed we add the monomial i^k to the ideal
        #under consideration
        J2 = L[3] + ideal(R, [i^k])
        #compute product of all variables in L[1]
        r = reduce(*, L[1], init = one(R))
        J2 = saturation(J2, ideal(R, r))
        if !isone(J2)
          #we have to decompose J2 further
          push!(todo, (copy(L[1]), L2, J2))
        end
      end
      #continue with the next variable and add i to L[1]
      if !isone(J)
        L1 = copy(L[1])
        push!(L1, i)
        push!(todo, (L[1], L2, J))
      end
    end
  end
  return inclusion_minimal_ideals(res)
end

###################################################################################
#
#       Partial characters and ideals
#
###################################################################################

function ideal_from_character(P::QabModule.PartialCharacter, R::MPolyRing)
  #input: partial character P and a polynomial ring R
  #output: the ideal $I_+(P)=\langle x^{u_+}- P(u)x^{u_-} \mid u \in P.A \rangle$

  @assert ncols(P.A) == nvars(R)
  #test if the domain of the partial character is the zero lattice
  if isone(nrows(P.A)) && QabModule.have_same_span(P.A, zero_matrix(FlintZZ, 1, ncols(P.A)))
    return ideal(R, zero(R))
  end

  #now case if P.A is the identity matrix
  #then the ideal generated by the generators of P.A suffices and gives the whole ideal I_+(P)
  #note that we can only compare the matrices if P.A is a square matrix
  if ncols(P.A) == nrows(P.A) && isone(P.A)
    return _make_binomials(P, R)
  end

  #now check if the only values of P taken on the generators of the lattice is one
  #then we can use markov bases
  #simple test
  test = true
  i = 1
  Variables = gens(R)
  I = ideal(R, zero(R))

  while test && i <= length(P.b)
    if !isone(P.b[i])
      #in this case there is a generator g for which P(g)!=1
      test = false
    end
    i=i+1
  end

  if test
    #then we can use markov bases to get the ideal
    A = markov4ti2(P.A)
    #now get the ideal corresponding to the computed markov basis
    #-> we have nr generators for the ideal
    #for each row vector compute the corresponding binomial
    for k = 1:nrows(A)
      monomial1 = one(R)
      monomial2 = one(R)
      for s = 1:ncols(A)
        expn = A[k,s]
        if expn < 0
          monomial2=monomial2*Variables[s]^(-expn)
        elseif expn > 0
          monomial1=monomial1*Variables[s]^expn
        end
      end
      #the new generator for the ideal is monomial1-minomial2
      I += ideal(R, monomial1-monomial2)
    end
    return I
  end

  #now consider the last case where we have to saturate
  I = _make_binomials(P, R)
  #now we have to saturate the ideal by the product of the ring variables
  varProduct = prod(Variables)
  return saturation(I, ideal(R, varProduct))
end

function _make_binomials(P::QabModule.PartialCharacter, R::MPolyRing)
  #output: ideal generated by the binomials corresponding to the generators of the domain P.A of the partial character P
  #Note: This is not the ideal I_+(P)!!
  @assert ncols(P.A) == nvars(R)
  Variables = gens(R)
  #-> we have nr binomial generators for the ideal
  I = ideal(R, zero(R))

  for k = 1:nrows(P.A)
    monomial1 = one(R)
    monomial2 = one(R)
    for s = 1:ncols(P.A) 
      expn = P.A[k,s]
      if expn < 0
        monomial2 *= Variables[s]^(-expn)
      elseif expn > 0
        monomial1 *= Variables[s]^expn
      end
    end
    #the new generator for the ideal is monomial1-P.b[k]*monomial2
    I += ideal(R, monomial1-P.b[k]*monomial2)
  end
  return I
end

function partial_character_from_ideal(I::MPolyIdeal, R::MPolyRing)
  #input: cellular binomial ideal
  #output: the partial character corresponding to the ideal I \cap k[\mathbb{N}^\Delta]

  #first test if the input ideal is really a cellular ideal
  if !isbinomial(I)
    error("Input ideal is not binomial")
  end
  cell = iscellular(I)
  if !cell[1]
    error("input ideal is not cellular")
  end

  Delta = cell[2]   #cell variables
  if isempty(Delta)
    return QabModule.partial_character(zero_matrix(FlintZZ, 1, nvars(R)), [one(QabModule.Qab)], Set{Int64}())
  end

  #now consider the case where Delta is not empty
  #fist compute the intersection I \cap k[\Delta]
  #for this use eliminate function from Singular. We first have to compute the product of all
  #variables not in Delta
  Variables = gens(R)
  to_eliminate = elem_type(R)[Variables[i] for i = 1:nvars(R) if !(i in Delta)]
  if isempty(to_eliminate)
    J = I
  else
    J = eliminate(I, to_eliminate)
  end
  Qabcl, = abelian_closure(QQ)
  if iszero(J)
    return QabModule.partial_character(zero_matrix(FlintZZ, 1, nvars(R)), [one(Qabcl)], Set{Int64}())
  end
  #now case if J \neq 0
  #let ts be a list of minimal binomial generators for J
  gb = groebner_basis(J, complete_reduction = true)
  vs = zero_matrix(FlintZZ, 0, nvars(R))
  images = QabElem[]
  for t in gb
    #TODO: Once tail will be available, use it.
    lm = leading_monomial(t)
    tl = t - lm
    u = exponent_vector(lm, 1)
    v = exponent_vector(tl, 1)
    #now test if we need the vector uv
    uv = matrix(FlintZZ, 1, nvars(R), Int[u[j]-v[j] for j  =1:length(u)]) #this is the vector of u-v
    #TODO: It can be done better by saving the hnf...
    if !can_solve(vs, uv, side = :left)[1]
      push!(images, -Qabcl(leading_coefficient(tl)))
      vs = vcat(vs, uv)#we have to save u-v as generator for the lattice
    end
  end
  #delete zero rows in the hnf of vs so that we do not get problems when considering a
  #saturation
  hnf!(vs)
  i = nrows(vs)
  while iszero_row(vs, i)
    i -= 1
  end
  vs = view(vs, 1:i, 1:nvars(R))
  return QabModule.partial_character(vs, images, Set{Int64}(Delta))
end

###################################################################################
#
#   Embedded associated lattice witnesses and hull
#
###################################################################################
"""
    cellular_standard_monomials(I::MPolyIdeal)

Given a cellular ideal `I`, return the standard monomials of `I`.
"""
function cellular_standard_monomials(I::MPolyIdeal)
  
#=`I `\cap `k[`\mathbb{N}`^`{`\Delta`^`c`}]` (these are only finitely many).=#

  cell = iscellular(I)
  if !cell[1]
    error("Input ideal is not cellular")
  end
  R = base_ring(I)

  if length(cell[2]) == nvars(R)
    return elem_type(R)[one(R)]
  end
  #now we start computing the standard monomials
  #first determine the set Delta^c of noncellular variables
  DeltaC = Int[i for i = 1:nvars(R) if !(i in cell[2])]

  #eliminate the variables in Delta
  Variables = gens(R)
  prodDelta = elem_type(R)[Variables[i] for i in cell[2]]
  if isempty(prodDelta)
    J = I
  else
    J = eliminate(I, prodDelta)
  end

  bas = Vector{elem_type(R)}[]
  for i in DeltaC
    mon = elem_type(R)[] #this will hold set of standard monomials
    push!(mon, one(R))
    x = Variables[i]
    while !(x in I)
      push!(mon, x)
      x *= Variables[i]
    end
    push!(bas, mon)
  end

  leadIdeal = leading_ideal(J)
  res = elem_type(R)[]
  it = Hecke.cartesian_product_iterator(UnitRange{Int}[1:length(x) for x in bas], inplace = true)
  for I in it
    testmon = prod(bas[i][I[i]] for i = 1:length(I))
    if !(testmon in leadIdeal)
      push!(res, testmon)
    end
  end
  return res
end

"""
    witness_monomials(I::MPolyIdeal)

Given a cellular binomial ideal I, return a set of monomials generating M_{emb}(I)
"""
function witness_monomials(I::MPolyIdeal)
  #test if input ideal is cellular
  cell = iscellular(I)
  if !cell[1]
    error("input ideal is not cellular")
  end

  R = base_ring(I)
  Delta = cell[2]
  #compute the PartialCharacter corresponding to I and the standard monomials of I \cap k[N^Delta]
  P = partial_character_from_ideal(I, R)
  M = cellular_standard_monomials(I)  #array of standard monomials, this is our to-do list
  witnesses = elem_type(R)[]   #this will hold our set of witness monomials

  for i = 1:length(M)
    el = M[i]
    Iquotm = quotient(I, ideal(R, el))
    Pquotm = partial_character_from_ideal(Iquotm, R)
    if rank(Pquotm.A) > rank(P.A)
      push!(witnesses, el)
    end
    #by checking for divisibility of the monomials in M by M[1] respectively of M[1]
    #by monomials in M, some monomials in M necessarily belong to Memb, respectively can
    #be directly excluded from being elements of Memb
    #todo: implement this for improvement
  end
  return witnesses
end

@doc Markdown.doc"""
    cellular_hull(I::MPolyIdeal)

Given a cellular binomial ideal `I`, return the intersection 
of the minimal primary components of `I`.

# Examples
```jldoctest
julia> R, x = PolynomialRing(QQ, "x" => 1:6)
(Multivariate Polynomial Ring in 6 variables x[1], x[2], x[3], x[4], ..., x[6] over Rational Field, fmpq_mpoly[x[1], x[2], x[3], x[4], x[5], x[6]])

julia> I = ideal(R, [x[5]*(x[1]-x[2]), x[6]*(x[3]-x[4]), x[5]^2, x[6]^2, x[5]*x[6]])
ideal(x[1]*x[5] - x[2]*x[5], x[3]*x[6] - x[4]*x[6], x[5]^2, x[6]^2, x[5]*x[6])

julia> iscellular(I)
(true, [1, 2, 3, 4])

julia> cellular_hull(I)
ideal(x[1]*x[5] - x[2]*x[5], x[3]*x[6] - x[4]*x[6], x[5]^2, x[6]^2, x[5]*x[6], x[5], x[6])
```
"""
function cellular_hull(I::MPolyIdeal)
  #by theorems we know that Hull(I)=M_emb(I)+I
  cell = iscellular(I)
  if !cell[1]
    error("input ideal is not cellular")
  end
  #now construct the ideal M_emb with the above algorithm witnessMonomials
  R = base_ring(I)
  M = witness_monomials(I)
  if isempty(M)
    return I
  end
  return I + ideal(R, M)
end

###################################################################################
#
#       Associated primes
#
###################################################################################

@doc Markdown.doc"""
    cellular_associated_primes(I::MPolyIdeal{fmpq_mpoly})

Given a cellular binomial ideal `I`, return the associated primes of `I`.

# Examples
```jldoctest
julia> R, x = PolynomialRing(QQ, "x" => 1:6)
(Multivariate Polynomial Ring in 6 variables x[1], x[2], x[3], x[4], ..., x[6] over Rational Field, fmpq_mpoly[x[1], x[2], x[3], x[4], x[5], x[6]])

julia> I = ideal(R, [x[5]*(x[1]-x[2]), x[6]*(x[3]-x[4]), x[5]^2, x[6]^2, x[5]*x[6]])
ideal(x[1]*x[5] - x[2]*x[5], x[3]*x[6] - x[4]*x[6], x[5]^2, x[6]^2, x[5]*x[6])

julia> cellular_associated_primes(I)
3-element Vector{MPolyIdeal{AbstractAlgebra.Generic.MPoly{QabElem}}}:
 ideal(x5, x6)
 ideal(x1 - x2, x5, x6)
 ideal(x3 - x4, x5, x6)
```
"""
function cellular_associated_primes(I::MPolyIdeal{fmpq_mpoly}, RQab::MPolyRing = PolynomialRing(abelian_closure(QQ)[1], nvars(base_ring(I)))[1])
  #input: cellular binomial ideal
  #output: the set of associated primes of I

  if !isunital(I)
    error("Input ideal has to be a unital ideal")
  end
  cell = iscellular(I)
  if !cell[1]
    error("Input ideal is not cellular")
  end

  associated_primes = Vector{MPolyIdeal{Generic.MPoly{QabModule.QabElem}}}()  #this will hold the set of associated primes of I
  R = base_ring(I)
  
  U = cellular_standard_monomials(I)  #set of standard monomials

  #construct the ideal (x_i \mid i \in \Delta^c)
  
  Variables = gens(RQab)
  gi = elem_type(RQab)[Variables[i] for i = 1:nvars(R) if !(i in cell[2])]
  if isempty(gi)
    push!(gi, zero(RQab))
  end
  idealDeltaC = ideal(RQab, gi)
  
  for m in U
    Im = quotient(I, ideal(R, m))
    Pm = partial_character_from_ideal(Im, R)
    #now compute all saturations of the partial character Pm
    PmSat = QabModule.saturations(Pm)
    for P in PmSat
      new_id = ideal_from_character(P, RQab) + idealDeltaC
      push!(associated_primes, new_id)
    end
  end

  #now check if there are superflous elements in Ass
  res = typeof(associated_primes)() 
  for i = 1:length(associated_primes)
    found = false
    for j = 1:length(res)
      if associated_primes[i] == res[j]
        found = true
        break
      end
    end
    if !found
      push!(res, associated_primes[i])
    end
  end
  return res
end

@doc Markdown.doc"""
    cellular_minimal_associated_primes(I::MPolyIdeal{fmpq_mpoly})

Given a cellular binomial ideal `I`, return the minimal associated primes of `I`.

# Examples
```jldoctest
julia> R, x = PolynomialRing(QQ, "x" => 1:6)
(Multivariate Polynomial Ring in 6 variables x[1], x[2], x[3], x[4], ..., x[6] over Rational Field, fmpq_mpoly[x[1], x[2], x[3], x[4], x[5], x[6]])

julia> I = ideal(R, [x[5]*(x[1]-x[2]), x[6]*(x[3]-x[4]), x[5]^2, x[6]^2, x[5]*x[6]])
ideal(x[1]*x[5] - x[2]*x[5], x[3]*x[6] - x[4]*x[6], x[5]^2, x[6]^2, x[5]*x[6])

julia> cellular_minimal_associated_primes(I)
1-element Vector{MPolyIdeal{AbstractAlgebra.Generic.MPoly{QabElem}}}:
 ideal(x5, x6)
```
"""
function cellular_minimal_associated_primes(I::MPolyIdeal{fmpq_mpoly})
  #input: cellular unital ideal
  #output: the set of minimal associated primes of I

  if !isunital(I)
    error("Input ideal is not a unital ideal")
  end
  cell = iscellular(I)
  if !cell[1]
    error("Input ideal is not cellular")
  end
  R = base_ring(I)
  P = partial_character_from_ideal(I, R)
  Qabcl, = abelian_closure(QQ)
  RQab = PolynomialRing(Qabcl, nvars(R))[1]
  PSat = QabModule.saturations(P)
  minimal_associated = Vector{MPolyIdeal{Generic.MPoly{QabElem}}}() #this will hold the set of minimal associated primes

  #construct the ideal (x_i \mid i \in \Delta^c)
  Variables = gens(RQab)
  gs = [Variables[i] for i = 1:nvars(RQab) if !(i in cell[2])]
  idealDeltaC = ideal(RQab, gs)

  for Q in PSat
    push!(minimal_associated, ideal_from_character(Q, RQab)+idealDeltaC)
  end
  return minimal_associated
end

function binomial_associated_primes(I::MPolyIdeal)
  #input:unital ideal
  #output: the associated primes, but only implemented effectively in the cellular case
  #in the noncellular case compute a primary decomp and take radicals

  if !isunital(I)
    error("input ideal is not a unital ideal")
  end
  cell = iscellular(I)
  if cell[1]
    return cellular_associated_primes(I)
  end

  #now consider the case when I is not cellular and compute a primary decomposition
  PD = binomial_primary_decomposition(I)
  return typeof(I)[x[2] for x in PD]
end

###################################################################################
#
#   Primary decomposition
#
###################################################################################

    
@doc Markdown.doc"""
    cellular_primary_decomposition(I::MPolyIdeal{fmpq_mpoly})

Given a cellular binomial ideal `I`, return a binomial primary decomposition of `I`.

# Examples
```jldoctest
julia> R, x = PolynomialRing(QQ, "x" => 1:6)
(Multivariate Polynomial Ring in 6 variables x[1], x[2], x[3], x[4], ..., x[6] over Rational Field, fmpq_mpoly[x[1], x[2], x[3], x[4], x[5], x[6]])

julia> I = ideal(R, [x[5]*(x[1]-x[2]), x[6]*(x[3]-x[4]), x[5]^2, x[6]^2, x[5]*x[6]])
ideal(x[1]*x[5] - x[2]*x[5], x[3]*x[6] - x[4]*x[6], x[5]^2, x[6]^2, x[5]*x[6])

julia> cellular_primary_decomposition(I)
3-element Vector{Tuple{MPolyIdeal{AbstractAlgebra.Generic.MPoly{QabElem}}, MPolyIdeal{AbstractAlgebra.Generic.MPoly{QabElem}}}}:
 (ideal(x1*x5 - x2*x5, x3*x6 - x4*x6, x5^2, x6^2, x5*x6, x5, x6), ideal(x5, x6))
 (ideal(x1*x5 - x2*x5, x3*x6 - x4*x6, x5^2, x6^2, x5*x6, x1 - x2, x6), ideal(x1 - x2, x5, x6))
 (ideal(x1*x5 - x2*x5, x3*x6 - x4*x6, x5^2, x6^2, x5*x6, x3 - x4, x5), ideal(x3 - x4, x5, x6))
```
"""
function cellular_primary_decomposition(I::MPolyIdeal{fmpq_mpoly}, RQab::MPolyRing = PolynomialRing(abelian_closure(QQ)[1], nvars(base_ring(I)))[1])
  #algorithm from macaulay2
  #input: unital cellular binomial ideal in k[x]
  #output: binomial primary ideals which form a minimal primary decomposition of I 
  #        and the corresponding associated primes in a second array

  if !isunital(I)
    error("Input ideal is not a unital ideal")
  end

  cell = iscellular(I)
  if !cell[1]
    error("Input ideal is not cellular")
  end

  #compute associated primes
  cell_ass = cellular_associated_primes(I, RQab)

  Qab = base_ring(RQab)
  IQab = ideal(RQab, [map_coefficients(Qab, x, parent = RQab) for x in gens(I)])

  #compute product of all non cellular variables and the product of all cell variables
  R = base_ring(I)
  Variables = gens(RQab)
  prodDeltaC = elem_type(RQab)[Variables[i] for i = 1:nvars(R) if !(i in cell[2])]
  prodDelta = elem_type(RQab)[Variables[i] for i in cell[2]]

  J = ideal(RQab, prodDelta)
  T = MPolyIdeal{Generic.MPoly{QabElem}}
  res = Vector{Tuple{T, T}}()
  for P in cell_ass
    if isempty(prodDeltaC)
      helpIdeal = IQab + P
    else
      helpIdeal = IQab + eliminate(P, prodDeltaC)
    end
    #now saturate the ideal with respect to the cellular variables
    helpIdeal = saturation(helpIdeal, J)
    push!(res, (cellular_hull(helpIdeal), P))
  end
  return res
end

@doc Markdown.doc"""
    binomial_primary_decomposition(I::MPolyIdeal{fmpq_mpoly})

Given a binomial ideal `I`, return a binomial primary decomposition of `I`.

# Examples
```jldoctest
julia> R, (x,y,z) =  PolynomialRing(QQ, ["x", "y", "z"])
(Multivariate Polynomial Ring in x, y, z over Rational Field, fmpq_mpoly[x, y, z])

julia> I = ideal(R, [x-y,x^3-1,z*y^2-z])
ideal(x - y, x^3 - 1, y^2*z - z)

julia> binomial_primary_decomposition(I)
3-element Vector{Tuple{MPolyIdeal{AbstractAlgebra.Generic.MPoly{QabElem}}, MPolyIdeal{AbstractAlgebra.Generic.MPoly{QabElem}}}}:
 (ideal(x1 - x2, x1^3 - 1, x2^2*x3 - x3, x3, x2 - z(3), x1 - z(3)), ideal(x1*x2^2 - 1, x2 - z(3), x3))
 (ideal(x1 - x2, x1^3 - 1, x2^2*x3 - x3, x3, x2 + z(3) + 1, x1 + z(3) + 1), ideal(x1*x2^2 - 1, x2 + z(3) + 1, x3))
 (ideal(x2 - 1, x1 - 1, x1*x2 - 1), ideal(x2 - 1, x1 - 1, x1*x2 - 1))
```
"""
function binomial_primary_decomposition(I::MPolyIdeal{fmpq_mpoly})
  #input: a binomial ideal such that the ideals in its cellular
  #       decomposition are unital 
  #output: binomial primary ideals which form a not necessarily
  #         minimal primary decomposition of I, together with its corresponding associated primes 
  #         in the same order as the primary components

  #first compute a cellular decomposition of I
  cell_comps = cellular_decomposition_macaulay(I)

  T = MPolyIdeal{Generic.MPoly{QabElem}}
  res = Vector{Tuple{T, T}}() #This will hold the set of primary components
  #now compute a primary decomposition of each cellular component
  Qab, = abelian_closure(QQ)
  RQab = PolynomialRing(Qab, nvars(base_ring(I)))[1]
  for J in cell_comps
    resJ = cellular_primary_decomposition(J, RQab)
    append!(res, resJ)
  end
  return _remove_redundancy(res)
end

function markov4ti2(L::fmpz_mat)
  #sanity checks noch einbauen!!
  nc = ncols(L)
  nr = nrows(L)
  #have to prepare an input file for 4ti2
  #create the file julia4ti2.lat
  name = tempname()
  mkdir(name)
  name = joinpath(name, "julia4ti2")
  f=open("$name.lat","w")
  write(f,"$nr ")
  write(f,"$nc \n")

  for i=1:nr
    for j=1:nc
      write(f,"$(L[i,j]) ")
    end
    write(f,"\n")
  end
  close(f)

  #now we have the file julia4ti2.lat in the current working directory
  #can run 4ti2 with this input file to get a markov basis
  lib4ti2_jll.exe4ti2gmp() do x 
    run(ignorestatus(`$x markov -q $name`))
  end

#        run(`$(lib4ti2_jll.markov) -q $name`)
  #this creates the file julia4ti2.mar with the markov basis

  #now we have to get the matrix from julia4ti2.mat in julia
  #this is an array of thype Any
  mat_to_return = _parse_matrix("$name.mar")
  return mat_to_return
end


function _parse_matrix(filename::String)
  f = open("$filename", "r")
  ncols = -1
  s = readline(f)
  i = 1
  while s[i] != ' ' 
    i += 1
  end
  nrows = parse(Int, s[1:i-1])
  ncols = parse(Int, s[i+1:end])
  M = Matrix{Int}(undef, nrows, ncols)
  for i = 1:nrows
    s = readline(f)
    ind1 = 1
    ind2 = 2
    while s[ind2] != ' ' 
      ind2 += 1
    end
    M[i, 1] = parse(Int, s[ind1:ind2-1])
    for j = 2:ncols-1
      ind1 = ind2+1
      ind2 = ind1+1
      while s[ind2] != ' ' 
        ind2 += 1
      end
      M[i, j] = parse(Int, s[ind1:ind2-1])
    end
    ind1 = ind2+1
    M[i, ncols] = parse(Int, s[ind1:end])
  end
  return M
end

################################################################################
#
#  Birth-Death ideal - for testing purposes
#
################################################################################

function birth_death_ideal(m::Int, n::Int)
  
  #To make it clearer, I split the variables 
  U = Matrix{fmpq_mpoly}(undef, m+1, n)
  R = Matrix{fmpq_mpoly}(undef, m, n+1)
  D = Matrix{fmpq_mpoly}(undef, m+1, m)
  L = Matrix{fmpq_mpoly}(undef, m+1, n+1)
  Qxy, gQxy = PolynomialRing(FlintQQ, length(U)+length(R)+length(D)+length(L))
  pols = Vector{elem_type(Qxy)}(undef, 4*n*m)
  ind = 1
  for i = 1:m+1
    for j = 1:n
      U[i, j] = gQxy[ind]
      ind += 1
    end
  end
  for i = 1:m
    for j = 1:n+1
      R[i, j] = gQxy[ind]
      ind += 1
    end
  end
  for i = 1:m+1
    for j = 1:m
      D[i, j] = gQxy[ind]
      ind += 1
    end
  end
  for i = 1:m+1
    for j = 1:n+1
      L[i, j] = gQxy[ind]
      ind += 1
    end
  end
  ind = 1
  for i = 1:m
    for j = 1:n
      pols[ind] = U[i, j]*R[i, j+1] - R[i, j]*U[i+1, j]
      pols[ind+1] = D[i, j]*R[i, j] - R[i, j+1]*D[i+1, j]
      pols[ind+2] = D[i+1, j]*L[i+1, j] - L[i+1, j+1]*D[i, j]
      pols[ind+3] = U[i+1, j]*L[i+1, j+1] - L[i+1, j]*U[i, j]
      ind += 4
    end
  end
  return ideal(Qxy, pols)
end
