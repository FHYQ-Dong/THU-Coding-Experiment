function encrypt_advanced(input_filename, output_filename, key)
% ENCRYPT_ADVANCED (SHA-256 + Logistic Chaos 版本)
% 结合了 SHA-256 哈希密钥扩展和双重混沌结构

    % 1. 读取明文流
    fid = fopen(input_filename, 'r');
    if fid == -1, error('无法打开明文文件'); end
    plaintext_str = fread(fid, '*char')'; 
    fclose(fid);
    
    % --- 预处理：10...0 填充 ---
    plaintext_str = [plaintext_str, '1'];
    len = length(plaintext_str);
    pad_len = mod(8 - mod(len, 8), 8);
    if pad_len == 8, pad_len = 0; end
    plaintext_str = [plaintext_str, repmat('0', 1, pad_len)];
    
    % --- Bit流 -> Byte数组 ---
    bin_matrix = reshape(plaintext_str, 8, [])'; 
    data_bytes = uint8(bin2dec(char(bin_matrix)));
    N = length(data_bytes); 
    
    % ==============================================
    %      SHA-256 驱动的混沌核心
    % ==============================================
    
    % 1. 利用 SHA-256 生成高灵敏度初始值
    [x0_1, x0_2] = get_chaos_params_sha256(key);
    
    % 2. 生成混沌序列 (使用动态生成的 x0)
    % 参数 r 设为 3.99 以确保处于完全混沌状态
    chaos_seq1 = logistic_map(3.99, x0_1, N);
    chaos_seq2 = logistic_map(3.99, x0_2, N);
    
    % 3. 步骤1: 像素值扩散 (Diffusion 1)
    diffused_data = bitxor(data_bytes, uint8(chaos_seq1(:) * 255));
    
    % 4. 步骤2: 位置置乱 (Permutation)
    [~, idx] = sort(chaos_seq2(:));
    scrambled_data = diffused_data;
    scrambled_data(idx) = diffused_data; 
    
    % 5. 步骤3: 二次扩散 (Diffusion 2)
    encrypted_bytes = bitxor(scrambled_data, uint8(mod(chaos_seq1(:) * 1000, 256)));
    
    % ==============================================
    
    % --- 转换回比特流并输出 ---
    cipher_bin_matrix = dec2bin(encrypted_bytes, 8);
    final_ciphertext = cipher_bin_matrix'; 
    final_ciphertext = final_ciphertext(:)'; 
    
    fid_out = fopen(output_filename, 'w');
    fwrite(fid_out, final_ciphertext, 'char');
    fclose(fid_out);
    
    fprintf('高级混沌加密完成 (SHA-256): %s -> %s\n', input_filename, output_filename);
end

% 混沌映射函数
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

% 在此处粘贴 get_chaos_params_sha256 函数，或者将其放在同路径下
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