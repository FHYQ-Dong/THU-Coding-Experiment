function [V, H] = seqcplxchan(U, K, b, rho, sigma_n_sq, opts)
    % seqcplxchan 仿真复电平序列信道
    %
    % 本函数依赖于 cplxchan.m
    %
    % 等效模型: v_i = h_i * u_i + n_eff_i,  i = 1...L
    % 其中 h_i = mean_{t=(i-1)*K+1}^{i*K} a_t
    %
    % 语法:
    %   [V, H] = seqcplxchan(U, K, b, rho, sigma_n_sq, opts)
    %
    % 输入:
    %   U          - (L x 1) 复数输入符号序列 [u_1, ..., u_L]
    %   K          - (scalar) 每个 u_i 连续使用的次数
    %   b          - (scalar) 信道参数 b, 范围 [0, 1]
    %   rho        - (scalar) AR(1) 模型相关系数 rho, 范围 [-1, 1]
    %   sigma_n_sq - (scalar) 噪声功率参数 sigma_n^2
    %   opts       - (optional) 可选参数 (例如 opts.seed)
    %
    % 输出:
    %   V          - (L x 1) 复数输出序列 [v_1, ..., v_L]
    %   H          - (L x 1) 等效信道增益序列 [h_1, ..., h_L]

    %% -----  输入参数检查  -----
    if nargin < 5
        error('至少需要 5 个输入参数: U, K, b, rho, sigma_n_sq');
    end
    if ~isvector(U)
        error('输入 U 必须是一个向量。');
    end
    U = U(:);
    L = length(U);
    if L < 1
        error('输入序列 U 的长度必须至少为 1。');
    end
    if ~(isscalar(K) && isreal(K) && K > 0 && mod(K, 1) == 0)
        error('输入 K 必须是一个正整数标量。');
    end
    if nargin < 6 || isempty(opts)
        opts = struct();
    end

    %% -----  cplxchan 的总输入向量 X  -----
    % 每个 u_i 需要重复 K 次，并缩放 1/sqrt(K)
    X = repelem(U / sqrt(K), K, 1);

    %% -----  调用复采样信道  -----
    % A = [a_1, ..., a_T]'
    % Y = [y_1, ..., y_T]'
    [Y, A] = cplxchan(X, b, rho, sigma_n_sq, opts);

    %% -----  输出序列 V (L x 1) -----
    % 将 Y 重塑为 K x L 矩阵、沿列求和、缩放 sqrt(K)
    V_row = sum(reshape(Y, K, L), 1) / sqrt(K);
    V = V_row(:);

    %% -----  计算等效信道序列 H (L x 1)  -----
    % 将 A (T x 1) 重塑为 K x L 矩阵、沿列求均值
    H_row = mean(reshape(A, K, L), 1);
    H = H_row(:);

end
