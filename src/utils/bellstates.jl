using QuantumOptics

b = SpinBasis(1/2) ⊗ SpinBasis(1/2)
Φ⁺ = dm(Ket(b, [1, 0, 0, 1]/√2))
Φ⁻ = dm(Ket(b, [1, 0, 0, -1]/√2))
Ψ⁺ = dm(Ket(b, [0, 1, 1, 0]/√2))
Ψ⁻ = dm(Ket(b, [0, 1, -1, 0]/√2))