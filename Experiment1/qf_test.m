clc; clear; close all;

test_image = imread('./lena_128_bw.bmp');
logfile = fopen('qf_test_log.txt', 'w');

% qf = [5, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100];
% vlc_sliceOp = [0,1,2,3,4];
% escapec = [1,2,3,4,5];
% Mmode = [1,2,3];
qf = [70];
vlc_sliceOp = [1];
escapec = [4];
Mmode = [1];
huff_mode = 2;
for idx = 1:length(qf)
for jdx = 1:length(vlc_sliceOp)
for kdx = 1:length(escapec)
for mdx = 1:length(Mmode)
    quant_factor = qf(idx);
    vlc_sliceOption = vlc_sliceOp(jdx);
    escape_count = escapec(kdx);
    M = Mmode(mdx);
try
%% ----------  量化  ----------
% quant_factor = 10;
quant_image = jpeg_quantization(test_image, quant_factor);


%% ----------  VLC编码  ----------
% escape_count = 2;
if huff_mode == 1
encoded_bits_single = encode_huffman(quant_image, 'single', escape_count);
disp(['单精度编码比特数: ', num2str(length(encoded_bits_single))]);
else
encoded_bits_double = encode_huffman(quant_image, 'double', escape_count);
disp(['双精度编码比特数: ', num2str(length(encoded_bits_double))]);
end

% VLC参数
% vlc_sliceOption = 1;
vlc_slice_start_code = '000011110000111100001111';
if huff_mode == 1
[num_vlc1, code_vlc1] = encode_vlc1('huff_table1.txt', vlc_sliceOption, test_image, quant_image, vlc_slice_start_code); % VLC单符号编码
else
[num_vlc2_1, num_vlc2_2, code_vlc2] = encode_vlc2('huff_table2.txt', vlc_sliceOption, test_image, quant_image, vlc_slice_start_code); % VLC双符号编码
end

%% ----------  信道  ----------
% 信道参数
K = 10;            % 每个 u_i 的重复次数
% M = 1;             % 比特/符号
codec_mode = 1;    % 编码模式
b = 0.7;
% b = 0;
rho = 0.996;
% rho = 0;
sigma_n_sq = 0.01;
opts.seed = 42;

% 导频配置
use_pilot = true;
pilot_config.interval = 3; % 1 导频, 2 数据
pilot_config.symbol = 2 + 0j;

% --- 生成比特流 ---
if huff_mode == 1
vlc1_binfile = fopen('vlc1_bin.txt', 'r');
vlc_bitstream = fgetl(vlc1_binfile);
vlc_bitstream = vlc_bitstream - '0';
fclose(vlc1_binfile);
else
vlc2_binfile = fopen('vlc2_bin.txt', 'r');
vlc_bitstream = fgetl(vlc2_binfile);
vlc_bitstream = vlc_bitstream - '0';
fclose(vlc2_binfile);
end

extra_length = M - mod(length(vlc_bitstream), M);
encoded_bits = zeros(length(vlc_bitstream) + extra_length, 1);
encoded_bits(1:length(vlc_bitstream)) = vlc_bitstream;
[U_data, is_data_mask] = bit2sym(encoded_bits, M, codec_mode, use_pilot, pilot_config);
[V_data, H_true] = seqcplxchan(U_data, K, b, rho, sigma_n_sq, opts);
[C, B] = constellation_map(M, codec_mode); % 获取星座图

% figure;
% scatter(real(V_data), imag(V_data), 'b.', 'DisplayName', 'Received Symbols');
% hold on;

% B_text = num2str(B');
% plot(real(C), imag(C), 'ro', 'DisplayName', 'Constellation', 'MarkerFaceColor', 'r', 'MarkerSize',10);
% text(real(C)-0.05*M, imag(C)+0.2, B_text, 'VerticalAlignment','bottom','HorizontalAlignment','right','FontSize',12);
% plot(real(pilot_config.symbol), imag(pilot_config.symbol), 'g^', 'MarkerSize', 10, 'MarkerFaceColor', 'g', 'DisplayName', 'Pilot Symbol');
% legend show;
% axis equal;
% title('符号星座图与接收符号');
% hold off;

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
if huff_mode == 1
chan_binfile = fopen('chan1_bin.txt', 'wb');
else
chan_binfile = fopen('chan2_bin.txt', 'wb');
end
fwrite(chan_binfile, bit_stream_out + '0', 'uint8');
fclose(chan_binfile);

%% ----------  VLC解码  ----------
if huff_mode == 1
rec_vlc1_image = decode_vlc1('chan1_bin.txt', num_vlc1, code_vlc1, vlc_sliceOption, test_image, quant_image, vlc_slice_start_code);
else
rec_vlc2_image = decode_vlc2('chan2_bin.txt', num_vlc2_1, num_vlc2_2, code_vlc2, vlc_sliceOption, test_image, quant_image, vlc_slice_start_code);
end


%% ----------  反量化  ----------
if huff_mode == 1
rec_image = jpeg_dequantization(rec_vlc1_image, quant_factor);
else
rec_image = jpeg_dequantization(rec_vlc2_image, quant_factor);
end
figure;
imshow(rec_image,[]);
title(sprintf('重构图像, 量化因子=%d, psnr=%f dB', quant_factor, psnr(rec_image, test_image)));
catch
    disp(['quant_factor ', num2str(quant_factor), ', vlc_sliceOption ', num2str(vlc_sliceOption), ', escape_count ', num2str(escape_count), ' 出错!']);
    continue;
end

try
fprintf(logfile, '{"quant_factor": %d, "vlc_sliceOption": %d, "escape_count": %d, "M": %d, "psnr": %f dB, "snr": %f dB}\n', quant_factor, vlc_sliceOption, escape_count, M, psnr(rec_image, test_image), SNR);
fprintf('{"quant_factor": %d, "vlc_sliceOption": %d, "escape_count": %d, "M": %d, "psnr": %f dB, "snr": %f dB}\n', quant_factor, vlc_sliceOption, escape_count, M, psnr(rec_image, test_image), SNR);
catch
    disp(['quant_factor ', num2str(quant_factor), ', vlc_sliceOption ', num2str(vlc_sliceOption), ', escape_count ', num2str(escape_count), ', M ', num2str(M), ' 写入日志出错!']);
    continue;
end

end
end
end
end
fclose(logfile);