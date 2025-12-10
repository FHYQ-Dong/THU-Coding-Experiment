% --- sim_err_ser_vs_snr.m ---
%
% 演示使用导频和信道估计的相干解调
%
% 依赖:
%   cplxchan.m
%   seqcplxchan.m
%   constellation_map.m
%   bit2sym.m
%   sym2bit.m

clear; clc; close all;

%% 1. 仿真参数设置
L_data = 5000;     % *数据* 符号序列长度
K = 10;            % 每个 u_i 的重复次数
M = 1;             % 比特/符号 (M=2, QPSK)
B_total = L_data * M; % 总 *数据* 比特数

% 导频配置
use_pilot = true;
pilot_config.interval = 3; % 1 导频, 2 数据
pilot_config.symbol = 1 + 0j;

% 信道参数
b = 0.7;
rho = 0.996;
opts.seed = 42;

% SNR 扫描参数
sigma_n_sq_vec = logspace(-2, 1, 10); % 扫描 10 个 sigma_n^2 点
snr_db_vec = zeros(size(sigma_n_sq_vec));
ser_vec = zeros(size(sigma_n_sq_vec));
ber_vec = zeros(size(sigma_n_sq_vec));

fprintf('--- 仿真开始 (带信道估计) ---\n');
fprintf('M=%d, K=%d, L_data=%d, Pilot Interval=%d\n', M, K, L_data, pilot_config.interval);

H_estimated_all = {};
H_true_all = {};
bit_stream_in_all = {};
bit_stream_out_all = {};

%% 2. SER vs. SNR 循环
for i = 1:length(sigma_n_sq_vec)
    sigma_n_sq = sigma_n_sq_vec(i);
    opts.seed = 42; 

    % --- 生成比特流 ---
    bit_stream_in = randi([0 1], B_total, 1);
    bit_stream_in_all{i} = bit_stream_in;

    % --- 1. 比特 -> 符号 (插入导频) ---
    [U_total, is_data_mask] = bit2sym(bit_stream_in, M, 1, use_pilot, pilot_config);

    % --- 2. 通过序列信道 ---
    % H_true 是为了计算SNR，接收端不知道
    [V, H_true] = seqcplxchan(U_total, K, b, rho, sigma_n_sq, opts); 
    H_true_all{i} = H_true;

    % --- 3. 符号 -> 比特 (带估计) ---
    [bit_stream_out, H_estimated] = sym2bit(V, M, 1, use_pilot, pilot_config);
    H_estimated_all{i} = H_estimated;
    bit_stream_out_all{i} = bit_stream_out;

    % --- 4. 检查比特流长度 (非常重要) ---
    if length(bit_stream_in) ~= length(bit_stream_out)
        error('输入输出比特流长度不匹配! %d vs %d', ...
              length(bit_stream_in), length(bit_stream_out));
    end
    
    % --- 5. 计算 SER (误符号率) ---
    U_data_in = U_total(is_data_mask);
    [U_data_out, ~] = bit2sym(bit_stream_out, M, 1, false); % 仅用 bit2sym 重建
    num_sym_errors = sum(U_data_in ~= U_data_out);
    ser_vec(i) = num_sym_errors / L_data;

    % --- 6. 计算 BER (误比特率) ---
    num_bit_errors = sum(bit_stream_in ~= bit_stream_out);
    ber_vec(i) = num_bit_errors / B_total;
    
    % --- 7. 计算真实的信噪比 (用于绘图) ---
    S_seq_power = mean(abs(H_true(is_data_mask) .* U_data_in).^2);
    N_eff = V(is_data_mask) - (H_true(is_data_mask) .* U_data_in);
    N_seq_power = mean(abs(N_eff).^2);
    snr_db_vec(i) = 10 * log10(S_seq_power / N_seq_power);
    
    fprintf('  sigma_n^2=%.2e | SNR=%.2f dB | SER=%.4f | BER=%.4f\n', ...
             sigma_n_sq, snr_db_vec(i), ser_vec(i), ber_vec(i));
end

%% 3. 绘制 SER/BER vs. SNR 曲线
figure;
semilogy(snr_db_vec, ser_vec, 'o-b', 'LineWidth', 2, 'DisplayName', 'SER');
hold on;
semilogy(snr_db_vec, ber_vec, 's-r', 'LineWidth', 2, 'DisplayName', 'BER');
title('SER/BER vs. SNR (带信道估计)');
xlabel('SNR_{seq} (dB)');
ylabel('错误率');
grid on;
ylim([1e-4, 1.0]);
legend show;

figure;
hold on;
if use_pilot
    H_estimated = H_estimated_all{1};
    plot(1:20, real(H_estimated(1:20)), 'o-', 'DisplayName', 'Re(H_{估计})');
    plot(1:20, imag(H_estimated(1:20)), 'o-', 'DisplayName', 'Im(H_{估计})');
end
H_true = H_true_all{1};
plot(1:20, real(H_true(1:20)), 'x--', 'DisplayName', 'Re(H_{真实})');
plot(1:20, imag(H_true(1:20)), 'x--', 'DisplayName', 'Im(H_{真实})');
grid on;
title('sigma_n^2 = 0.01 时 H 的分布');
xlabel('比特索引（1:20）'); ylabel('H 值');
legend show;
hold off;

figure;
hold on;
if use_pilot
    H_estimated = H_estimated_all{end};
    plot(1:20, real(H_estimated(1:20)), 'o-', 'DisplayName', 'Re(H_{估计})');
    plot(1:20, imag(H_estimated(1:20)), 'o-', 'DisplayName', 'Im(H_{估计})');
end
H_true = H_true_all{end};
plot(1:20, real(H_true(1:20)), 'x--', 'DisplayName', 'Re(H_{真实})');
plot(1:20, imag(H_true(1:20)), 'x--', 'DisplayName', 'Im(H_{真实})');
grid on;
title('最后一次仿真中 H 的分布');
xlabel('Re(H)'); ylabel('Im(H)');
legend show;
hold off;

%% 4. 绘制等效二元信道的错误图案
figure;
for i = 1:length(sigma_n_sq_vec)
    subplot(2, 5, i);
    bit_stream_in = bit_stream_in_all{i};
    bit_stream_out = bit_stream_out_all{i};
    error_pattern = (bit_stream_in ~= bit_stream_out);
    stem(error_pattern(1:100), 'filled');
    title(sprintf('sigma_n^2=%.2e', sigma_n_sq_vec(i)));
    xlabel('比特索引 (1:100)');
    ylabel('错误 (1=错, 0=对)');
    ylim([-0.1, 1.1]);
    grid on;
end
