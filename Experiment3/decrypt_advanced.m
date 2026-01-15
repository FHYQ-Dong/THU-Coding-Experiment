function decrypt_advanced(input_filename, output_filename, key)
% DECRYPT_ADVANCED (SHA-256 + Logistic Chaos 版本) - 修复版
% 修正了逆置乱逻辑不对称的Bug

    % 1. 读取密文
    fid = fopen(input_filename, 'r');
    if fid == -1, error('无法打开密文文件'); end
    ciphertext_str = fread(fid, '*char')'; 
    fclose(fid);
    
    % --- Bit流 -> Byte数组 ---
    bin_matrix = reshape(ciphertext_str, 8, [])';
    encrypted_bytes = uint8(bin2dec(char(bin_matrix)));
    N = length(encrypted_bytes);
    
    % ==============================================
    %      SHA-256 驱动的解密核心
    % ==============================================
    
    % 1. 利用 SHA-256 恢复初始值 (必须与加密端一致)
    [x0_1, x0_2] = get_chaos_params_sha256(key);
    
    % 2. 重现混沌序列
    chaos_seq1 = logistic_map(3.99, x0_1, N);
    chaos_seq2 = logistic_map(3.99, x0_2, N);
    
    % 3. 步骤1: 去除二次扩散 (Inverse Diffusion 2)
    % 异或的逆运算还是异或
    step1_data = bitxor(encrypted_bytes, uint8(mod(chaos_seq1(:) * 1000, 256)));
    
    % 4. 步骤2: 逆置乱 (Inverse Permutation) - 【核心修复】
    [~, idx] = sort(chaos_seq2(:));
    
    % 加密逻辑是: scrambled(idx) = original
    % 这意味着 original(k) 被放到了 scrambled(idx(k))
    % 所以要恢复 original(k)，直接去 scrambled 取 idx(k) 位置的值即可
    unscrambled_data = step1_data(idx); 
    
    % 5. 步骤3: 逆一次扩散 (Inverse Diffusion 1)
    decrypted_bytes = bitxor(unscrambled_data, uint8(chaos_seq1(:) * 255));
    
    % ==============================================
    
    % --- 转换回比特流 ---
    plain_bin_matrix = dec2bin(decrypted_bytes, 8);
    plaintext_str = plain_bin_matrix';
    plaintext_str = plaintext_str(:)';
    
    % --- 后处理：去除 10...0 填充 ---
    % 从末尾寻找第一个 '1'
    last_one_idx = find(plaintext_str == '1', 1, 'last');
    
    if ~isempty(last_one_idx)
        % 找到了填充位，保留它之前的所有位
        plaintext_str = plaintext_str(1:last_one_idx-1);
    else
        % 如果没找到，说明解密后的数据完全不对（由于置乱错误或密钥错误）
        warning('SHA-256混沌解密：未检测到填充位 1，解密可能失败（数据损坏或逻辑错误）。');
    end
    
    % 输出明文
    fid_out = fopen(output_filename, 'w');
    fwrite(fid_out, plaintext_str, 'char');
    fclose(fid_out);
    
    fprintf('高级混沌解密完成: %s -> %s\n', input_filename, output_filename);
end

% 混沌映射函数 (需与加密端完全一致)
function seq = logistic_map(r, x0, n)
    seq = zeros(n, 1);
    x = x0;
    for i = 1:n+1000  
        x = r * x * (1 - x);
        if i > 1000
            seq(i-1000) = x;
        end
    end
end

% SHA-256 辅助函数
function [x0_1, x0_2] = get_chaos_params_sha256(key)
    if isnumeric(key), key_str = num2str(key(:)'); else, key_str = char(key); end
    import java.security.MessageDigest;
    hasher = MessageDigest.getInstance('SHA-256');
    hasher.update(uint8(key_str));
    digest = typecast(hasher.digest(), 'uint8');
    val1 = typecast(digest(1:8), 'uint64'); 
    x0_1 = double(val1) / 1.844674407370955e+19; 
    val2 = typecast(digest(9:16), 'uint64');
    x0_2 = double(val2) / 1.844674407370955e+19;
    if x0_1 <= 0 || x0_1 >= 1, x0_1 = 0.12345678; end
    if x0_2 <= 0 || x0_2 >= 1, x0_2 = 0.87654321; end
end
