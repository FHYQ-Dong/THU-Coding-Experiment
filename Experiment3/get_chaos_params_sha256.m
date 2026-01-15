function [x0_1, x0_2] = get_chaos_params_sha256(key)
% GET_CHAOS_PARAMS_SHA256 利用 SHA-256 将任意密钥转换为混沌初始值
% 输入: 任意类型的 key (字符串、数字、向量)
% 输出: 两个 (0, 1) 之间的双精度浮点数，用作 Logistic 映射的 x0

    % 1. 统一转换为字符串并提取字节
    if isnumeric(key)
        key_str = num2str(key(:)'); % 将数字转为字符串
    else
        key_str = char(key);
    end
    key_bytes = uint8(key_str);

    % 2. 调用 Java 的 SHA-256 算法
    import java.security.MessageDigest;
    hasher = MessageDigest.getInstance('SHA-256');
    hasher.update(key_bytes);
    digest = typecast(hasher.digest(), 'uint8'); % 获取 32 字节哈希值
    
    % 3. 利用哈希值的不同部分生成参数
    % SHA-256 有 32 个字节。我们取前 8 字节生成 x0_1，取后 8 字节生成 x0_2
    
    % --- 生成 x0_1 (利用第 1-8 字节) ---
    % 将 8 个字节组合成一个 64 位无符号整数
    val1 = typecast(digest(1:8), 'uint64'); 
    % 归一化到 (0, 1) 区间: 除以 2^64
    x0_1 = double(val1) / 1.844674407370955e+19; 
    
    % --- 生成 x0_2 (利用第 9-16 字节) ---
    val2 = typecast(digest(9:16), 'uint64');
    x0_2 = double(val2) / 1.844674407370955e+19;
    
    % 4. 边界保护 (Logistic 映射对 0 和 1 敏感)
    if x0_1 <= 0 || x0_1 >= 1, x0_1 = 0.12345678; end
    if x0_2 <= 0 || x0_2 >= 1, x0_2 = 0.87654321; end
    
    % fprintf('SHA-256 Derived Params: x0_1 = %.8f, x0_2 = %.8f\n', x0_1, x0_2);
end
