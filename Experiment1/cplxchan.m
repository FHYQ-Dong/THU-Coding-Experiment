function [Y, A] = cplxchan(X, b, rho, sigma_n_sq, opts)
    % cplxchan 仿真复采样信道
    %
    % 信道模型:
    %   y_i = a_i * x_i + n_i
    %   a_i = sqrt(1 - b^2) + b * beta_i
    %   beta_i = rho * beta_{i-1} + sqrt(1 - rho^2) * z_i
    %
    % 语法:
    %   [Y, A] = cplxchan(X, b, rho, sigma_n_sq, opts)
    %
    % 输入:
    %   X          - (N x 1) 复数输入符号向量 [x_1, ..., x_N]。
    %   b          - (scalar) 信道参数 b, 范围 [0, 1]
    %   rho        - (scalar) AR(1) 模型相关系数 rho, 范围 [-1, 1]
    %   sigma_n_sq - (scalar) 噪声功率参数 sigma_n^2
    %   opts.seed  - (optional) 随机数生成器种子，用于结果可重复性
    %
    % 输出:
    %   Y          - (N x 1) 复数输出向量 [y_1, ..., y_N]
    %   A          - (N x 1) 复数信道系数向量 [a_1, ..., a_N]
    %
    % 随机变量:
    %   - beta_1, z_i: 独立复高斯, 均值为0, 总方差为 0.5
    %   - n_i: 独立复高斯, 均值为0, 总方差为 sigma_n_sq / 2

    %% -----  输入参数检查  -----
    if ~isvector(X)
        error('输入 X 必须是一个向量。');
    end
    X = X(:);
    N = length(X);
    if N < 1
        error('输入向量 X 的长度必须至少为 1。');
    end
    if ~(isscalar(b) && isreal(b) && b >= 0 && b <= 1)
        error('参数 b 必须是 [0, 1] 范围内的实数标量。');
    end
    if ~(isscalar(rho) && isreal(rho) && abs(rho) <= 1)
        warning('参数 rho 通常为实数，且绝对值不超过 1。');
    end
    if ~(isscalar(sigma_n_sq) && isreal(sigma_n_sq) && sigma_n_sq >= 0)
        error('参数 sigma_n_sq 必须是非负实数标量。');
    end

    if nargin < 5 || isempty(opts)
        opts = struct();
    end
    if isstruct(opts) && isfield(opts,'seed') && ~isempty(opts.seed)
        rng(opts.seed,'twister');
    end

    %% -----  生成 beta  -----
    var_beta_z_total = 0.5;
    std_dev_part_beta_z = sqrt(var_beta_z_total / 2);
    beta = complex(zeros(N, 1));
    beta(1) = (randn() + 1i * randn()) * std_dev_part_beta_z;
    Z = (randn(N-1, 1) + 1i * randn(N-1, 1)) * std_dev_part_beta_z; % 只需要 N-1 个 z_i
    ar_factor = sqrt(1 - rho^2);
    for i = 2:N
        beta(i) = rho * beta(i-1) + ar_factor * Z(i-1); % Z(i-1) 对应 z_i
    end

    %% -----  生成 A  -----
    A = sqrt(1 - b^2) + b * beta;

    %% -----  生成 N_noise  -----
    % n_i 的总方差为 sigma_n_sq / 2, 因此实部和虚部分别为 sigma_n_sq / 4
    N_noise = (randn(N, 1) + 1i * randn(N, 1)) * sqrt(sigma_n_sq / 4);

    %% -----  输出 Y  -----
    Y = A .* X + N_noise;

end
