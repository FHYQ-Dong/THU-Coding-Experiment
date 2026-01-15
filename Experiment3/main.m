clear; clc; close all;

%% 1. 基础参数
image_name = 'lena_128_bw.bmp'; 
quant_factor = 50;            
escape_count = 50;            
vlc_sliceOption = 1;          
vlc_slice_start_code = '000011110000111100001111'; 
security_key = "See you tomorrow, Cyrene."; 

% === 信道编码参数 ===
CONV_BLOCK_SIZE = 500; % 块长
TAILING_MODE = 1;      % 收尾模式

% === SNR 扫描范围 ===
snr_range = -8:2:12; 
psnr_curve_enc = zeros(size(snr_range)); % 加密方案的 PSNR
psnr_curve_raw = zeros(size(snr_range)); % 不加密方案的 PSNR

%% 2. 信源编码 (公共部分)
try
    srcImage = imread(image_name);
    if size(srcImage, 3) == 3, srcImage = rgb2gray(srcImage); end
catch
    srcImage = uint8(randi([0, 255], 256, 256));
end
srcImage = double(srcImage);

fprintf('=== 发送端处理 ===\n');
% 2.1 JPEG 量化 & Huffman
quant_image = jpeg_quantization(srcImage, quant_factor);
encode_huffman(quant_image, 'single', escape_count); 
[num_vlc1, code_vlc1] = encode_vlc1('huff_table1.txt', vlc_sliceOption, srcImage, quant_image, vlc_slice_start_code);

% 2.2 读取原始明文流 (这是不加密方案的输入，也是加密方案的明文)
fid = fopen('vlc1_bin.txt', 'r'); 
plain_char_stream = fread(fid, '*char')'; 
fclose(fid);
% 转为数值向量 [0, 1, ...]
bits_raw = plain_char_stream - '0'; 

% 2.3 加密处理 (仅加密方案使用)
encrypt_advanced('vlc1_bin.txt', 'encrypted_data.bin', security_key);
fid = fopen('encrypted_data.bin', 'r'); 
cipher_char_stream = fread(fid, '*char')'; 
fclose(fid);
bits_enc = cipher_char_stream - '0';

%% 3. 信道编码 (Channel Coding)
% 我们需要分别对 "bits_raw" (不加密) 和 "bits_enc" (加密) 进行信道编码

fprintf('正在执行 (3,1,4) 卷积编码...\n');

% --- 辅助函数：执行分块卷积编码 ---
function stream_out = perform_channel_coding(input_bits, block_size, tailing_mode)
    total = length(input_bits);
    num_blks = ceil(total / block_size);
    pad_len = num_blks * block_size - total;
    padded = [input_bits(:).', zeros(1, pad_len)];
    stream_out = [];
    for b = 1:num_blks
        chunk = padded((b-1)*block_size+1 : b*block_size);
        stream_out = [stream_out, encoder314(chunk, tailing_mode)];
    end
end

% 3.1 编码不加密链路
encoded_stream_raw = perform_channel_coding(bits_raw, CONV_BLOCK_SIZE, TAILING_MODE);
% 3.2 编码加密链路
encoded_stream_enc = perform_channel_coding(bits_enc, CONV_BLOCK_SIZE, TAILING_MODE);

%% 4. SNR 扫描仿真
fprintf('\n=== 开始信道仿真 (SNR 扫描) ===\n');

% 计算信道编码后的块长 (输入块长 + 尾比特) * 3
coded_block_len = (CONV_BLOCK_SIZE + 3) * 3;

for i = 1:length(snr_range)
    curr_snr = snr_range(i);
    fprintf('Simulating SNR = %2d dB... ', curr_snr);
    
    % ==========================================
    %          链路 A: 有加密 (With Encryption)
    % ==========================================
    
    % A.1 信道 (AWGN)
    rx_soft_enc = awgn_channel_soft(encoded_stream_enc, curr_snr);
    
    % A.2 信道译码 (Soft Viterbi)
    decoded_bits_enc_all = [];
    num_blocks_enc = length(rx_soft_enc) / coded_block_len;
    
    for b = 1:num_blocks_enc
        chunk_soft = rx_soft_enc((b-1)*coded_block_len+1 : b*coded_block_len);
        decoded_bits_enc_all = [decoded_bits_enc_all, decoder314_soft(chunk_soft, TAILING_MODE)];
    end
    % 截断 Padding
    decoded_bits_enc_valid = decoded_bits_enc_all(1:length(bits_enc));
    
    % A.3 解密
    % 写入文件供解密器读取
    fid = fopen('temp_rx_enc.bin', 'w'); fwrite(fid, char(decoded_bits_enc_valid+'0'), 'char'); fclose(fid);
    decrypt_advanced('temp_rx_enc.bin', 'chan_out_enc.txt', security_key);
    
    % A.4 信源解码 & 重建
    psnr_A = 0;
    rec_img_A = ones(size(srcImage))*255; % 默认全白，表示失败
    try
        rec_vlc_A = decode_vlc1('chan_out_enc.txt', num_vlc1, code_vlc1, vlc_sliceOption, srcImage, quant_image, vlc_slice_start_code);
        rec_img_A = jpeg_dequantization(rec_vlc_A, quant_factor);
        mse = mean((srcImage(:) - double(rec_img_A(:))).^2);
        if mse==0, psnr_A=100; else, psnr_A=10*log10(255^2/mse); end
    catch
        psnr_A = 0; % 解码失败
    end
    psnr_curve_enc(i) = psnr_A;
    
    % 读取解密后的比特流用于画误码图
    fid = fopen('chan_out_enc.txt', 'r'); 
    final_bits_A = fread(fid, '*char')' - '0'; 
    fclose(fid);

    % ==========================================
    %          链路 B: 无加密 (Without Encryption)
    % ==========================================
    
    % B.1 信道 (AWGN)
    % 注意：为了对比公平，可以重新生成噪声，或者使用相同种子。这里直接调用函数生成新的随机噪声。
    rx_soft_raw = awgn_channel_soft(encoded_stream_raw, curr_snr);
    
    % B.2 信道译码
    decoded_bits_raw_all = [];
    num_blocks_raw = length(rx_soft_raw) / coded_block_len;
    
    for b = 1:num_blocks_raw
        chunk_soft = rx_soft_raw((b-1)*coded_block_len+1 : b*coded_block_len);
        decoded_bits_raw_all = [decoded_bits_raw_all, decoder314_soft(chunk_soft, TAILING_MODE)];
    end
    % 截断 Padding -> 这就是最终给信源解码器的比特
    final_bits_B = decoded_bits_raw_all(1:length(bits_raw));
    
    % B.3 (无解密) 直接写入文件
    fid = fopen('chan_out_raw.txt', 'w'); fwrite(fid, char(final_bits_B+'0'), 'char'); fclose(fid);
    
    % B.4 信源解码 & 重建
    psnr_B = 0;
    rec_img_B = ones(size(srcImage))*255;
    try
        rec_vlc_B = decode_vlc1('chan_out_raw.txt', num_vlc1, code_vlc1, vlc_sliceOption, srcImage, quant_image, vlc_slice_start_code);
        rec_img_B = jpeg_dequantization(rec_vlc_B, quant_factor);
        mse = mean((srcImage(:) - double(rec_img_B(:))).^2);
        if mse==0, psnr_B=100; else, psnr_B=10*log10(255^2/mse); end
    catch
        psnr_B = 0;
    end
    psnr_curve_raw(i) = psnr_B;
    
    fprintf('PSNR(Enc)=%.2f, PSNR(Raw)=%.2f\n', psnr_A, psnr_B);

% ==========================================
    %          可视化 (Visualization)
    % ==========================================
    h_fig = figure('Visible', 'off'); % 后台绘图
    set(h_fig, 'Position', [100, 50, 1000, 800], 'Visible', 'on'); %以此增加高度以容纳3行
    sgtitle(['SNR = ' num2str(curr_snr) ' dB']);
    
    % --- 第一行：重建图像对比 ---
    subplot(3,2,1); 
    imshow(uint8(rec_img_A)); title(['[With Enc] PSNR=' num2str(psnr_A, '%.2f') 'dB']);
    
    subplot(3,2,2); 
    imshow(uint8(rec_img_B)); title(['[No Enc] PSNR=' num2str(psnr_B, '%.2f') 'dB']);
    
    % --- 【新增】第二行：解密前的错误图案 (密文误码 vs 信道误码) ---
    % 目的：展示卷积码输出后的残留误码，此时还没经过解密模块的“放大”
    
    % 链路 A (加密): 对比“接收到的密文”与“原始密文”
    len_cmp_pre_A = min(length(bits_enc), length(decoded_bits_enc_valid));
    diff_A_pre = decoded_bits_enc_valid(1:len_cmp_pre_A) ~= bits_enc(1:len_cmp_pre_A);
    
    subplot(3,2,3);
    stem(diff_A_pre, 'Color', [0.8 0.4 0]); % 使用深橙色区分
    title(['[With Enc] Ciphertext Errors (Before Decrypt)']);
    xlabel('Bit Index');
    
    % 链路 B (不加密): 对比“接收到的比特”与“原始比特”
    % 注：对于不加密链路，这里和第三行是一样的，因为没有解密步骤，但为了对比排版保留
    len_cmp_pre_B = min(length(bits_raw), length(final_bits_B));
    diff_B_pre = final_bits_B(1:len_cmp_pre_B) ~= bits_raw(1:len_cmp_pre_B);
    
    subplot(3,2,4);
    stem(diff_B_pre, 'Color', [0.8 0.4 0]);
    title(['[No Enc] Channel Errors (No Decrypt Step)']);
    xlabel('Bit Index');
    
    % --- 第三行：解密后的错误图案 (送入信源解码器的比特 vs 原始明文) ---
    % 注意：如果长度不一致(通常是因为padding移除逻辑)，取最小长度比较
    len_cmp = min(length(plain_char_stream), length(final_bits_A));
    diff_A = final_bits_A(1:len_cmp) ~= bits_raw(1:len_cmp);
    
    len_cmp_B = min(length(plain_char_stream), length(final_bits_B));
    diff_B = final_bits_B(1:len_cmp_B) ~= bits_raw(1:len_cmp_B);
    
    subplot(3,2,5);
    stem(diff_A, 'Color', 'b'); 
    title(['[With Enc] Final Bit Errors (BER=' num2str(mean(diff_A)*100, '%.2f') '%)']);
    xlabel('Bit Index');
    
    subplot(3,2,6);
    stem(diff_B, 'Color', 'b'); 
    title(['[No Enc] Final Bit Errors (BER=' num2str(mean(diff_B)*100, '%.2f') '%)']);
    xlabel('Bit Index'); 
    
    drawnow;
end

%% 5. 最终结果对比曲线
figure('Name', 'System Performance Comparison', 'Color', 'w');
plot(snr_range, psnr_curve_enc, 'r-^', 'LineWidth', 2, 'MarkerFaceColor', 'r');
hold on;
plot(snr_range, psnr_curve_raw, 'b-o', 'LineWidth', 2, 'MarkerFaceColor', 'b');
grid on;
xlabel('SNR (dB)');
ylabel('Reconstructed PSNR (dB)');
title('Performance Comparison: With vs Without Encryption');
legend('With Encryption', 'Without Encryption', 'Location', 'SouthEast');