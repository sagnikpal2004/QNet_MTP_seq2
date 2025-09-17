using QuantumSavory
using QuantumSavory.ProtocolZoo

using ConcurrentSim
using ResumableFunctions

include("utils/bellstates.jl")
include("processes/entangle.jl")
include("processes/swapping.jl")

function simulation_setup(q::Int, n::Int; T2::Float64, t_comm, F, success_prob, t_workload)
    network = RegisterNet([Register(q, T2Dephasing(T2)) for _ in 1:2n])
    sim = get_time_tracker(network)

    for i in 1:n
        network.cchannels[2i-1=>2i] = DelayQueue{Tag}(sim, t_comm)
        network.cchannels[2i=>2i-1] = DelayQueue{Tag}(sim, t_comm)
    end

    @process NetworkEntanglerProt(sim, network; success_prob, t_comm, t_workload)()
    for i in 1:n-1
        @process SwapperProt(sim, network, 2i, 2i+1)()
    end
    for i in 1:2n
        @process EntanglementTracker(sim, network, i)()
    end

    return sim, network
end
