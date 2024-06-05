
########################################################################
# Basic getters                                                        #
########################################################################
domain(f::CoveringMorphism) = f.domain
codomain(f::CoveringMorphism) = f.codomain
getindex(f::CoveringMorphism, U::AbsAffineScheme) = f.morphisms[U]
morphisms(f::CoveringMorphism) = f.morphisms

