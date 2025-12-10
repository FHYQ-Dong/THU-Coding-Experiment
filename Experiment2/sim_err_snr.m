% 统计误比特率与信噪比的关系，给出 10 个典型的误码图案

clc; clear; close all;
rng(093);

% 生成信号
N = 1e5;
binstream = randi([0 1], 1, N);
encoded_214 = encoder214(binstream, 1);
encoded_314 = encoder314(binstream, 1);
Es = 1;

% 信噪比设置
snr_db = linspace(-10, 20, 10); % 信噪比范围
snr = 10.^(snr_db / 10);
ber_214 = zeros(1, length(snr));
ber_314 = zeros(1, length(snr));
biterr_214 = zeros(length(snr), N);
biterr_314 = zeros(length(snr), N);

% 信道参数
K = 10;            % 每个 u_i 的重复次数
M = 1;             % 比特/符号
codec_mode = 1;    % 编码模式
b = 0.7;
rho = 0.996;
% sigma_n_sq = 0.01; % 噪声功率
% 导频配置
use_pilot = true;
pilot_config.interval = 3; % 1 导频, 2 数据
pilot_config.symbol = 2 + 0j;

fprintf("结果\nSNR\tBER_214\tBER_314\n------------------------------\n");
for cnt1 = 1:length(snr)
    sigma_n_sq = Es / snr(cnt1); % 计算噪声功率
    [chan_U_214, is_data_mask_214] = bit2sym(encoded_214, M, codec_mode, use_pilot, pilot_config);
    [chan_U_314, is_data_mask_314] = bit2sym(encoded_314, M, codec_mode, use_pilot, pilot_config);
    [chan_V_214, H_true_214] = seqcplxchan(chan_U_214, K, b, rho, sigma_n_sq);
    [chan_V_314, H_true_314] = seqcplxchan(chan_U_314, K, b, rho, sigma_n_sq);
    [chan_bitout_214, H_est_214] = sym2bit(chan_V_214, M, codec_mode, use_pilot, pilot_config);
    [chan_bitout_314, H_est_314] = sym2bit(chan_V_314, M, codec_mode, use_pilot, pilot_config);
    decoded_214 = decoder214_hard(chan_bitout_214, 1);
    decoded_314 = decoder314_hard(chan_bitout_314, 1);
    ber_214(cnt1) = sum(binstream ~= decoded_214) / length(binstream);
    ber_314(cnt1) = sum(binstream ~= decoded_314) / length(binstream);
    biterr_214(cnt1, :) = binstream ~= decoded_214;
    biterr_314(cnt1, :) = binstream ~= decoded_314;
    fprintf('%.2f\t%.5f\t%.5f\n', snr_db(cnt1), ber_214(cnt1), ber_314(cnt1));
end

% 绘制误比特率与信噪比的关系
figure;
semilogy(snr_db, ber_214, '-o', 'DisplayName', 'BER 214');
hold on;
semilogy(snr_db, ber_314, '-s', 'DisplayName', 'BER 314');
grid on;
xlabel('信噪比 (dB)');
ylabel('误比特率 (BER)');
title('误比特率与信噪比的关系 (收尾)');
legend('show');

% 绘制典型误码图案
num_patterns = 10;
figure;
for i = 1:num_patterns
    subplot(5, 2, i);
    stem([biterr_214(i, 1:100), biterr_214(i, end-99:end)], 'filled');
    title(['SNR = ' num2str(snr_db(i)) ' dB (214 码，收尾)']);
    xlabel('比特位置 (1:100, N-99:N)');
    ylabel('误码');
    ylim([-0.1 1.1]);
end
figure;
for i = 1:num_patterns
    subplot(5, 2, i);
    stem([biterr_314(i, 1:100), biterr_314(i, end-99:end)], 'filled');
    title(['SNR = ' num2str(snr_db(i)) ' dB (314 码，收尾)']);
    xlabel('比特位置 (1:100, N-99:N)');
    ylabel('误码');
    ylim([-0.1 1.1]);
end
