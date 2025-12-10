% (3,1,4)卷积码译码（软判决）
% 输入：待译码消息的对数似然比llrstream，收尾方式tailing_mode（0不收尾，1收尾，2咬尾）
% 输出：译码后的消息decoded_binstream
function decoded_binstream = decoder314_soft(llrstream, tailing_mode)
    REPEAT_TIMES = 5; % 咬尾时，重复译码次数

    % 预处理
    llrstream = llrstream(:).'; % 确保是行向量
    L = length(llrstream)/3;

    if tailing_mode ~= 2 % 非咬尾
        % 状态转移
        [state, edge] = state_transform();
        pre_state = zeros(L, 8); % 记录从哪一个状态转移过来的
        max_llr = zeros(L, 8); % 记录目前的最大llr
        % DP
        for i = 1:L 
            if i == 1
                pre_llr = zeros(1, 8);
                pre_state(1, 2:8) = -inf; % 初始状态的llr
            else
                pre_llr = max_llr(i-1, :); % 上一轮的llr
            end
            for j = 1:8 % 遍历得到两个bit后的状态
                out1 = state(j, 1:3);
                in1 = state(j, 4);
                ps1 = state(j, 5);
                out2 = state(j, 6:8);
                in2 = state(j, 9);
                ps2 = state(j, 10);
                llr1 = llrstream(i*3-2:i*3) * out1.';
                llr2 = llrstream(i*3-2:i*3) * out2.';
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
        % 选最大的
        [~, max_state] = max(max_llr(end, :));
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

    else % 咬尾
        % 重复多次迭代译码
        llrstream = repmat(llrstream, 1, REPEAT_TIMES);
        % 状态转移
        [state, edge] = state_transform();
        pre_state = zeros(L*REPEAT_TIMES, 8); % 记录从哪一个状态转移过来的
        max_llr = zeros(L*REPEAT_TIMES, 8); % 记录目前的最大llr
        % DP
        for i = 1:L*REPEAT_TIMES
            if i == 1
                pre_llr = zeros(1, 8);
                pre_state(1, 2:8) = -inf; % 初始状态的llr
            else
                pre_llr = max_llr(i-1, :); % 上一轮的llr
            end
            for j = 1:8 % 遍历得到两个bit后的状态
                out1 = state(j, 1:3);
                ps1 = state(j, 5);
                out2 = state(j, 6:8);
                ps2 = state(j, 10);
                llr1 = llrstream(i*3-2:i*3) * out1.';
                llr2 = llrstream(i*3-2:i*3) * out2.';
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
    % 网格图
    % id:     state:  out0:   ns0:    out1:   ns1:
    % ----------------------------------------------
    % 1       000     000     000     111     100
    % 2       001     111     000     000     100
    % 3       010     101     001     010     101
    % 4       011     010     001     101     101
    % 5       100     011     010     100     110
    % 6       101     100     010     011     110
    % 7       110     110     011     001     111
    % 8       111     001     011     110     111
    % ----------------------------------------------
    state = [ ...
        -1 -1 -1  0  1,  1  1  1  0  2; ...
         1 -1  1  0  3, -1  1 -1  0  4; ...
        -1  1  1  0  5,  1 -1 -1  0  6; ...
         1  1 -1  0  7, -1 -1  1  0  8; ...
         1  1  1  1  1, -1 -1 -1  1  2; ...
        -1  1 -1  1  3,  1 -1  1  1  4; ...
         1 -1 -1  1  5, -1  1  1  1  6; ...
        -1 -1  1  1  7,  1  1 -1  1  8 ...
    ]; % 这个状态可以从那些状态转移过来。行：当前状态，列：[out1, in1, ps1, out2, in2, ps2]
    % 状态转移时的输入/输出
    edge = zeros(8, 8); % (前序状态, 当前状态)
    edge(1, 1) = 0;
    edge(1, 5) = 1;
    edge(2, 1) = 0;
    edge(2, 5) = 1;
    edge(3, 2) = 0;
    edge(3, 6) = 1;
    edge(4, 2) = 0;
    edge(4, 6) = 1;
    edge(5, 3) = 0;
    edge(5, 7) = 1;
    edge(6, 3) = 0;
    edge(6, 7) = 1;
    edge(7, 4) = 0;
    edge(7, 8) = 1;
    edge(8, 4) = 0;
    edge(8, 8) = 1;
end
