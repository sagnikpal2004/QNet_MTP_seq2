@kwdef struct MultiplexedEntanglerProt <: QuantumSavory.ProtocolZoo.AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """service rate (per second)"""
    μ::Float64 = 1.0
    """number of qubits to attempt to entangle"""
    num_qubits::Int = 1
    """the state being generated (supports symbolic, numeric, noisy, and pure)"""
    pairstate = StabilizerState("ZZ XX")
    """success probability of one attempt of entanglement generation"""
    success_prob::Float64 = 0.001
    """fixed "busy time" duration immediately before starting entanglement generation attempts"""
    local_busy_time_pre::Float64 = 0.0
    """fixed "busy time" duration immediately after the a successful entanglement generation attempt"""
    local_busy_time_post::Float64 = 0.0
    """communication time between nodes"""
    t_comm::Float64 = 0.0
end

function MultiplexedEntanglerProt(sim::Simulation, net::RegisterNet; kwargs...)
    MultiplexedEntanglerProt(; sim, net, kwargs...)
end

@resumable function (prot::MultiplexedEntanglerProt)(nodeA::Int, nodeB::Int)
    @info "MultiplexedEntanglerProt: Starting for nodes $nodeA ↔ $nodeB at time $(now(prot.sim))"
    
    if nodeB > length(prot.net.registers)
        @info "MultiplexedEntanglerProt: nodeB=$nodeB > network size, returning"
        return
    end
    
    @yield timeout(prot.sim, 3*prot.t_comm)
    @process prot(nodeA+2, nodeB+2)

    @info "MultiplexedEntanglerProt: Looking for $(prot.num_qubits) free slots on nodes $nodeA ↔ $nodeB"
    left_slots, right_slots = nothing, nothing
    while true
        left_slots = findfreeslots(prot.net[nodeA], prot.num_qubits)
        right_slots = findfreeslots(prot.net[nodeB], prot.num_qubits)

        if !isnothing(left_slots) && !isnothing(right_slots)
            @info "MultiplexedEntanglerProt: Found free slots on both nodes $nodeA ↔ $nodeB"
            break
        end
        @info "MultiplexedEntanglerProt: Waiting for free slots on nodes $nodeA ↔ $nodeB (left=$(isnothing(left_slots) ? "busy" : "free"), right=$(isnothing(right_slots) ? "busy" : "free"))"
        @yield onchange_tag(prot.net[nodeA]) | onchange_tag(prot.net[nodeB])
    end

    for q in 1:prot.num_qubits
        @yield lock(left_slots[q])
        @yield lock(right_slots[q])
    end
    @yield timeout(prot.sim, rand(Exponential(prot.μ)) + 0.5 * prot.t_comm)
    
    successful_pairs = Tuple{RegRef, RegRef}[]
    for q in 1:prot.num_qubits
        a = left_slots[q]
        b = right_slots[q]

        if rand() < prot.success_prob
            initialize!((a, b), prot.pairstate)
            push!(successful_pairs, (a, b))
        end
    end

    @yield timeout(prot.sim, 0.5 * prot.t_comm)

    for (a, b) in successful_pairs
        # Tag with proper remote node and slot indices
        # a is on nodeA, entangled with b on nodeB at slot b.idx
        tag!(a, EntanglementCounterpart, nodeB, b.idx)
        # b is on nodeB, entangled with a on nodeA at slot a.idx  
        tag!(b, EntanglementCounterpart, nodeA, a.idx)
        
        @info "EntangleProt: Tagged $(nodeA):$(a.idx) ↔ $(nodeB):$(b.idx) at time $(now(prot.sim))"
    end
    for q in 1:prot.num_qubits
        unlock(left_slots[q])
        unlock(right_slots[q])
    end
end

function findfreeslots(reg::Register, num_qubits::Int)
    n_slots = length(reg.staterefs)
    freeslots = [i for i in 1:n_slots if !islocked(reg[i]) && !isassigned(reg[i])]
    if length(freeslots) < num_qubits
        return nothing
    end
    return reg[freeslots[1:num_qubits]]
end


@kwdef struct NetworkEntanglerProt <: QuantumSavory.ProtocolZoo.AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """Poisson distribution rate of requests (per second)"""
    λ::Float64 = 1.0
    """Exponential distribution service rate (per second)"""
    μ::Float64 = 1.0
    """the state being generated (supports symbolic, numeric, noisy, and pure)"""
    pairstate = StabilizerState("ZZ XX")
    """success probability of one attempt of entanglement generation"""
    success_prob::Float64 = 0.001
    """Communication time between nodes"""
    t_comm::Float64 = 0.0
end

function NetworkEntanglerProt(sim::Simulation, net::RegisterNet; kwargs...)
    return NetworkEntanglerProt(; sim, net, kwargs...)
end

@resumable function (prot::NetworkEntanglerProt)()
    eprot = MultiplexedEntanglerProt(prot.sim, prot.net;
        num_qubits = 16,
        pairstate = prot.pairstate,
        success_prob = prot.success_prob,
        μ = prot.μ,
        t_comm = prot.t_comm
    )

    while true
        @yield timeout(prot.sim, rand(Exponential(prot.λ)))
        @info "Entanglement request initiated at $(now(prot.sim))"

        @process eprot(1, 2)
    end
end
