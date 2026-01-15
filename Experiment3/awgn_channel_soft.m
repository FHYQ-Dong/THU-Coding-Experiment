function rx_soft = awgn_channel_soft(tx_bits, snr_db)
% AWGN_CHANNEL_SOFT BPSK调制 + AWGN信道 (输出软值)
% 输入: 
%   tx_bits: 0/1 比特向量
%   snr_db: 信噪比 (dB)
% 输出:
%   rx_soft: 接收到的含噪信号 (实数向量)

    % 1. BPSK 调制
    % 规则: 0 -> -1, 1 -> +1
    % 这必须与你的 decoder314_soft 内部的 state_transform 匹配
    % 你的 decoder 中: input 0 对应 state output -1
    tx_signal = zeros(size(tx_bits));
    tx_signal(tx_bits == 0) = -1;
    tx_signal(tx_bits == 1) =  1;
    
    % 2. 计算噪声功率
    % BPSK: Eb = 1 (Symbol Energy)
    % 码率 R = 1/3 (因为卷积码引入了冗余)
    % Es = R * Eb ? 
    % 注意: 在仿真中通常以 Symbol 为单位加噪。
    % SNR = Es / N0. 对于 BPSK, Es = 1.
    % noise_power = 10^(-snr_db/10); 
    
    % 工程修正：通常 SNR 指的是 Eb/N0。
    % 经过 1/3 编码后，每个 Symbol 携带 1/3 bit 信息。
    % 但为了简化对比 (保持与无编码系统一致的 SNR 定义)，
    % 我们这里定义的 SNR 为 "Channel SNR" (Es/N0)。
    % 这样对比才公平：同样的物理信道条件，加了编码效果如何。
    
    noise_power = 10^(-snr_db / 10);
    sigma = sqrt(noise_power / 2);
    
    % 3. 加噪
    noise = sigma * randn(size(tx_signal));
    rx_soft = tx_signal + noise;
end
