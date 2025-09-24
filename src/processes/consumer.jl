include("../noisyops/CircuitZoo.jl")

@kwdef struct EntanglementPurifyAndConsume <: ProtocolZoo.AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """the vertex index of node A"""
    nodeA::Int
    """the vertex index of node B"""
    nodeB::Int
    """Gate error rate for purification circuit"""
    ϵ_g::Float64
    """Measurement error rate for purification circuit"""
    ξ::Float64
    """stores the time and resulting observable from querying nodeA and nodeB for `EntanglementCounterpart`"""
    log::Vector{Tuple{Float64, Float64, Float64}} = Tuple{Float64, Float64, Float64}[]
end

# function EntanglementPurifyAndConsume(sim::Simulation, net::RegisterNet, nodeA::Int, nodeB::Int; kwargs...)
#     return EntanglementPurifyAndConsume(;sim, net, nodeA, nodeB, kwargs...)
# end

@resumable function (prot::EntanglementPurifyAndConsume)()
    while true
        queries_a = queryall(prot.net[prot.nodeA], EntanglementCounterpart, prot.nodeB, W; locked=false, assigned=true)
        queries_b = queryall(prot.net[prot.nodeB], EntanglementCounterpart, prot.nodeA, W; locked=false, assigned=true)
       
        if length(queries_a) < 2 || length(queries_b) < 2
            @info "EntanglementPurifyAndConsume: Waiting for at least 2 entangled pairs for distillation on nodes $(prot.nodeA) ↔ $(prot.nodeB) (nodeA=$(length(queries_a)), nodeB=$(length(queries_b)))"
            @yield onchange_tag(prot.net[prot.nodeA]) | onchange_tag(prot.net[prot.nodeB])
            continue
        end

        query1_a, query2_a = queries_a[1], queries_a[2]
        query1_b, query2_b = queries_b[1], queries_b[2]

        q1_a, q1_b = query1_a.slot, query1_b.slot
        q2_a, q2_b = query2_a.slot, query2_b.slot
        
        @yield lock(q1_a) & lock(q1_b) & lock(q2_a) & lock(q2_b)

        @debug "EntanglementPurifyAndConsume: Starting DEJMPS purification between $(prot.nodeA) and $(prot.nodeB): pairs ($(q1_a.idx),$(q1_b.idx)) & ($(q2_a.idx),$(q2_b.idx)) @ $(now(prot.sim))"
        uptotime!((q1_a, q1_b, q2_a, q2_b), now(prot.sim))

        purification_circuit = DEJMPSCircuit(prot.ϵ_g, prot.ξ)
        success = purification_circuit(q1_a, q1_b, q2_a, q2_b)
        
        if success
            @debug "EntanglementPurifyAndConsume: DEJMPS purification SUCCEEDED - consuming purified pair"

            ob1 = real(observable((q1_a, q1_b), Z⊗Z))
            ob2 = real(observable((q1_a, q1_b), X⊗X))
            push!(prot.log, (now(prot.sim), ob1, ob2))
        else
            @debug "EntanglementPurifyAndConsume: DEJMPS purification FAILED - all qubits traced out"
        end
        
        traceout!(q1_a, q1_b, q2_a, q2_b)

        untag!(q1_a, query1_a.id)
        untag!(q1_b, query1_b.id)
        untag!(q2_a, query2_a.id)
        untag!(q2_b, query2_b.id)

        unlock(q1_a)
        unlock(q1_b) 
        unlock(q2_a)
        unlock(q2_b)
        
        @debug "EntanglementPurifyAndConsume: Completed DEJMPS purification and consumption @ $(now(prot.sim))"
    end
end