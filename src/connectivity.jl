export edge_connectivity, min_edge_cut

"""
`min_edge_cut(G)` returns a minimum size set of edges whose removal
disconnects `G`. The graph must have at least two vertices.
"""
function min_edge_cut(G::SimpleGraph{T})::Set{Tuple{T,T}} where T
    n = NV(G)
    n > 1 || error("Graph must have at least two vertices")

    if cache_check(G,:min_edge_cut)
        return cache_recall(G,:min_edge_cut)
    end

    if !is_connected(G)
        X = Set{Tuple{T,T}}()
        cache_save(G,:min_edge_cut,X)
        return X
    end

    VV = vlist(G)
    EE = elist(G)

    MOD = Model(with_optimizer(_SOLVER.Optimizer; _OPTS...))

    @variable(MOD,a[VV],Bin)  # in part 1
    @variable(MOD,b[VV],Bin)  # in part 2
    @variable(MOD,c[EE],Bin)  # span between the parts

    for v in VV
        @constraint(MOD,a[v]+b[v]==1)
    end

    @constraint(MOD,sum(a[v] for v in VV) >= 1)
    @constraint(MOD,sum(b[v] for v in VV) >= 1)

    for e in EE
        u,v = e
        @constraint(MOD,a[u]+b[v]-1 <= c[e])
        @constraint(MOD,a[v]+b[u]-1 <= c[e])
    end

    @objective(MOD, Min, sum(c[e] for e in EE))

    optimize!(MOD)
    status = Int(termination_status(MOD))

    C =  value.(c)

    X = Set(e for e in EE if C[e] > 0.5)
    cache_save(G,:min_edge_cut,X)
    return X
end

"""
`edge_connectivity(G)` returns the size of a minimum edge cut of `G`.
"""
edge_connectivity(G::SimpleGraph) = length(min_edge_cut(G))

"""
`edge_connectivity(G,s,t)` determines the minimum size of an edge cut
separating `s` and `t`.
"""
function edge_connectivity(G::SimpleGraph, s, t, verbose::Bool=false)::Int
    has(G,s) || error("$s is not a vertex of this graph")
    has(G,t) || error("$t is not a vertex of this graph")
    s!=t || error("source and sink cannot be the same")

    if length(find_path(G,s,t)) == 0
        return 0
    end

    VV = vlist(G)
    n = NV(G)

    MOD = Model(with_optimizer(_SOLVER.Optimizer; _OPTS...))

    @variable(MOD, x[VV,VV], Bin)  # X[i,j]=1 if unit flow from i to j

    # no flow on a self loop
    for v in VV
        @constraint(MOD,x[v,v]==0)
    end

    # no flow on a non edge
    for u in VV
        for v in VV
            if u!=v && !has(G,u,v)
                @constraint(MOD, x[u,v]==0)
            end
        end
    end

    # don't have flows on both antiparallel edges
    for u in VV
        for v in VV
            if u!=v
                @constraint(MOD,x[u,v]+x[v,u] <= 1)
            end
        end
    end

    # flow in = flow out  everywhere except s,t
    for v in VV
        if v==s || v==t
            continue
        end

        Nv = G[v]
        @constraint(MOD, sum(x[v,w] for w in Nv) == sum(x[w,v] for w in Nv))
    end

    Ns = G[s]
    Nt = G[t]

    @constraint(MOD, sum(x[s,w] for w in Ns) == sum(x[w,t] for w in Nt))

    @objective(MOD, Max, sum(x[s,w] for w in Ns))

    optimize!(MOD)
    status = Int(termination_status(MOD))

    X = value.(x)


    if verbose
        for u in VV
            for v in VV
                if X[u,v] > 0.4
                    println("($u,$v)")
                end
            end
        end
    end

    return Int(objective_value(MOD))

end
