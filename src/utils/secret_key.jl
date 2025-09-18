function r_secure(Q_x::Float64, Q_z::Float64)
    @assert 0 <= Q_x <= 1 "Q_x must be in [0, 1]"
    @assert 0 <= Q_z <= 1 "Q_z must be in [0, 1]"
    
    h_x = (-Q_x * log2(Q_x)) - ((1 - Q_x) * log2(1 - Q_x)); h_x = isnan(h_x) ? -Inf : h_x
    h_y = (-Q_z * log2(Q_z)) - ((1 - Q_z) * log2(1 - Q_z)); h_y = isnan(h_y) ? -Inf : h_y

    return max(1 - h_x - h_y, 0)
end