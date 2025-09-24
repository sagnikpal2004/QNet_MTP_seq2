include("../src/setup.jl")

L = 10^4            # Total network distance in km    
η_c = 1.0           # Coupling coefficient
ϵ_g = 0.0001        # Gate error rate
n = 4               # Number of segments

q = 64              # Number of qubits per interface
q_req = 16          # Number of qubits requested per request
T2 = 1.0            # T2 dephasing time in seconds

c = 2e5             # Speed of light in km/s
l_att = 20          # Attenuation length in km

l0 = L / n          # Internode distance in km
success_prob = 0.25 # 0.5 * η_c^2 * exp(-l0 / l_att)  # Entanglement generation probability
ξ = 0.25ϵ_g         # Measurement error rate
F = 1 - 1.25ϵ_g     # Initial bellpair fidelity

t_comm = 0.1 #l0 / c     # internode communication time
λ = 5.0             # Average rate of requests per second 
μ = 0.1             # Average rate of service per second

sim, network, results = simulation_setup(q, n; T2, λ, μ, t_comm, F, success_prob, q_req)

using GLMakie
fig = Figure()
coords = [Point2f(i÷2*10+i%2, 1) for i in 1:2n]
_, ax, _, obs = registernetplot_axis(fig[1,1], network, registercoords=coords)
ax.aspect = MathConstants.golden


record(fig, "media/1_visualize.mp4", 0:0.1:100; framerate=10, visible=false) do t
    run(sim, t)
    ax.title = "Time: $t"
    notify(obs)
end

for res in results
    println(res)
end