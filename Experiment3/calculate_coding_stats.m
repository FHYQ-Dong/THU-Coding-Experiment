%% 计算编码统计信息并输出
function stats = calculate_coding_stats(original_data, encoded_bits, codebook, symbol_type)
    
    % 分离正常符号和逃逸码
    %escape_idx = find([codebook.symbol] == 255);
    %if isempty(escape_idx)
    %    error('码本中未找到逃逸码');
    %end
    
    escape_entry = codebook(end);
    normal_codebook = codebook;
    normal_codebook(end) = [];
    
    % 原始数据比特数
    original_bits_count = length(original_data) * 8; % 每个像素8比特
    
    % 编码后比特数
    encoded_length = length(encoded_bits);
    
    % 码本大小估算 - 更准确的估算
    codebook_bits = calculate_codebook_size(normal_codebook, escape_entry, symbol_type);
    
    % 总传输比特数（数据 + 码本）
    total_bits = encoded_length + codebook_bits;
    
    % 压缩比  &  编码效率
    compression_ratio = original_bits_count / total_bits;
    coding_efficiency = original_bits_count / encoded_length;
    
    % 统计逃逸码出现次数：通过前缀匹配解码
    escape_code = escape_entry.code;
    escape_counts = 0;

    % 构建码字到符号的映射（用于快速查找）
    code_to_symbol = containers.Map();
    for i = 1:length(codebook)
        code_str = codebook(i).code;
        sym = codebook(i).symbol;
        % 如果 code_str 已存在（理论上不应发生），可报错
        if isKey(code_to_symbol, code_str)
            warning('码本中存在重复码字: %s', code_str);
        else
            code_to_symbol(code_str) = sym;
        end
    end

    % 模拟解码过程
    idx = 1;  % 当前比特位置
    current_code = '';
    while idx <= encoded_length
        current_code = [current_code, encoded_bits(idx)];
        idx = idx + 1;
        % 检查当前码是否在码本中
        if isKey(code_to_symbol, current_code)
            % 判断是否为逃逸符号
            if strcmp(escape_code, current_code)
                escape_counts = escape_counts + 1;

                % 跳过后续的原始数据比特
                if strcmp(symbol_type, 'single')
                    skip_bits = 8;
                else
                    skip_bits = 16;
                end
                idx = idx + skip_bits;
                % 检查是否越界
                if idx - 1 > encoded_length
                    warning('逃逸码后原始数据不完整');
                    break;
                end
            end
            % 重置当前码，准备下一个符号
            current_code = '';
        end
        % 注意：由于是前缀码，一旦匹配就一定是完整符号，无需回溯
    end

    % 如果循环结束 current_code 非空，说明比特流不完整（可选报错）
    if ~isempty(current_code)
        warning('编码比特流末尾存在无法匹配的比特: %s', current_code);
    end

    stats = struct( ...
    'original_bits_count', original_bits_count, ...
    'encoded_length',      encoded_length, ...
    'codebook_bits',       codebook_bits, ...
    'total_bits',          total_bits, ...
    'compression_ratio',   compression_ratio, ...
    'coding_efficiency',   coding_efficiency, ...
    'symbol_type',         symbol_type, ...
    'codebook_size_symbols', length(normal_codebook), ...
    'escape_code',         escape_entry.code, ...
    'escape_counts',       escape_counts ...
);

    fprintf('编码统计:\n');
    fprintf('  原始数据比特数: %d bits\n', original_bits_count);
    fprintf('  编码后数据比特数: %d bits\n', encoded_length);
    fprintf('  码本大小: %d bits\n', codebook_bits);
    fprintf('  总传输比特数: %d bits\n', total_bits);
    fprintf('  压缩比: %.4f\n', compression_ratio);
    fprintf('  编码效率: %.4f\n', coding_efficiency);
    fprintf('  编码类型: %s符号编码\n', symbol_type);
    fprintf('  正常符号种类: %d 种符号\n', length(normal_codebook));
    fprintf('  逃逸码: %s\n', escape_entry.code);
    fprintf('  逃逸码出现次数: %d\n', escape_counts);
end

%% 计算码本大小
function codebook_bits = calculate_codebook_size(normal_codebook, escape_entry, symbol_type)
% 更准确地估算码本传输所需比特数
    
    % 码本条目比特数
    entry_bits = 0;
    for i = 1:length(normal_codebook)
        symbol_data = normal_codebook(i);
        
        if (strcmp(symbol_type,'single'))
            % 单符号：符号值(8bit) + 码字本身
            symbol_bits = 8 + length(symbol_data.code);
        else
            % 双符号：两个符号值(16bit) + 码字本身
            symbol_bits = 16 + length(symbol_data.code);
        end
        entry_bits = entry_bits + symbol_bits;
    end
    
    % 逃逸码信息
    escape_bits = length(escape_entry.code); % 逃逸码标识(8bit) + 逃逸码本身
    
    codebook_bits = entry_bits + escape_bits;
end
