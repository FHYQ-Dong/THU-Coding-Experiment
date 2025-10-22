function [bit_stream_out, H_estimated] = sym2bit(V, M, use_pilot, pilot_config)
    % sym2bit 实现带信道估计的相干解调
    %
    % 语法:
    %   bit_stream_out = sym2bit(V, M, use_pilot, pilot_config)
    %
    % 输入:
    %   V             - (L_total x 1) 接收到的完整符号序列
    %   M             - (scalar) 每个符号的比特数 (1, 2, 或 3)
    %   use_pilot     - (logical) 是否使用导频 (true/false)
    %   pilot_config  - (struct) 导频配置 (必须与发送端一致)
    %     .interval   - (scalar) 导频间隔
    %     .symbol     - (scalar) 导频符号
    %
    % 输出:
    %   bit_stream_out - (B x 1) 判决恢复的比特流

    %% -----  获取星座图和基本参数  -----
    [C, B] = constellation_map(M); % C: 1x2^M, B: Mx2^M
    L_total = length(V);

    if use_pilot
        interval = pilot_config.interval;
        pilot_sym = pilot_config.symbol;

        %% -----  生成掩码并提取导频 (LS 估计)  -----
        % 接收端必须重新生成与发送端完全一致的掩码
        pilot_indices = 1:interval:L_total;
        is_data_mask = true(L_total, 1);
        is_data_mask(pilot_indices) = false;
        % 提取接收到的导频
        V_pilots = V(pilot_indices);

        %% -----  插值估计 h_i  -----
        % 最小二乘 (LS) 估计: h_ls = v_p / u_p
        H_ls_at_pilots = V_pilots / pilot_sym;
        H_estimated = interp1(pilot_indices', H_ls_at_pilots, (1:L_total)', 'linear', 'extrap');
    else
        H_estimated = ones(L_total, 1); % 不使用导频时，假设信道为全1
        is_data_mask = true(L_total, 1); % 全为数据符号
    end

    %% -----  逐符号进行相干 ML 判决  -----
    B_out_matrix = zeros(M, L_total);
    for i = 1:L_total
        v_i = V(i);
        h_i_est = H_estimated(i);
        possible_rx_points = h_i_est * C;
        distances_sq = abs(v_i - possible_rx_points).^2;
        [~, min_idx] = min(distances_sq);
        B_out_matrix(:, i) = B(:, min_idx);
    end

    %% -----  提取数据比特 -----
    % 我们只关心 'is_data_mask' 为 true 的列
    B_data_matrix = B_out_matrix(:, is_data_mask);
    % 将 M x L_data 矩阵重塑为 B x 1 的比特流
    bit_stream_out = B_data_matrix(:);

end
