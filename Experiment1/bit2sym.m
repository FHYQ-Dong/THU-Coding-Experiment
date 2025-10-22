function [U, is_data_mask] = bit2sym(bit_stream_in, M, use_pilot, pilot_config)
    % bit2sym 实现“比特串-电平映射”并（可选）插入导频
    %
    % 语法:
    %   [U, is_data_mask] = bit2sym(bit_stream_in, M, use_pilot, pilot_config)
    %
    % 输入:
    %   bit_stream_in - (B x 1) 输入的二元比特流 (0和1)
    %   M             - (scalar) 每个符号的比特数 (1, 2, 或 3)
    %   use_pilot     - (logical) 是否插入导频 (true/false)
    %   pilot_config  - (struct) 导频配置，如果 use_pilot 为 true，则需要提供
    %     .interval   - (scalar) 导频间隔 (例如 10, 表示 1个导频, 9个数据)
    %     .symbol     - (scalar) 导频符号 (例如 1+0j)
    %
    % 输出:
    %   U             - (L_total x 1) 复数电平符号序列 (混合了数据和导频)
    %   is_data_mask  - (L_total x 1) 逻辑掩码 (true 为数据, false 为导频)

    %% -----  输入参数检查  -----
    B_total = length(bit_stream_in);
    if mod(B_total, M) ~= 0
        error('总比特数 %d 必须是 M=%d 的整数倍。', B_total, M);
    end
    L_data = B_total / M; % 数据符号的总数

    %% -----  获取星座图和比特映射  -----
    [C, B] = constellation_map(M); % C: 1x2^M, B: Mx2^M

    %% -----  bit 2 data symbols  -----
    B_matrix = reshape(bit_stream_in, M, L_data);
    U_data = complex(zeros(L_data, 1));
    for i = 1:L_data
        current_bits = B_matrix(:, i);
        [~, col_index] = ismember(current_bits', B', 'rows');
        if col_index == 0
            warning('比特组合未在星座图中找到，索引 %d', i);
            U_data(i) = C(1);
        else
            U_data(i) = C(col_index);
        end
    end

    %% -----  插入导频  -----
    if ~use_pilot
        U = U_data;
        is_data_mask = true(L_data, 1);
    else
        L_total = L_data + ceil(L_data / (pilot_config.interval - 1));
        U = complex(zeros(L_total, 1));
        is_data_mask = true(L_total, 1);
        is_data_mask(1:pilot_config.interval:L_total) = false;
        U(is_data_mask) = U_data;
        U(~is_data_mask) = pilot_config.symbol;
    end

end
