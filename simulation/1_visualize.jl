include("../src/setup.jl")

L = 10^4                # Total network distance in km    
η_c = 1.0           # Coupling coefficient
ϵ_g = 0.0001        # Gate error rate
n = 4               # Number of segments

q = 32              # Number of qubits per interface
T2 = 1.0            # T2 dephasing time in seconds

c = 2e5             # Speed of light in km/s
l_att = 20          # Attenuation length in km

l0 = L / n          # Internode distance in km
success_prob = 0.25 # 0.5 * η_c^2 * exp(-l0 / l_att)  # Entanglement generation probability
ξ = 0.25ϵ_g         # Measurement error rate
F = 1 - 1.25ϵ_g     # Initial bellpair fidelity

t_comm = 0.333 #l0 / c
t_workload = 1.0

sim, network = simulation_setup(q, n; T2, t_comm, F, success_prob, t_workload)

using WGLMakie
fig = Figure()
coords = [Point2f(i÷2*10+i%2, 1) for i in 1:2n]
_, ax, _, obs = registernetplot_axis(fig[1,1], network, registercoords=coords)


record(fig, "media/1_visualize.mp4", 0:0.1:10; framerate=10, visible=false) do t
    run(sim, t)
    ax.title = "Time: $t"
    notify(obs)
end
