clc; clear; close all;

test_image = imread('./lena_128_bw.bmp');

%% ----------  量化  ----------
quant_factor = 10;
quant_image = h261_quantization(test_image, quant_factor);


%% ----------  VLC编码  ----------
escape_count = 5;
encoded_bits_single = encode_huffman(quant_image, 'single', escape_count);
% encoded_bits_double = encode_huffman(quant_image, 'double', escape_count);
disp(['单精度编码比特数: ', num2str(length(encoded_bits_single))]);
% disp(['双精度编码比特数: ', num2str(length(encoded_bits_double))]);

% VLC参数
vlc_sliceOption = 1;
vlc_slice_start_code = '000011110000111100001111';
[num_vlc1, code_vlc1] = encode_vlc1('huff_table1.txt', vlc_sliceOption, test_image, quant_image, vlc_slice_start_code); % VLC单符号编码
% [num_vlc2_1, num_vlc2_2, code_vlc2] = encode_vlc2('huff_table2.txt', vlc_sliceOption, test_image, quant_image, vlc_slice_start_code); % VLC双符号编码

%% ----------  信道  ----------
% 信道参数
K = 10;            % 每个 u_i 的重复次数
M = 1;             % 比特/符号 (M=2, QPSK)
codec_mode = 0;    % 编码模式
b = 0.7;
rho = 0.996;
sigma_n_sq = 0.01;
opts.seed = 42;

% 导频配置
use_pilot = true;
pilot_config.interval = 3; % 1 导频, 2 数据
pilot_config.symbol = 2 + 0j;

% --- 生成比特流 ---
vlc1_binfile = fopen('vlc1_bin.txt', 'r');
vlc_bitstream = fgetl(vlc1_binfile);
vlc_bitstream = vlc_bitstream - '0';
fclose(vlc1_binfile);

extra_length = M - mod(length(vlc_bitstream), M);
encoded_bits = zeros(length(vlc_bitstream) + extra_length, 1);
encoded_bits(1:length(vlc_bitstream)) = vlc_bitstream;
[U_data, is_data_mask] = bit2sym(encoded_bits, M, codec_mode, use_pilot, pilot_config);
[V_data, H_true] = seqcplxchan(U_data, K, b, rho, sigma_n_sq, opts);
[C, B] = constellation_map(M, codec_mode); % 获取星座图

figure;
scatter(real(V_data), imag(V_data), 'b.', 'DisplayName', 'Received Symbols');
hold on;

B_text = num2str(B');
plot(real(C), imag(C), 'ro', 'DisplayName', 'Constellation', 'MarkerFaceColor', 'r', 'MarkerSize',10);
text(real(C)-0.05*M, imag(C)+0.2, B_text, 'VerticalAlignment','bottom','HorizontalAlignment','right','FontSize',12);
plot(real(pilot_config.symbol), imag(pilot_config.symbol), 'g^', 'MarkerSize', 10, 'MarkerFaceColor', 'g', 'DisplayName', 'Pilot Symbol');
legend show;
axis equal;
title('符号星座图与接收符号');
hold off;

[bit_stream_out, H_estimated] = sym2bit(V_data, M, codec_mode, use_pilot, pilot_config);
U_error = bit2sym(bit_stream_out, M, codec_mode, false, struct());
U_error = (U_data(is_data_mask) ~= U_error);

    % --- 7. 计算真实的信噪比 (用于绘图) ---
    S_seq_power = mean(abs(H_true .* U_data).^2);
    N_eff = V_data - (H_true .* U_data);
    N_seq_power = mean(abs(N_eff).^2);
    SNR = 10*log10(S_seq_power / N_seq_power);

num_bit_errors = sum(encoded_bits ~= bit_stream_out);
disp(['符号错误数: ', num2str(sum(U_error))]);
disp(['符号错误率: ', num2str(10*log10(sum(U_error) / length(U_error))), ' dB']);
disp(['比特错误数: ', num2str(num_bit_errors)]);
disp(['比特错误率: ', num2str(10*log10(num_bit_errors / length(encoded_bits))), ' dB']);
disp(['真实信噪比: ', num2str(SNR), ' dB']);

% 写入文件
chan_binfile = fopen('chan1_bin.txt', 'wb');
% chan_binfile = fopen('chan2_bin.txt', 'wb');
fwrite(chan_binfile, bit_stream_out + '0', 'uint8');
fclose(chan_binfile);

%% ----------  VLC解码  ----------
rec_vlc1_image = decode_vlc1('chan1_bin.txt', num_vlc1, code_vlc1, vlc_sliceOption, test_image, quant_image, vlc_slice_start_code);
% rec_vlc2_image = decode_vlc2('chan2_bin.txt', num_vlc2_1, num_vlc2_2, code_vlc2, vlc_sliceOption, test_image, quant_image, vlc_slice_start_code);


%% ----------  反量化  ----------
rec_image = h261_dequantization(rec_vlc1_image, quant_factor);
% rec_image = h261_dequantization(rec_vlc2_image);
figure;
imshow(rec_image,[]);
title('重构图像');
