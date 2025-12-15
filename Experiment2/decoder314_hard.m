function decoded_binstream = decoder314_hard(binstream, tailing_mode)
    REPEAT_TIMES = 5; % 咬尾时，重复译码次数

    % 预处理
    binstream = binstream(:).'; % 确保是行向量
    L = length(binstream)/3; % (3,1,4) 码率，每次处理3比特

    if tailing_mode ~= 2 % 非咬尾 (Mode 0 & Mode 1)
        % 状态转移
        [state, edge] = state_transform();
        pre_state = zeros(L, 8); % 记录从哪一个状态转移过来的
        min_dh = zeros(L, 8);    % 记录目前的最小汉明距离
        
        % DP
        for i = 1:L 
            if i == 1
                % 【修正1】初始化度量矩阵 pre_dh，而非路径矩阵 pre_state
                % 初始时刻必须从 State 1 (000) 出发
                pre_dh = inf(1, 8);
                pre_dh(1) = 0;
            else
                pre_dh = min_dh(i-1, :); % 上一轮的汉明距离
            end
            
            for j = 1:8 % 遍历得到两个bit后的状态
                out1 = state(j, 1:3);
                in1 = state(j, 4);
                ps1 = state(j, 5);
                out2 = state(j, 6:8);
                in2 = state(j, 9);
                ps2 = state(j, 10);
                
                dh1 = sum(binstream(i*3-2:i*3) ~= out1);
                dh2 = sum(binstream(i*3-2:i*3) ~= out2);
                
                if tailing_mode == 1 && L - i < 3
                    if in1 == 1
                        dh1 = inf; % 收尾时，不能输入1
                    end
                    if in2 == 1
                        dh2 = inf; % 收尾时，不能输入1
                    end
                end
                
                if dh1 + pre_dh(ps1) < dh2 + pre_dh(ps2)
                    min_dh(i, j) = dh1 + pre_dh(ps1);
                    pre_state(i, j) = ps1; % 记录前序状态
                else
                    min_dh(i, j) = dh2 + pre_dh(ps2);
                    pre_state(i, j) = ps2; % 记录前序状态
                end
            end
        end
        
        % 【修正2】Mode 1 强制回溯起点
        if tailing_mode == 1
            min_state = 1; % Zero Tailing 必然结束于 State 1
        else
            [~, min_state] = min(min_dh(end, :));
        end
        
        % 从后往前扫，得到重建比特
        decoded_binstream = zeros(1, L);
        for i = L:-1:1
            decoded_binstream(i) = edge(pre_state(i, min_state), min_state);
            min_state = pre_state(i, min_state);
        end
        
        % 收尾处理
        if tailing_mode == 1
            decoded_binstream = decoded_binstream(1:end-3); % 收尾
        end

    else % 咬尾 (Mode 2)
        % 重复多次迭代译码
        binstream = repmat(binstream, 1, REPEAT_TIMES);
        % 状态转移
        [state, edge] = state_transform();
        pre_state = zeros(L*REPEAT_TIMES, 8); % 记录从哪一个状态转移过来的
        min_dh = zeros(L*REPEAT_TIMES, 8);    % 记录目前的最小汉明距离
        
        % DP
        for i = 1:L*REPEAT_TIMES
            if i == 1
                % 【修正3】咬尾模式初始状态等概，移除了错误的 pre_state 赋值
                pre_dh = zeros(1, 8); 
            else
                pre_dh = min_dh(i-1, :); % 上一轮的汉明距离
            end
            
            for j = 1:8 % 遍历得到两个bit后的状态
                out1 = state(j, 1:3);
                ps1 = state(j, 5);
                out2 = state(j, 6:8);
                ps2 = state(j, 10);
                
                dh1 = sum(binstream(i*3-2:i*3) ~= out1);
                dh2 = sum(binstream(i*3-2:i*3) ~= out2);
                
                if dh1 + pre_dh(ps1) < dh2 + pre_dh(ps2)
                    min_dh(i, j) = dh1 + pre_dh(ps1);
                    pre_state(i, j) = ps1; % 记录前序状态
                else
                    min_dh(i, j) = dh2 + pre_dh(ps2);
                    pre_state(i, j) = ps2; % 记录前序状态
                end
            end
        end
        
        % 选最小的
        [~, min_state] = min(min_dh(end, :));
        
        % 从后往前扫，得到重建比特
        decoded_binstream = zeros(1, L);
        for i = L*REPEAT_TIMES:-1:L*(REPEAT_TIMES-1)+1
            decoded_binstream(i-L*(REPEAT_TIMES-1)) = edge(pre_state(i, min_state), min_state);
            min_state = pre_state(i, min_state);
        end
    end
end


function [state, edge] = state_transform()
    % 网格图保持不变，你的配置是正确的
    state = [ ...
        0 0 0 0 1, 1 1 1 0 2; ...
        1 0 1 0 3, 0 1 0 0 4; ...
        0 1 1 0 5, 1 0 0 0 6; ...
        1 1 0 0 7, 0 0 1 0 8; ...
        1 1 1 1 1, 0 0 0 1 2; ...
        0 1 0 1 3, 1 0 1 1 4; ...
        1 0 0 1 5, 0 1 1 1 6; ...
        0 0 1 1 7, 1 1 0 1 8 ...
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
