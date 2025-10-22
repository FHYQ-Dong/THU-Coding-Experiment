function encoded_bits = encode_huffman(image, symbol_mode)
    % ENCODE_HUFFMAN 通用Huffman编码接口
    % symbol_mode: 'single' 或 'double'
    if strcmp(symbol_mode, 'single')
        [tmp1, tmp2] = single_symbol_huffman(image, 'table.txt');
    elseif strcmp(symbol_mode, 'double')
        [tmp1, tmp2] = double_symbol_huffman(image, 'table2.txt');
    else
        error('未知的符号模式: %s', symbol_mode);
    end

    encoded_bits = zeros(1, length(tmp1));
    encoded_bits(tmp1 == '1') = 1;
end

%% 单符号Huffman编码
function [encoded_bits, stats] = single_symbol_huffman(image, codebook_file)
    % 将图像转换为一维序列
    data = image(:);
    
    % 统计符号频率
    symbols = unique(data);
    counts = histcounts(data, [symbols; max(symbols)+1]);
    probabilities = counts / sum(counts);

    % probabilities(probabilities <= 1e-2) = 0;
    
    fprintf('符号数量: %d\n', length(symbols));
    fprintf('数据长度: %d\n', length(data));
    
    % 生成Huffman码本
    symbols = num2cell(symbols);
    [codebook, excluded_symbols] = generate_huffman_codebook(symbols, probabilities, 'single');
    %codebook = generate_huffman_codebook(symbols, probabilities, 'single');

    % 编码数据
    encoded_bits = encode_single_symbol(data, codebook);

    % 计算统计信息
    stats = calculate_coding_stats(data, encoded_bits, codebook, 'single');
    
    % 保存码本到文件
    save_codebook(codebook, codebook_file, 'single');
end

%% 双符号Huffman编码
function [encoded_bits, stats] = double_symbol_huffman(image, codebook_file)
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
    
    fprintf('符号对数量: %d\n', length(unique_pairs));
    fprintf('数据长度: %d (原始像素), %d (符号对)\n', length(data), length(unique_pairs));
    
    % 生成Huffman码本
    [codebook, excluded_symbols] = generate_huffman_codebook(unique_pairs, probabilities, 'double');
    fprintf('  被排除的低概率符号对: %d种\n', length(excluded_symbols));
    %codebook = generate_huffman_codebook(unique_pairs, probabilities, 'double');
    
    % 编码数据
    encoded_bits = encode_double_symbol(pair_symbols, codebook);

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
        fprintf('码本类型: %s符号\n', codebook_type);
        
    catch ME
        % 发生错误时关闭文件
        if fid ~= -1
            fclose(fid);
        end
        rethrow(ME);
    end
end
