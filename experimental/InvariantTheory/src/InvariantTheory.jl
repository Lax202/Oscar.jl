import Oscar.gens, AbstractAlgebra.direct_sum, Oscar.invariant_ring
export ReductiveGroup, reductive_group, representation_matrix, group, reynolds_operator, group_ideal, canonical_representation, natural_representation
export RepresentationReductiveGroup, representation_reductive_group, representation_on_forms, representation_matrix
export InvariantRing, invariant_ring, fundamental_invariants, null_cone_ideal
##########################
#Reductive Groups
##########################
mutable struct ReductiveGroup
    field::Field #characteristic zero. implement check? 
    group::Tuple{Symbol, Int}
    group_ideal::MPolyIdeal
    reynolds_operator::Function
    canonical_representation::AbstractAlgebra.Generic.MatSpaceElem

    function ReductiveGroup(sym::Symbol, m::Int, fld::Field) #have not decided the representation yet
        #check char(fld)
        if sym == :SL 
            R, _ = polynomial_ring(fld, :z => (1:m,1:m))
            return ReductiveGroup(sym, m, R)
        elseif sym == :torus
            G = new()
            G.group = (sym, m)
            characteristic(fld) == 0 || error("Characteristic should be 0 for linearly reductive groups")
            G.field = fld
            return G
        end
    end

    function ReductiveGroup(sym::Symbol, m::Int, pring::MPolyRing) #the ring input is the group ring
        #check char(field)
        G = new()
        if sym != :SL
            error("Only implemented for SLm")
        end
        fld = base_ring(pring)
        characteristic(fld) == 0 || error("Characteristic should be 0 for linearly reductive groups")
        G.field = fld
        @assert m^2  == ngens(pring)
        G.group = (sym,m)
        G.reynolds_operator = reynolds_slm
        M = matrix(pring, m, m, gens(pring))
        G.canonical_representation = M
        G.group_ideal = ideal([det(M) - 1])
        #base ring of M has to be the same as the representation matrix when that is created later.
        return G
    end
end

function Base.show(io::IO, G::ReductiveGroup)
    print(io, "Reductive group ", G.group[1], G.group[2])
end

reductive_group(sym::Symbol, m::Int, R::MPolyRing) = ReductiveGroup(sym,m,R)
reductive_group(sym::Symbol, m::Int, F::Field) =  ReductiveGroup(sym,m,F)
group(G::ReductiveGroup) = G.group
field(G::ReductiveGroup) = G.field
reynolds_operator(G::ReductiveGroup) = G.reynolds_operator
group_ideal(G::ReductiveGroup) = G.group_ideal
canonical_representation(G::ReductiveGroup) = G.canonical_representation
natural_representation(G::ReductiveGroup) = G.canonical_representation

#####################
#Representation of Reductive Groups. Embeds SLm in GLn. 
#####################

mutable struct RepresentationReductiveGroup
    group::ReductiveGroup
    rep_mat::AbstractAlgebra.Generic.MatSpaceElem
    sym_deg::Tuple{Bool, Int}
    reynolds_v::Function

    weights::Vector{Vector{ZZRingElem}}
    
    #representation of group G over symmetric degree d
    function RepresentationReductiveGroup(G::ReductiveGroup, d::Int)
        R = new()
        R.group = G
        R.rep_mat = rep_mat_(G, d)
        R.sym_deg = (true, d)
        R.reynolds_v = reynolds_v_slm
        return R
    end

    #function RepresentationReductiveGroup(G::ReductiveGroup, W::Union{ZZMatrix, Matrix{<:Integer}, Vector{<:Integer}})
    function RepresentationReductiveGroup(G::ReductiveGroup, W::Vector{Vector{ZZRingElem}})
        if !(G.group[1] == :torus)
            return nothing
        else
            R = new()
            R.group = G
            R.weights = W
            return R
        end
    end
    
    #matrix M is the representation matrix. does not check M.
    function RepresentationReductiveGroup(G::ReductiveGroup, M::AbstractAlgebra.Generic.MatSpaceElem)
        @req base_ring(M) == base_ring(G.group_ideal) "Group ideal and representation matrix must have same parent ring"
        R = new()
        R.group = G
        R.rep_mat = M
        R.sym_deg = (false, 0)
        R.reynolds_v = reynolds_v_slm
        return R
    end
end

#representation_reductive_group(G::ReductiveGroup, d::Int) = RepresentationReductiveGroup(G, d)
representation_reductive_group(G::ReductiveGroup, M::AbstractAlgebra.Generic.MatSpaceElem) = RepresentationReductiveGroup(G,M)
group(R::RepresentationReductiveGroup) = R.group

function representation_on_forms(G::ReductiveGroup, d::Int)
    if G.group[1] == :SL
        return RepresentationReductiveGroup(G, d)
    end
end

function representation_on_weights(G::ReductiveGroup, W::Union{ZZMatrix, Matrix{<:Integer}, Vector{<:Int}})
    if G.group[1] == :torus
        V = Vector{Vector{ZZRingElem}}()
        if typeof(W) <: Vector
            G.group[2] == 1 || @error("Incompatible weights")
            for i in 1:length(W)
                push!(V, [ZZRingElem(W[i])])
            end
        else
            G.group[2] == ncols(W) || @error("Incompatible weights")
            #assume columns = G.group[2]
            for i in 1:nrows(W)
                push!(V, [ZZRingElem(W[i,j]) for j in 1:ncols(W)])
            end
        end
        return RepresentationReductiveGroup(G,V)
    end
end

function representation_reductive_group(G::ReductiveGroup)
    if G.group[1] == :SL
        M = canonical_representation(G)
        return RepresentationReductiveGroup(G,M)
    end
end

function representation_matrix(R::RepresentationReductiveGroup) 
    if isdefined(R, :rep_mat) 
        return R.rep_mat
    else 
        return nothing
    end
end

function weights(R::RepresentationReductiveGroup)
    if isdefined(R, :weights)
        return R.weights
    end
end

reductive_group(R::RepresentationReductiveGroup) = R.group

#returns dimension n
function vector_space_dimension(R::RepresentationReductiveGroup)
    if isdefined(R, :rep_mat)
        return ncols(R.rep_mat)
    elseif isdefined(R, :weights)
        return ncols(R.weights) #check
    end
end

function Base.show(io::IO, R::RepresentationReductiveGroup)
    io = AbstractAlgebra.pretty(io)
    if group(group(R))[1] == :SL
        println(io, "Representation of ", group(group(R))[1], group(group(R))[2])
        if R.sym_deg[1]
            print(io, AbstractAlgebra.Indent(), "over symmetric forms of degree ", R.sym_deg[2])
            print(io, AbstractAlgebra.Dedent())
        else
            println(io, AbstractAlgebra.Indent(), "with representation matrix")
            show(io, R.rep_mat)
            print(io, AbstractAlgebra.Dedent())
        end
    else
        println(io, "Torus of degree ", group(group(R))[2])
        print(IOContext(io, :supercompact => true), AbstractAlgebra.Indent(), "over the field ", field(group(R)))
        print(io, AbstractAlgebra.Dedent())
    end
end

function direct_sum(X::RepresentationReductiveGroup, Y::RepresentationReductiveGroup)
    @assert group(X) == group(Y)
    G = group(X)
    R = base_ring(group_ideal(G))
    Mat = block_diagonal_matrix(R, [Matrix(representation_matrix(X)), Matrix(representation_matrix(Y))])
    return RepresentationReductiveGroup(G, Mat)
end

function direct_sum(V::Vector{RepresentationReductiveGroup})
    n = length(V)
    G = group(V[1])
    for i in 2:n
        @assert G == group(V[i])
    end
    R = base_ring(group_ideal(G))
    Mat = block_diagonal_matrix(R, [Matrix(representation_matrix(V[i])) for i in 1:n])
    return RepresentationReductiveGroup(G, Mat)
end

function tensor(X::RepresentationReductiveGroup, Y::RepresentationReductiveGroup)
    @assert group(X) == group(Y)
    Mat = kronecker_product(representation_matrix(X), representation_matrix(Y))
    return RepresentationReductiveGroup(group(X), Mat)
end

function tensor(V::Vector{RepresentationReductiveGroup})
    n = length(V)
    for i in 2:n
        @assert group(V[1]) == group(V[i])
    end
    Mat = representation_matrix(V[1])
    for i in 2:n
        Mat = kronecker_product(Mat,representation_matrix(V[i]))
    end
    return RepresentationReductiveGroup(group(V[1]), Mat)
end

###############

#computes the representation matrices of SL_m acting over m-forms of symmetric degree sym_deg
function rep_mat_(G::ReductiveGroup, sym_deg::Int)
    G.group[1] == :SL || error("Only implemented for SLm")
    m = G.group[2]
    R = base_ring(G.group_ideal) # TODO: probably should have a getter function for this
    mixed_ring, t = polynomial_ring(R, "t" => 1:m)
    group_mat = natural_representation(G)
    new_vars = group_mat*t
    
    b = degree_basis(mixed_ring,sym_deg)
    n = length(b)
    
    # transform the b elements
    images_of_b = [evaluate(f, new_vars) for f in b]

    mat = zero_matrix(R, n, n)
    for j in 1:n
        f = images_of_b[j]
        x = mixed_ring()
        # express f as a linear combination of degree_basis
        for i in 1:n
            c = coeff(f, leading_exponent(b[i]))
            mat[i,j] = c / leading_coefficient(b[i])
        end
    end
    return mat
end

#computes symmetric degree basis (of the first m variables) WITH multinomial coefficients!
function degree_basis(R::MPolyRing, t::Int)
    m = ngens(R)
    C = zero_matrix(Int, m, m)
    for i in 1:m
      C[i,i] = -1 
    end
    d = zeros(m)
    A = ones(m)
    b = [t]
    P = Polyhedron((C, d), (A, b))
    L = lattice_points(P)
    W = Vector{MPolyRingElem}(undef,0)
    for l in L
        v = R(1)
        for i in 1:m
            v = v*gen(R,i)^l[i]
        end
        v = v*multinomial(t,l)
        push!(W,v)
    end
    #we reverse here to get the natural order of a degree basis, eg x^2, 2xy, y^2.
    return reverse(W)
end

#used to compute multinomial expansion coefficients (used in degree_basis)
function multinomial(n::Int, v::Union{Vector{Int64},PointVector{ZZRingElem}})
    l = length(v)
    x = 1
    for i in 1:l
        x = x*factorial(v[i])
    end
    return Int(factorial(n)/x)
end

##########################
#Invariant Rings of Reductive groups
##########################
mutable struct InvariantRing
    field::Field
    poly_ring::MPolyDecRing #graded
    
    group::ReductiveGroup
    representation::RepresentationReductiveGroup
    
    fundamental::Vector{MPolyDecRingElem}
    primary::Vector{MPolyDecRingElem}
    secondary::Vector{MPolyDecRingElem}
    
    reynolds_operator::Function
    
    NullConeIdeal::MPolyIdeal
    
    #Invariant ring of reductive group G (in representation R), no other input.
    function InvariantRing(R::RepresentationReductiveGroup) #here G already contains information n and rep_mat
        z = new()
        if isdefined(R, :weights)
            n = length(weights(R))
            z.field = field(group(R))
            super_ring, __ = graded_polynomial_ring(field(group(R)), "X"=>1:n)
            z.poly_ring = super_ring
            z.group = group(R)
            z.representation = R
            #z.fundamental = torus_invariants_fast(weights(R), ring)
            return z
        end
        n = ncols(R.rep_mat)
        z.representation = R
        z.group = R.group
        G = z.group
        z.field = G.field
        z.poly_ring, __ = graded_polynomial_ring(G.field, "X" => 1:n)
        z.reynolds_operator = reynolds_v_slm
        return z
    end
    
    #to compute invariant ring ring^G where G is the reductive group of R. 
    function InvariantRing(R::RepresentationReductiveGroup, ring::MPolyDecRing)
        n = ncols(R.rep_mat)
        n == ngens(ring) || error("The given polynomial ring is not compatible.")
        z = new()
        if isdefined(R, :weights)
            #dosomething
        end
        z.representation = R
        z.group = R.group
        G = R.group
        z.field = G.field
        z.poly_ring = ring
        z.reynolds_operator = reynolds_v_slm
        return z
    end
end

invariant_ring(R::RepresentationReductiveGroup) = InvariantRing(R)
invariant_ring(ring::MPolyDecRing, R::RepresentationReductiveGroup) = InvariantRing(R, ring)
null_cone_ideal(R::InvariantRing) = R.NullConeIdeal
poly_ring(R::InvariantRing) = R.poly_ring

function fundamental_invariants(z::InvariantRing)
    if isdefined(z, :fundamental)
        return z.fundamental
    else
        R = z.representation
        if group(group(R))[1] == :torus && isdefined(R, :weights)
            z.fundamental = torus_invariants_fast(weights(R), poly_ring(z))
            return z.fundamental
        end
        I, M = proj_of_image_ideal(R.group, R.rep_mat)
        z.NullConeIdeal = ideal(generators(R.group, I, R.rep_mat))
        z.fundamental = inv_generators(z.NullConeIdeal, R.group, z.poly_ring, M, I, z.reynolds_operator)
        return z.fundamental
    end
end

function Base.show(io::IO, R::InvariantRing) 
    io = AbstractAlgebra.pretty(io)
    println(io, "Invariant Ring of")
    show(io, R.poly_ring)
    print(io, AbstractAlgebra.Indent(),  " under group action of ", R.group.group[1], R.group.group[2])
    print(io, AbstractAlgebra.Dedent())
end

#computing the graph Gamma from Derksens paper
function image_ideal(G::ReductiveGroup, rep_mat::AbstractAlgebra.Generic.MatSpaceElem)
    R = base_ring(rep_mat)
    n = ncols(rep_mat)
    m = G.group[2]
    mixed_ring_xy, x, y, zz = polynomial_ring(G.field, "x"=>1:n, "y"=>1:n, "zz"=>1:m^2)
    ztozz = hom(R,mixed_ring_xy, gens(mixed_ring_xy)[(2*n)+1:(2*n)+(m^2)])
    genss = [ztozz(f) for f in gens(G.group_ideal)]
    #rep_mat in the new ring
    new_rep_mat = matrix(mixed_ring_xy,n,n,[ztozz(rep_mat[i,j]) for i in 1:n, j in 1:n])
    new_vars = new_rep_mat*x
    ideal_vect = y - new_vars 
    ideal_vect = vcat(ideal_vect,genss)
    return ideal(mixed_ring_xy, ideal_vect), new_rep_mat
end

#computing I_{\Bar{B}}
function proj_of_image_ideal(G::ReductiveGroup, rep_mat::AbstractAlgebra.Generic.MatSpaceElem)
    W = image_ideal(G, rep_mat)
    mixed_ring_xy = base_ring(W[2])
    n = ncols(rep_mat)
    m = G.group[2]
    #use parallelised groebner bases here. This is the bottleneck!
    return eliminate(W[1], gens(mixed_ring_xy)[(2*n)+1:(2*n)+(m^2)]), W[2]
end


#evaluate at y = 0 
function generators(G::ReductiveGroup, X::MPolyIdeal, rep_mat::AbstractAlgebra.Generic.MatSpaceElem)
    n = ncols(rep_mat)
    m = G.group[2]
    gbasis = gens(X) 
    length(gbasis) == 0 && return gbasis,new_rep_mat
    mixed_ring_xy = parent(gbasis[1])
    #evaluate at y=0
    V = vcat(gens(mixed_ring_xy)[1:n], [0 for i in 1:n], gens(mixed_ring_xy)[2*n+1:2*n+m^2])
    ev_gbasis = [evaluate(f,V)  for f in gbasis]
    #grading starts here. In the end, our invariant ring is graded.
    mixed_ring_graded, (x,y,zz) = grade(mixed_ring_xy)
    mapp = hom(mixed_ring_xy, mixed_ring_graded, gens(mixed_ring_graded))
    ev_gbasis_new = [mapp(ev_gbasis[i]) for i in 1:length(ev_gbasis)]
    if length(ev_gbasis_new) == 0
        return [mixed_ring_graded()]
    end
    return minimal_generating_set(ideal(ev_gbasis_new))
end

#computing the invariant generators.
#now we have to perform reynolds operation. This will happen in mixed_ring_xy. 
#the elements returned will be in the polynomial ring K[X]
function inv_generators(I::MPolyIdeal, G::ReductiveGroup, ringg::MPolyRing, M::AbstractAlgebra.Generic.MatSpaceElem, X::MPolyIdeal, reynolds_function::Function)
    genss = gens(I)
    if length(genss) == 0
        return Vector{elem_type(ringg)}()
    end
    mixed_ring_xy = parent(genss[1])
    R = base_ring(M)
    m = G.group[2]
    n = ncols(M)
    mapp = hom(R, mixed_ring_xy, gens(mixed_ring_xy))
    new_rep_mat = matrix(mixed_ring_xy,n,n,[mapp(M[i,j]) for i in 1:n, j in 1:n])
    #we need det_
    det_ = det(G.canonical_representation)
    mapp_ = hom(parent(det_), mixed_ring_xy, gens(mixed_ring_xy)[(2*n)+1:(2*n)+(m^2)])
    new_det = mapp_(det_)
    if G.group[1] == :SL #TODO other types of reductive groups
        new_gens_wrong_ring = [reynolds_function(genss[i], new_rep_mat, new_det, m) for i in 1:length(genss)]
    else 
        return nothing
    end
    img_genss = vcat(gens(ringg), zeros(ringg, n+m^2))
    mixed_to_ring = hom(mixed_ring_xy, ringg, img_genss)
    new_gens = Vector{elem_type(ringg)}()
    for elemm in new_gens_wrong_ring
        if elemm != 0
            push!(new_gens, mixed_to_ring(elemm))
        end
    end
    if length(new_gens) == 0
        return [ringg()]
    end
    
    #remove ugly coefficients: 
    V= Vector{FieldElem}[]
    new_gens_ = Vector{elem_type(ringg)}()
    for elem in new_gens
        V = vcat(V,collect(coefficients(elem)))
        maxx = maximum([abs(denominator(V[i])) for i in 1:length(V)])
        minn = minimum([abs(numerator(V[i])) for i in 1:length(V)])
        if denominator((maxx*elem)//minn) != 1
            error("den not 1")
        end
        push!(new_gens_, numerator((maxx*elem)//minn))
        V= Vector{FieldElem}[]
    end
    return new_gens_
end

function reynolds_v_slm(elem::MPolyDecRingElem, new_rep_mat::AbstractAlgebra.Generic.MatSpaceElem, new_det::MPolyDecRingElem, m::Int)
    mixed_ring_xy = parent(elem)
    n = ncols(new_rep_mat)
    new_vars = new_rep_mat*gens(mixed_ring_xy)[1:n]
    sum_ = mixed_ring_xy()
    phi = hom(mixed_ring_xy, mixed_ring_xy, vcat(new_vars, [0 for i in 1:ncols(new_rep_mat)+m^2]))
    sum_ = phi(elem)
    t = needed_degree(sum_, m)
    if !divides(t, m)[1]
        return parent(elem)()
    else
        p = divexact(t, m)
    end
    #num = omegap_(p, new_det, sum_)
    #den = omegap_(p, new_det, (new_det)^p)
    #if !(denominator(num//den)==1)
    #    error("denominator of reynolds not rational")
    #end
    #return numerator(num//den)
    return reynolds_slm(sum_, new_det, p)
end

function reynolds_slm(elem::MPolyRingElem, det_::MPolyRingElem, p::Int)
    num = omegap_(p,det_, elem)
    den = omegap_(p,det_,det_^p)
    if !(denominator(num//den)==1)
        error("denominator of reynolds not rational")
    end
    return numerator(num//den)
end

#used to compute the degree p of omega_p
#computes the degree of the z_ij variables of the leading term of elem.
function needed_degree(elem_::MPolyDecRingElem, m::Int)
    elem = leading_monomial(elem_)
    R = parent(elem)
    n = ngens(R) - m^2
    extra_ring, _= polynomial_ring(base_ring(R), "z"=>1:m^2)
    mapp = hom(R,extra_ring, vcat([1 for i in 1:n], gens(extra_ring)))
    return total_degree(mapp(elem))
end

 function omegap_(p::Int, det_::MPolyDecRingElem, f::MPolyDecRingElem)
     parent(det_) == parent(f) || error("Omega process ring error")
     action_ring = parent(det_)
     monos = collect(monomials(det_))
     coeffs = collect(coefficients(det_))
     for i in 1:p
     h = action_ring()
     for i in 1:length(monos)
         exp_vect = exponent_vector(monos[i], 1)
         x = f
         for i in 1:length(exp_vect)
             for j in 1:exp_vect[i]
                 x = derivative(x, i)
                 if x == 0
                     break
                 end
             end
         end
         h += coeffs[i]*x
     end
         f = h
     end
     return f
 end

#####################callable reynold's operator

#this function returns the image of elem under the reynolds operator of group with representation X
function reynolds_operator(X::RepresentationReductiveGroup, elem::MPolyRingElem)
    X.group.group[1] == :SL || error("Only implemented for SLm")
    vector_ring = parent(elem)
    G = X.group
    n = ngens(vector_ring)
    n == ncols(X.rep_mat) || error("group not compatible with element")
    m = G.group[2]
    R, _ = graded_polynomial_ring(G.field,"x"=>1:n, "y"=>1:n, "z"=>(1:m, 1:m))
    #R, _ = grade(PolynomialRing(G.field,"x"=>1:n, "y"=>1:n, "z"=>(1:m, 1:m))[1])
    map1 = hom(vector_ring, R, gens(R)[1:n])
    new_elem = map1(elem)
    group_ring = base_ring(X.rep_mat)
    map2 = hom(group_ring, R, gens(R)[2*n+1:2*n+m^2])
    new_rep_mat = map_entries(map2, X.rep_mat)
    new_det = map2(det(G.canonical_representation))
    f = X.reynolds_v(new_elem, new_rep_mat, new_det, m)
    reverse_map = hom(R, vector_ring, vcat(gens(vector_ring), [0 for i in 1:n+m^2]))
    return reverse_map(f)
end

function reynolds_operator(R::InvariantRing, elem::MPolyRingElem)
    X = R.representation
    return reynolds_operator(X, elem)
end

##########################
#fast algorithm for invariants of tori
##########################
function torus_invariants_fast(W::Vector{Vector{ZZRingElem}}, R::MPolyRing)
    #no check that length(W[i]) for all i is the same
    length(W) == ngens(R) || error("number of weights must be equal to the number of generators of the polynomial ring")
    n = length(W)
    r = length(W[1])
    #step 2
    if length(W[1]) == 1
        M = zero_matrix(Int, n, 1)
        for i in 1:n
            M[i,1] = W[i][1]
        end
        C1 = collect(lattice_points(convex_hull(M)))
    else
        M = zero_matrix(Int, 2*n, r)
        for i in 1:n
            M[i, 1:r] = 2*r*W[i]
            M[n + i, 1:r] = -2*r*W[i]   
        end
        C1 = collect(lattice_points(convex_hull(M)))
    end
    
    #get a Vector{Vector{ZZRingElem}} from Vector{PontVector{ZZRingElem}}
    C = [[ZZRingElem(0) for i in 1:r] for j in 1:length(C1)]
    for i in 1:length(C1)
        for j in 1:r
            C[i][j] = C1[i][j]
        end
    end
    #step 3
    S = Vector{Vector{elem_type(R)}}()
    U = Vector{Vector{elem_type(R)}}()
    index_0 = 0
    for point in C
        if point == [ZZRingElem(0) for i in 1:r] #this may not work CHECK
            index_0 = findfirst(item -> item == point, C)
        end
        c = true
        for i in 1:n
            if point == W[i] #check type here TODO
                push!(S, [gen(R,i)])
                push!(U, [gen(R,i)])
                c = false
                break
            end
        end
        if c == true
            push!(S, elem_type(R)[])
            push!(U, elem_type(R)[])
        end
    end
    #step 4
    @label step_4 #not sure if this is needed...
    j = 0
    for i in 1:length(U)
        if length(U[i]) != 0
            j = i
            @goto step4_b
        end
    end
    return S[index_0]
    @label step4_b
    m = U[j][1]
    w = C[j] #weight_of_monomial(m, W)
    #step 5 - 7
    for i in 1:n
        u = m*gen(R,i)
        v = w + W[i]
        if v in C
            index = findfirst(item -> item == v, C)
            c = true
            if length(S[index]) == 0
                c = true
            end
            for elem in S[index]
                if divides(u, elem)[1]
                    c = false
                    break
                end
            end
            if c == true
                push!(S[index], u)
                push!(U[index], u)
            end
        end
    end
    deleteat!(U[j], findall(item -> item == m, U[j]))
    @goto step_4
end
