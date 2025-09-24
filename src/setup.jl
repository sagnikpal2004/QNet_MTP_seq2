using QuantumSavory
using QuantumSavory.ProtocolZoo

using ConcurrentSim
using ResumableFunctions

using Graphs
using Distributions

include("utils/bellstates.jl")
include("processes/entangle.jl")
include("processes/swapping.jl")
include("processes/consumer.jl")

function simulation_setup(q::Int, n::Int; T2::Float64, λ::Float64, μ::Float64, t_comm::Float64, F::Float64, success_prob::Float64, q_req::Int=1, t_workload::Float64=1.0, ϵ_g::Float64=0.0, ξ::Float64=0.0)
    network = RegisterNet([Register(q, T2Dephasing(T2)) for _ in 1:2n])
    sim = get_time_tracker(network)

    for i in 1:n
        network.cchannels[2i-1=>2i] = DelayQueue{Tag}(sim, t_comm)
        network.cchannels[2i=>2i-1] = DelayQueue{Tag}(sim, t_comm)
    end
    for v in Graphs.vertices(network.graph)
        channels = [(;src=w, channel=network.cchannels[w=>v]) for w in neighbors(network.graph, v)]
        network.cbuffers[v] = MessageBuffer(network, v, channels)
    end

    pairstate = F * Φ⁺ + (1-F)/3 * (Φ⁻ + Ψ⁺ + Ψ⁻)
    log = Tuple{Float64, Float64, Float64}[]

    @process NetworkEntanglerProt(sim, network; λ, μ, pairstate, success_prob, t_comm)()
    for i in 1:n-1
        @process SwapperProt(sim, network, 2i, 2i+1; ϵ_g, ξ)()
    end
    for i in 1:2n
        @process EntanglementTracker(sim, network, i)()
    end
    # for i in 2:2n-1
    #     @process CutoffProt(sim, network, i, period=nothing, retention_time=6*t_comm)()
    # end
    @process EntanglementPurifyAndConsume(;sim=sim, net=network, nodeA=1, nodeB=2n, log=log, ϵ_g=ϵ_g, ξ=ξ)()

    return sim, network, log
end
