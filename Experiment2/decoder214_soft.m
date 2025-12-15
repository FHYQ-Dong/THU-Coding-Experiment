function decoded_binstream = decoder214_soft(llrstream, tailing_mode)
    REPEAT_TIMES = 5; % 咬尾时，重复译码次数

    % 预处理
    llrstream = llrstream(:).'; % 确保是行向量
    L = length(llrstream)/2;

    if tailing_mode ~= 2 % 非咬尾 (Mode 0: Direct Truncation, Mode 1: Zero Tailing)
        % 状态转移
        [state, edge] = state_transform();
        pre_state = zeros(L, 8); % 记录从哪一个状态转移过来的
        max_llr = zeros(L, 8);   % 记录目前的最大llr
        
        % DP
        for i = 1:L 
            if i == 1
                % 【修正1】初始状态必须是全0状态 (State 1)
                % 其他状态的初始概率为0 (对数域为 -inf)
                pre_llr = -inf(1, 8);
                pre_llr(1) = 0; 
            else
                pre_llr = max_llr(i-1, :); % 上一轮的llr
            end
            
            for j = 1:8 % 遍历得到两个bit后的状态
                out1 = state(j, 1:2);
                in1 = state(j, 3);
                ps1 = state(j, 4);
                out2 = state(j, 5:6);
                in2 = state(j, 7);
                ps2 = state(j, 8);
                
                llr1 = llrstream(i*2-1:i*2) * out1.';
                llr2 = llrstream(i*2-1:i*2) * out2.';
                
                if tailing_mode == 1 && L - i < 3
                    if in1 == 1
                        llr1 = -inf; % 收尾时，不能输入1
                    end
                    if in2 == 1
                        llr2 = -inf; % 收尾时，不能输入1
                    end
                end
                
                if llr1 + pre_llr(ps1) > llr2 + pre_llr(ps2)
                    max_llr(i, j) = llr1 + pre_llr(ps1);
                    pre_state(i, j) = ps1; % 记录前序状态
                else
                    max_llr(i, j) = llr2 + pre_llr(ps2);
                    pre_state(i, j) = ps2; % 记录前序状态
                end
            end
        end
        
        % 【修正2】确定回溯起点
        if tailing_mode == 1
            % 收尾模式下，编码器被强制归零，因此必须从 State 1 (000) 开始回溯
            max_state = 1;
        else
            % 直接截断模式下，选择度量最大的状态
            [~, max_state] = max(max_llr(end, :));
        end
        
        % 从后往前扫，得到重建比特
        decoded_binstream = zeros(1, L);
        for i = L:-1:1
            decoded_binstream(i) = edge(pre_state(i, max_state), max_state);
            max_state = pre_state(i, max_state);
        end
        
        % 收尾处理
        if tailing_mode == 1
            decoded_binstream = decoded_binstream(1:end-3); % 收尾
        end

    else % 咬尾 (Mode 2: Tail-biting)
        % 重复多次迭代译码
        llrstream = repmat(llrstream, 1, REPEAT_TIMES);
        % 状态转移
        [state, edge] = state_transform();
        pre_state = zeros(L*REPEAT_TIMES, 8); % 记录从哪一个状态转移过来的
        max_llr = zeros(L*REPEAT_TIMES, 8);   % 记录目前的最大llr
        
        % DP
        for i = 1:L*REPEAT_TIMES 
            if i == 1
                % 【修正3】咬尾模式起始状态未知，假设所有状态等概
                pre_llr = zeros(1, 8); 
                % 移除了原代码中无意义的 pre_state(1, 2:8) = -inf
            else
                pre_llr = max_llr(i-1, :); % 上一轮的llr
            end
            
            for j = 1:8 % 遍历得到两个bit后的状态
                out1 = state(j, 1:2);
                ps1 = state(j, 4);
                out2 = state(j, 5:6);
                ps2 = state(j, 8);
                
                llr1 = llrstream(i*2-1:i*2) * out1.';
                llr2 = llrstream(i*2-1:i*2) * out2.';
                
                if llr1 + pre_llr(ps1) > llr2 + pre_llr(ps2)
                    max_llr(i, j) = llr1 + pre_llr(ps1);
                    pre_state(i, j) = ps1; % 记录前序状态
                else
                    max_llr(i, j) = llr2 + pre_llr(ps2);
                    pre_state(i, j) = ps2; % 记录前序状态
                end
            end
        end
        
        % 选最大的
        [~, max_state] = max(max_llr(end, :));
        
        % 从后往前扫，得到重建比特
        decoded_binstream = zeros(1, L);
        for i = L*REPEAT_TIMES:-1:L*(REPEAT_TIMES-1)+1
            decoded_binstream(i-L*(REPEAT_TIMES-1)) = edge(pre_state(i, max_state), max_state);
            max_state = pre_state(i, max_state);
        end
    end
end


function [state, edge] = state_transform()
    % 网格图保持不变
    state = [ ...
        -1 -1  0  1,   1  1  0  2; ...
        -1  1  0  3,   1 -1  0  4; ...
         1  1  0  5,  -1 -1  0  6; ...
         1 -1  0  7,  -1  1  0  8; ...
         1  1  1  1,  -1 -1  1  2; ...
         1 -1  1  3,  -1  1  1  4; ...
        -1 -1  1  5,   1  1  1  6; ...
        -1  1  1  7,   1 -1  1  8 ...
    ]; 
    edge = zeros(8, 8); 
    edge(1, 1) = 0; edge(1, 5) = 1;
    edge(2, 1) = 0; edge(2, 5) = 1;
    edge(3, 2) = 0; edge(3, 6) = 1;
    edge(4, 2) = 0; edge(4, 6) = 1;
    edge(5, 3) = 0; edge(5, 7) = 1;
    edge(6, 3) = 0; edge(6, 7) = 1;
    edge(7, 4) = 0; edge(7, 8) = 1;
    edge(8, 4) = 0; edge(8, 8) = 1;
end
