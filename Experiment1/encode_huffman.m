function encoded_bits = encode_huffman(image, symbol_mode, escape_count)
    % ENCODE_HUFFMAN 通用Huffman编码接口
    % symbol_mode: 'single' 或 'double'

    if strcmp(symbol_mode, 'single')
        [tmp1, tmp2] = single_symbol_huffman(image, 'huff_table1.txt', escape_count);
    elseif strcmp(symbol_mode, 'double')
        [tmp1, tmp2] = double_symbol_huffman(image, 'huff_table2.txt', escape_count);
    else
        error('未知的符号模式: %s', symbol_mode);
    end

    encoded_bits = zeros(1, length(tmp1));
    encoded_bits(tmp1 == '1') = 1;
end

%% 单符号Huffman编码
function [encoded_bits, stats] = single_symbol_huffman(image, codebook_file, escape_count)
    % 将图像转换为一维序列
    data = image(:);
    
    % 统计符号频率
    symbols = unique(data);
    counts = histcounts(data, [symbols; max(symbols)+1]);
    probabilities = counts / sum(counts);

    % probabilities(probabilities <= 1e-2) = 0;
    
    fprintf('数据长度: %d (原始像素), %d (符号)\n', length(data), length(data));
    fprintf('符号种类: %d\n', length(symbols));

    % 生成Huffman码本
    symbols = num2cell(symbols);
    [codebook, excluded_symbols] = generate_huffman_codebook(symbols, probabilities, 'single', escape_count/length(data));
    fprintf('逃逸码：将出现次数少于%d次的符号排除\n', escape_count);
    fprintf('       被排除的低概率符号: %d种\n', length(excluded_symbols));
    %codebook = generate_huffman_codebook(symbols, probabilities, 'single');
    
    %辅助工具，toolbox自带的霍夫曼编码
    %[dict,avglen] = huffmandict(symbols,probabilities);

    % 编码数据
    encoded_bits = encode_single_symbol(data, codebook);

     
    % 计算统计信息
    stats = calculate_coding_stats(data, encoded_bits, codebook, 'single');
    
    % 保存码本到文件
    save_codebook(codebook, codebook_file, 'single');
end

%% 双符号Huffman编码
function [encoded_bits, stats] = double_symbol_huffman(image, codebook_file, escape_count)
    % 将图像转换为一维序列
    data = image(:);
    
    % 确保数据长度为偶数
    if mod(length(data), 2) ~= 0
        data = [data; data(end)]; % 重复最后一个像素
    end
    
    % 构建符号对
    symbol_pairs = reshape(data, 2, [])';
    pair_symbols = cell(size(symbol_pairs, 1), 1);
    
    for i = 1:size(symbol_pairs, 1)
        pair_symbols{i} = sprintf('%d %d', symbol_pairs(i, 1), symbol_pairs(i, 2));
    end
    
    % 统计符号对频率
    [unique_pairs, ~, ic] = unique(pair_symbols);
    counts = histcounts(ic, [1:length(unique_pairs), length(unique_pairs)+1]);
    probabilities = counts / sum(counts);

    % probabilities(probabilities <= 1e-2) = 0;
    
    fprintf('数据长度: %d (原始像素), %d (符号对)\n', length(data), length(data)/2);
    fprintf('符号对种类: %d\n', length(unique_pairs));

    % 生成Huffman码本
    [codebook, excluded_symbols] = generate_huffman_codebook(unique_pairs, probabilities, 'double', 2*escape_count/length(data));
    fprintf('逃逸码：将出现次数少于%d次的符号排除\n', escape_count);
    fprintf('       被排除的低概率符号对: %d种\n', length(excluded_symbols));
    %codebook = generate_huffman_codebook(unique_pairs, probabilities, 'double');
    
    % 编码数据
    encoded_bits = encode_double_symbol(pair_symbols, codebook);
    %辅助工具，toolbox自带的霍夫曼编码
    %[dict,avglen] = huffmandict(unique_pairs,probabilities);

    % 计算统计信息
    stats = calculate_coding_stats(data, encoded_bits, codebook, 'double');
    
    % 保存码本到文件
    save_codebook(codebook, codebook_file, 'double');
end

%% 单符号编码生成比特流
function encoded_bits = encode_single_symbol(data, codebook)
% ENCODE_SINGLE_SYMBOL 单符号编码实现
    
    % 分离逃逸码和正常码字
    escape_code = codebook(end).code;
    normal_codebook = codebook;
    normal_codebook(end) = [];

    encoded_cells = cell(length(data), 1);
    index = 1;
    
    % 构建符号到码字的映射表（提高查找效率）
    symbol_map = containers.Map('KeyType', 'int32', 'ValueType', 'char');
    for i = 1:length(normal_codebook)
        symbol_map(int32(normal_codebook(i).symbol)) = normal_codebook(i).code;
    end
    
    % 遍历每个像素进行编码
    for i = 1:length(data)
        pixel_value = data(i);
            
        % 查找码字
        if isKey(symbol_map, int32(pixel_value))
            % 找到对应码字
            encoded_cells{index} = symbol_map(int32(pixel_value));
        else
            % 使用逃逸码 + 8bit原始值
            binary_value = dec2bin(pixel_value, 8);
            encoded_cells{index} = [escape_code, binary_value];
            %warning('像素值 %d 在码本中未找到，使用逃逸码编码', pixel_value);
        end
            
        index = index + 1;    
    end
    
    % 移除空单元格（如果有）
    encoded_cells = encoded_cells(1:index-1);

    encoded_bits = strjoin(encoded_cells, '');
end

%% 双符号编码生成比特流
function encoded_bits = encode_double_symbol(data, codebook)
% ENCODE_DOUBLE_SYMBOL 双符号编码实现
% data为元胞数组
    
    % 分离逃逸码和正常码字
    escape_code = codebook(end).code;
    normal_codebook = codebook;
    normal_codebook(end) = [];
    
    % 构建符号对到码字的映射表
    symbol_map = containers.Map('KeyType', 'char', 'ValueType', 'char');
    for i = 1:length(normal_codebook)
        key = normal_codebook(i).symbol;
        symbol_map(key) = normal_codebook(i).code;
    end
    
    % 将数据重塑为符号对
    pair_count = length(data);
    encoded_cells = cell(pair_count, 1);
    
    % 遍历每个符号对进行编码
    for i = 1:pair_count
        
        key = data{i};
        nums = sscanf(key, '%d %d');
        symbol1 = uint8(nums(1));
        symbol2 = uint8(nums(2));
        
        % 查找码字
        if isKey(symbol_map, key)
            % 找到对应码字
            encoded_cells{i} = symbol_map(key);
        else
            % 使用逃逸码 + 两个8bit原始值
            binary1 = dec2bin(symbol1, 8);
            binary2 = dec2bin(symbol2, 8);
            encoded_cells{i} = [escape_code, binary1, binary2];
            %warning('符号对 (%d, %d) 在码本中未找到，使用逃逸码编码', symbol1, symbol2);
        end
    end

    encoded_bits = strjoin(encoded_cells, '');
end

%% 保存码本到文件
function save_codebook(codebook, filename, codebook_type)
    fid = fopen(filename, 'w');
    if fid == -1
        error('无法打开码本文件: %s', filename);
    end
    
    try
        % 分离正常符号和逃逸码
        escape_entry = codebook(end);
        normal_entries = codebook;
        normal_entries(end) = [];
        
        % 写入正常符号的映射
        for i = 1:length(normal_entries)
            entry = normal_entries(i);
            
            if strcmp(codebook_type, 'single')
                % 单符号映射
                if isnumeric(entry.symbol)
                    fprintf(fid, '%d\t%s\n', entry.symbol, entry.code);
                else
                    fprintf(fid, '%s\t%s\n', num2str(entry.symbol), entry.code);
                end
            else
                % 双符号映射
                if ischar(entry.symbol) || isstring(entry.symbol)
                    sym_str = char(entry.symbol);
                    fprintf(fid, '%s\t%s\n', sym_str, entry.code);
                else
                    warning('双符号码本中的符号格式不正确，跳过: %s', mat2str(entry.symbol));
                    continue;
                end
            end
        end
        
        % 写入逃逸码（单独一行）
        fprintf(fid, '%s\n', escape_entry.code);
        
        % 关闭文件
        fclose(fid);
        
        fprintf('码本已成功保存到: %s\n', filename);
        fprintf('码本类型: %s符号\n\n', codebook_type);
        
    catch ME
        % 发生错误时关闭文件
        if fid ~= -1
            fclose(fid);
        end
        rethrow(ME);
    end
end

function [codebook, excluded_symbols] = generate_huffman_codebook(symbols, probabilities, symbol_type, prob_threshold)
% GENERATE_HUFFMAN_CODEBOOK 生成霍夫曼码本（含逃逸码）
% 将可调参数prob_threshold添加至函数输入，作为逃逸码阈值
    escape_symbol = 'ESCAPE';
    %excluded_symbols = []; % 默认为空

    %prob_threshold = 1e-4; % 可调参数
        
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

% === 递归函数 ===
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
