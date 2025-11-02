function decoded_image = decode_huffman(encoded_bits_bi, symbol_mode, image_size)
% DECODE_HUFFMAN 通用Huffman解码接口
% Inputs:
%   encoded_bits: 字符串形式的编码比特流，如 '1010110...'
%   symbol_mode:  'single' 或 'double'
%   image_size:   原始图像尺寸 [rows, cols]
    
    %将二进制数组转为字符串
    encoded_bits = num2str(encoded_bits_bi);
    encoded_bits = encoded_bits(encoded_bits ~= ' ');  % 移除空格
       
    if strcmp(symbol_mode, 'single')
        decoded_data = decode_single_symbol(encoded_bits, 'huff_table1.txt');
    elseif strcmp(symbol_mode, 'double')
        decoded_data = decode_double_symbol(encoded_bits, 'huff_table2.txt');
        % 移除可能的填充像素（如果原始长度为奇数）
        total_pixels = prod(image_size);
        if length(decoded_data) > total_pixels
            decoded_data = decoded_data(1:total_pixels);
        end
    else
        error('未知的符号模式: %s', symbol_mode);
    end

    % 重塑为原始图像尺寸
    decoded_image = reshape(decoded_data, image_size);
end

%% 单符号解码
function decoded_data = decode_single_symbol(encoded_bits, codebook_file)
    % 读取码本
    [codebook, escape_code] = load_codebook(codebook_file, 'single');
    
    % 构建码字到符号的映射（用于快速查找）
    code_to_symbol = containers.Map('KeyType', 'char', 'ValueType', 'uint8');
    for i = 1:length(codebook)
        code_str = codebook(i).code;
        if isKey(code_to_symbol, code_str)
            warning('码本中存在重复码字: %s', code_str);
        else
            code_to_symbol(code_str) = codebook(i).symbol;
        end
    end
    code_to_symbol(escape_code) = 0;%这个值任取都行，因为不care，只是将逃逸码码字添加到map中

    % % 解码过程
    idx = 1;
    current_code = '';
    decoded_symbols = [];
    while idx <= length(encoded_bits)
        current_code = [current_code, encoded_bits(idx)];
        idx = idx + 1;
        if isKey(code_to_symbol, current_code)       
            if strcmp(current_code, escape_code)
                % 逃逸码：读取接下来的8位作为原始像素值
                if idx + 7 > length(encoded_bits)
                    error('逃逸码后数据小于8位');
                end
                binary_val = encoded_bits(idx : idx+7);
                pixel_val = bin2dec(binary_val);
                decoded_symbols(end+1) = uint8(pixel_val);
                idx = idx + 8;
            else
                % 正常符号
                symbol = code_to_symbol(current_code);
                decoded_symbols(end+1) = symbol;
            end

            current_code = ''; % 重置
        end
    end

    if ~isempty(current_code)
        warning('解码结束时存在未匹配的比特: %s', current_code);
    end

    decoded_data = uint8(decoded_symbols)';
end

%% 双符号解码
function decoded_data = decode_double_symbol(encoded_bits, codebook_file)
    % 读取码本
    [codebook, escape_code] = load_codebook(codebook_file, 'double');
    
    % 构建码字到符号对的映射
    code_to_symbol = containers.Map('KeyType', 'char', 'ValueType', 'any');
    for i = 1:length(codebook)
        code_str = codebook(i).code;
        if isKey(code_to_symbol, code_str)
            warning('码本中存在重复码字: %s', code_str);
        else
            code_to_symbol(code_str) = codebook(i).symbol;
        end
    end
    code_to_symbol(escape_code) = 0;%这个值任取都行，因为不care，只是将逃逸码码字添加到map中

    % 解码过程
    idx = 1;
    current_code = '';
    decoded_pixels = [];

    while idx <= length(encoded_bits)
        current_code = [current_code, encoded_bits(idx)];
        idx = idx + 1;

        if isKey(code_to_symbol, current_code)
            if strcmp(current_code, escape_code)
                % 逃逸码：读取接下来的16位（两个8位像素）
                if idx + 15 > length(encoded_bits)
                    error('逃逸码后数据不足16位');
                end
                binary1 = encoded_bits(idx : idx+7);
                binary2 = encoded_bits(idx+8 : idx+15);
                pixel1 = bin2dec(binary1);
                pixel2 = bin2dec(binary2);
                decoded_pixels(end+1) = uint8(pixel1);
                decoded_pixels(end+1) = uint8(pixel2);
                idx = idx + 16;
            else
                % 正常符号对
                symbol_pair_str = code_to_symbol(current_code);
                nums = sscanf(symbol_pair_str, '%d %d');
                if length(nums) ~= 2
                    error('无效的符号对格式: %s', symbol_pair_str);
                end
                decoded_pixels(end+1) = uint8(nums(1));
                decoded_pixels(end+1) = uint8(nums(2));
            end
            
            current_code = '';
        end
    end

    if ~isempty(current_code)
        warning('解码结束时存在未匹配的比特: %s', current_code);
    end

    decoded_data = uint8(decoded_pixels)';
end

%% 从文件加载码本
function [codebook, escape_code] = load_codebook(filename, symbol_type)
    fid = fopen(filename, 'r');
    if fid == -1
        error('无法打开码本文件: %s', filename);
    end

    codebook = struct('symbol', {}, 'code', {});
    line_num = 0;
    escape_code = '';

    try
        while ~feof(fid)
            line = fgetl(fid);
            if isempty(line) || line(1) == '%'  % 跳过空行和注释
                continue;
            end
            line_num = line_num + 1;

            % 尝试按制表符分割
            parts = strsplit(line, '\t');
            if length(parts) == 2
                % 正常码本条目
                symbol_str = parts{1};
                code_str = parts{2};

                if strcmp(symbol_type, 'single')
                    symbol_val = str2double(symbol_str);
                    if isnan(symbol_val)
                        error('无法解析单符号: %s', symbol_str);
                    end
                    symbol = uint8(symbol_val);
                else
                    % 双符号直接保留字符串（如 '12 34'）
                    symbol = symbol_str;
                end

                codebook(end+1) = struct('symbol', symbol, 'code', code_str);
            elseif length(parts) == 1
                % 假设这是最后一行：逃逸码
                if line_num == 1 && isempty(codebook)
                    % 如果文件只有一行，可能是只有逃逸码（极端情况）
                    error('码本的第一行即为逃逸码');
                else
                    % 否则，这行就是逃逸码
                    escape_code = line;
                    break;
                end
            else
                error('码本中该行被制表符分为%d部分', length(parts));
            end
        end

        fclose(fid);

        if isempty(escape_code)
            error('码本文件中未找到逃逸码行');
        end

        % 验证最后一个条目是否为逃逸码（可选）
        % 实际上我们单独存储了 escape_code，码本中不包含它
        % 所以 codebook 仅包含正常符号

    catch ME
        fclose(fid);
        rethrow(ME);
    end
end