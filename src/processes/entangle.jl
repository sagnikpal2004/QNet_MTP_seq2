@kwdef struct MultiplexedEntanglerProt <: QuantumSavory.ProtocolZoo.AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """the vertex index of node A"""
    nodeA::Int
    """the vertex index of node B"""
    nodeB::Int
    """the state being generated (supports symbolic, numeric, noisy, and pure)"""
    pairstate = StabilizerState("ZZ XX")
    """success probability of one attempt of entanglement generation"""
    success_prob::Float64 = 0.001
    """fixed "busy time" duration immediately before starting entanglement generation attempts"""
    local_busy_time_pre::Float64 = 0.0
    """fixed "busy time" duration immediately after the a successful entanglement generation attempt"""
    local_busy_time_post::Float64 = 0.0
end

function MultiplexedEntanglerProt(sim::Simulation, net::RegisterNet, nodeA::Int, nodeB::Int; kwargs...)
    MultiplexedEntanglerProt(; sim, net, nodeA, nodeB, kwargs...)
end

@resumable function (prot::MultiplexedEntanglerProt)()
    num_qubits = min(length(prot.net[prot.nodeA].staterefs), length(prot.net[prot.nodeB].staterefs))
    successful_pairs = Int[]

    for q in 1:num_qubits
        @yield lock(prot.net[prot.nodeA][q])
        @yield lock(prot.net[prot.nodeB][q])
    end
    @yield timeout(prot.sim, prot.local_busy_time_pre)

    for q in 1:num_qubits
        a = prot.net[prot.nodeA][q]
        b = prot.net[prot.nodeB][q]

        if rand() < prot.success_prob
            initialize!((a, b), prot.pairstate)
            push!(successful_pairs, q)
        end
    end

    @yield timeout(prot.sim, prot.local_busy_time_post)

    for q in successful_pairs
        tag!(prot.net[prot.nodeA][q], EntanglementCounterpart, prot.nodeB, q)
        tag!(prot.net[prot.nodeB][q], EntanglementCounterpart, prot.nodeA, q)
    end
    for q in 1:num_qubits
        unlock(prot.net[prot.nodeA][q])
        unlock(prot.net[prot.nodeB][q])
    end
end


@kwdef struct NetworkEntanglerProt <: QuantumSavory.ProtocolZoo.AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """the state being generated (supports symbolic, numeric, noisy, and pure)"""
    pairstate = StabilizerState("ZZ XX")
    """success probability of one attempt of entanglement generation"""
    success_prob::Float64 = 0.001
    """Communication time between nodes"""
    t_comm::Float64 = 0.0
    """Workload time parameter"""
    t_workload::Float64 = 0.0
end

function NetworkEntanglerProt(sim::Simulation, net::RegisterNet; kwargs...)
    return NetworkEntanglerProt(; sim, net, kwargs...)
end

@resumable function (prot::NetworkEntanglerProt)()
    for i in 1:n
        @yield timeout(prot.sim, 3 * prot.t_comm)
        @process MultiplexedEntanglerProt(prot.sim, prot.net, 2i-1, 2i; success_prob=prot.success_prob, pairstate=prot.pairstate, local_busy_time_pre=prot.t_workload + 0.5*prot.t_comm, local_busy_time_post=0.5*prot.t_comm)()
    end
end
