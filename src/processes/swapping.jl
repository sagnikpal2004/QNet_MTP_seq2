import QuantumSavory.CircuitZoo: LocalEntanglementSwap

@kwdef struct SwapperProt <: QuantumSavory.ProtocolZoo.AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
     """the vertex index of node A"""
    nodeA::Int
    """the vertex index of node B"""
    nodeB::Int
end

# function SwapperProt(sim::Simulation, net::RegisterNet, nodeA::Int, nodeB::Int; kwargs...)
#     SwapperProt(; sim, net, nodeA, nodeB, kwargs...)
# end

@resumable function (prot::SwapperProt)()
    while true
        qubit_pair = findswappablequbits(prot.net, prot.nodeA, prot.nodeB)
        if isnothing(qubit_pair)
            @debug "SwapperProt: no swappable qubits found. Waiting for tag change..."
            @yield onchange_tag(prot.net[prot.nodeA]) | onchange_tag(prot.net[prot.nodeB])
            continue
        end

        (q1, id1, tag1) = qubit_pair[1].slot, qubit_pair[1].id, qubit_pair[1].tag
        (q2, id2, tag2) = qubit_pair[2].slot, qubit_pair[2].id, qubit_pair[2].tag

        @yield lock(q1) & lock(q2)
        untag!(q1, id1)
        # store a history of whom we were entangled to: remote_node_idx, remote_slot_idx, remote_swapnode_idx, remote_swapslot_idx, local_swap_idx
        tag!(q1, EntanglementHistory, tag1[2], tag1[3], tag2[2], tag2[3], q2.idx)

        untag!(q2, id2)
        # store a history of whom we were entangled to: remote_node_idx, remote_slot_idx, remote_swapnode_idx, remote_swapslot_idx, local_swap_idx
        tag!(q2, EntanglementHistory, tag2[2], tag2[3], tag1[2], tag1[3], q1.idx)

        uptotime!((q1, q2), now(prot.sim))
        swapcircuit = LocalEntanglementSwap()
        xmeas, zmeas = swapcircuit(q1, q2)

        # send from here to new entanglement counterpart:
        # tag with EntanglementUpdateX past_local_node, past_local_slot_idx past_remote_slot_idx new_remote_node, new_remote_slot, correction
        msg1 = Tag(EntanglementUpdateX, prot.nodeA, q1.idx, tag1[3], tag2[2], tag2[3], Int(xmeas))
        put!(channel(prot.net, prot.nodeA=>tag1[2]; permit_forward=true), msg1)
        @debug "SwapperProt @$(prot.nodeA): Send message to $(tag1[2]) | message=`$msg1` | time = $(now(prot.sim))"

        # send from here to new entanglement counterpart:
        # tag with EntanglementUpdateZ past_local_node, past_local_slot_idx past_remote_slot_idx new_remote_node, new_remote_slot, correction
        msg2 = Tag(EntanglementUpdateZ, prot.nodeB, q2.idx, tag2[3], tag1[2], tag1[3], Int(zmeas))
        put!(channel(prot.net, prot.nodeB=>tag2[2]; permit_forward=true), msg2)
        @debug "SwapperProt @$(prot.nodeB): Send message to $(tag2[2]) | message=`$msg2` | time = $(now(prot.sim))"

        unlock(q1)
        unlock(q2)
    end
end

function findswappablequbits(net, nodeA, nodeB)
    low_nodes = queryall(net[nodeA], EntanglementCounterpart, W, W; locked=false, assigned=true)
    high_nodes = queryall(net[nodeB], EntanglementCounterpart, W, W; locked=false, assigned=true)

    (isempty(low_nodes) || isempty(high_nodes)) && return nothing
    return low_nodes[1], high_nodes[1]
end
