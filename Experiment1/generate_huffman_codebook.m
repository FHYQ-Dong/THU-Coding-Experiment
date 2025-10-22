function [codebook, excluded_symbols] = generate_huffman_codebook(symbols, probabilities, symbol_type)
% GENERATE_HUFFMAN_CODEBOOK 生成霍夫曼码本（含逃逸符号，有一定忽略）
%   新增输出: excluded_symbols - 被排除的低概率符号（仅在双符号模式下非空）

    % 参数验证（略，保持原样）
    if nargin ~= 3
        error('需要三个输入参数: symbols, probabilities, symbol_type');
    end
    if length(symbols) ~= length(probabilities)
        error('符号数量和概率数量必须相等');
    end
    if abs(sum(probabilities) - 1) > 1e-10
        warning('概率总和不为1，正在自动归一化');
        probabilities = probabilities / sum(probabilities);
    end
    if any(probabilities <= 0)
        error('所有概率必须为正数');
    end
    
    escape_symbol = 'ESCAPE';
    excluded_symbols = []; % 默认为空

    if strcmp(symbol_type, 'single')
        % 单符号：保留原逻辑（可选是否加逃逸）
        escape_prob = 1e-10;
        symbols = [symbols; escape_symbol];
        probabilities = [probabilities, escape_prob];
        probabilities = probabilities / sum(probabilities);
        
    elseif strcmp(symbol_type, 'double')
        % === 双符号：启用逃逸机制（排除低概率符号）===
        prob_threshold = 1e-4; % 可调参数
        
        % 找出低概率符号
        low_prob_idx = probabilities < prob_threshold;
        high_prob_idx = ~low_prob_idx;
        
        high_symbols = symbols(high_prob_idx);
        high_probs = probabilities(high_prob_idx);
        excluded_symbols = symbols(low_prob_idx); % 返回给调用者
        
        % 逃逸符号的概率 = 所有被排除符号的概率之和 + 小量（避免为0）
        escape_prob = sum(probabilities(low_prob_idx)) + 1e-10;
        
        % 如果所有符号都被排除（极端情况），至少保留一个
        if isempty(high_symbols)
            warning('所有符号概率均低于阈值，保留概率最高的一个');
            [~, max_idx] = max(probabilities);
            high_symbols = symbols(max_idx);
            high_probs = probabilities(max_idx);
            escape_prob = 1 - high_probs + 1e-10;
        end
        
        % 将逃逸符号加入高频集合
        symbols = [high_symbols; escape_symbol];
        probabilities = [high_probs, escape_prob];
        
        % 重新归一化（重要！）
        probabilities = probabilities / sum(probabilities);
        
    else
        error('symbol_type 必须是 ''single'' 或 ''double''');
    end

    % === 构建霍夫曼树（通用逻辑）===
    nodes = struct();
    for i = 1:length(symbols)
        nodes(i).symbol = symbols(i);
        nodes(i).probability = probabilities(i);
        nodes(i).left = [];
        nodes(i).right = [];
        nodes(i).code = '';
    end 

    while length(nodes) > 1
        [~, sorted_idx] = sort([nodes.probability], 'ascend');
        nodes = nodes(sorted_idx);
        new_node = struct();
        new_node.symbol = [];
        new_node.probability = nodes(1).probability + nodes(2).probability;
        new_node.left = nodes(1);
        new_node.right = nodes(2);
        new_node.code = '';
        nodes = [nodes(3:end), new_node];
    end

    root = nodes(1);
    codebook = struct('symbol', {}, 'code', {});
    codebook = generate_codes(root, '', codebook);

    % 排序输出
    if strcmp(symbol_type, 'single')
        isescape = cellfun(@ischar, {codebook.symbol});
        escape_node = codebook(isescape);
        normal_codebook = codebook(~isescape);

        symbol_cells = {normal_codebook.symbol};
        symbol_vals = reshape(uint8([symbol_cells{:}]), size(symbol_cells));
        [~, sort_idx] = sort(symbol_vals);
    else
        isescape = strcmp({codebook.symbol},escape_symbol);
        escape_node = codebook(isescape);
        normal_codebook = codebook(~isescape);

        symbol_strs = {normal_codebook.symbol};
        n = length(symbol_strs);
        symbols_num = zeros(n, 2, 'uint8');
        for i = 1:n
            nums = sscanf(symbol_strs{i}, '%u %u');
            if length(nums) >= 2
                symbols_num(i, :) = uint8(nums(1:2));
            else
                symbols_num(i, :) = [0, 0];
            end
        end
        [~, sort_idx] = sortrows(symbols_num, [1, 2]);
    end
    normal_codebook = normal_codebook(sort_idx);
    codebook = [normal_codebook, escape_node];
end

% === 递归函数保持不变 ===
function codebook = generate_codes(node, current_code, codebook)
    if isempty(node.left) && isempty(node.right)
        new_entry = struct('symbol', node.symbol, 'code', current_code);
        codebook = [codebook, new_entry];
    else
        if ~isempty(node.left)
            codebook = generate_codes(node.left, [current_code, '0'], codebook);
        end
        if ~isempty(node.right)
            codebook = generate_codes(node.right, [current_code, '1'], codebook);
        end
    end
end