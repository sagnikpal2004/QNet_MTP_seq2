using QuantumSavory.CircuitZoo

include("./apply.jl")
include("./traceout.jl")
include("../baseops/RGate.jl")

struct NoisyLocalEntanglementSwap <: CircuitZoo.AbstractCircuit
    ϵ_g::Float64
    ξ::Float64

    function NoisyLocalEntanglementSwap(ϵ_g::Float64, ξ::Float64)
        @assert 0 <= ϵ_g <= 1   "ϵ_g must be in [0, 1]"
        @assert 0 <=  ξ  <= 1   "ξ must be in [0, 1]"

        new(ϵ_g, ξ)
    end
end
function (circuit::NoisyLocalEntanglementSwap)(localL, localR)
    apply_noisy!((localL, localR), CNOT; ϵ_g=circuit.ϵ_g)
    xmeas = project_traceout!(localL, σˣ; ξ=circuit.ξ)
    zmeas = project_traceout!(localR, σᶻ; ξ=circuit.ξ)
    xmeas, zmeas
end
inputqubits(::NoisyLocalEntanglementSwap) = 2


struct DEJMPSCircuit <: CircuitZoo.AbstractCircuit
    ϵ_g::Float64
    ξ::Float64

    function DEJMPSCircuit(ϵ_g::Float64, ξ::Float64)
        @assert 0 <= ϵ_g <= 1   "ϵ_g must be in [0, 1]"
        @assert 0 <=  ξ  <= 1   "ξ must be in [0, 1]"

        new(ϵ_g, ξ)
    end
end
function (circuit::DEJMPSCircuit)(purifiedL, purifiedR, sacrificedL, sacrificedR)
    apply!(purifiedL, Rx(π/2))
    apply!(sacrificedL, Rx(π/2))
    apply!(purifiedR, Rx(-π/2))
    apply!(sacrificedR, Rx(-π/2))

    apply_noisy!([purifiedL, sacrificedL], CNOT; ϵ_g=circuit.ϵ_g)
    apply_noisy!([purifiedR, sacrificedR], CNOT; ϵ_g=circuit.ϵ_g)

    measa = project_traceout!(sacrificedL, σᶻ; ξ=circuit.ξ)
    measb = project_traceout!(sacrificedR, σᶻ; ξ=circuit.ξ)

    success = measa == measb
    if !success
        traceout!(purifiedL)
        traceout!(purifiedR)
    end
    return success
end
inputqubits(::DEJMPSCircuit) = 4