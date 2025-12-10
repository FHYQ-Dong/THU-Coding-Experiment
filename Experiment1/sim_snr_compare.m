% --- sim_snr_compare.m ---
%
% 目的: 仿真并验证 seqcplxchan 和 cplxchan 之间的 SNR 关系
% 依赖: cplxchan.m, seqcplxchan.m
%
clear; clc; close all;

% -----  仿真参数  -----
L_long     = 10000; % 序列信道仿真长度
K          = 20;    % 重复次数
b          = 0.7;
sigma_n_sq = 0.1;

seed     = 42;    % 固定种子以便 cplxchan 和 seqcplxchan 内部噪声序列对齐
rho_slow = 0.999; % 慢衰落
rho_fast = 0.001; % 快衰落

fprintf('-----  仿真参数  -----\n');
fprintf('K = %d, b = %.2f, sigma_n^2 = %.2f\n', K, b, sigma_n_sq);

% 运行两次仿真
run_simulation(L_long, K, b, rho_slow, sigma_n_sq, seed, '慢衰落 (rho=0.999)');
run_simulation(L_long, K, b, rho_fast, sigma_n_sq, seed, '快衰落 (rho=0.001)');


%% -----  仿真主函数  -----
function run_simulation(L, K, b, rho, sigma_n_sq, seed, title_str)
    fprintf('\n-----  正在运行: %s  -----\n', title_str);

    % 固定种子以便 cplxchan 和 seqcplxchan 内部噪声序列对齐
    opts.seed = seed;
    
    % ----- 序列信道 (seqcplxchan) 仿真 -----
    % 生成输入信号 (归一化功率 Pu = 1)
    U_seq = (randi([0 1], L, 1) * 2 - 1 + 1i * (randi([0 1], L, 1) * 2 - 1)) / sqrt(2);
    P_u = mean(abs(U_seq).^2);
    % 仿真
    [V_seq, H_seq] = seqcplxchan(U_seq, K, b, rho, sigma_n_sq, opts);
    % 计算序列信道的信号和噪声
    S_seq = H_seq .* U_seq;
    N_seq = V_seq - S_seq;
    P_S_seq_sim = mean(abs(S_seq).^2);
    P_N_seq_sim = mean(abs(N_seq).^2);
    SNR_seq_sim = P_S_seq_sim / P_N_seq_sim;
    SNR_seq_sim_dB = 10 * log10(SNR_seq_sim);

    % ----- 内核信道 (cplxchan) 仿真 -----
    % 准备 cplxchan 的输入
    X_core = repelem(U_seq / sqrt(K), K, 1);
    P_x = mean(abs(X_core).^2); % Px 应该是 Pu / K
    opts.seed = 42; 
    % 仿真
    [Y_core, A_core] = cplxchan(X_core, b, rho, sigma_n_sq, opts);
    % 计算内核信道的信号和噪声
    S_core = A_core .* X_core;
    N_core = Y_core - S_core;
    P_S_core_sim = mean(abs(S_core).^2);
    P_N_core_sim = mean(abs(N_core).^2);
    SNR_core_sim = P_S_core_sim / P_N_core_sim;
    SNR_core_sim_dB = 10 * log10(SNR_core_sim);
    
    % ----- 结果分析与理论值对比 -----
    % 理论噪声功率 (P_N_thy)
    P_N_thy = sigma_n_sq / 2;
    % 理论增益 (G_thy)
    % G = K * E[|h|^2] / E[|a|^2]
    % 我们用仿真的均值 E_H_sq_sim 和 E_A_sq_sim 来近似期望
    E_H_sq_sim = mean(abs(H_seq).^2);
    E_A_sq_sim = mean(abs(A_core).^2);
    G_thy_approx = K * E_H_sq_sim / E_A_sq_sim;
    % 仿真增益 (G_sim)
    G_sim = SNR_seq_sim / SNR_core_sim;
    % 打印结果
    fprintf('输入功率: Pu=%.4f, Px=%.4f (Pu/K=%.4f)\n', P_u, P_x, P_u/K);
    fprintf('-------------------------------------------\n');
    fprintf('              | 内核 (cplxchan) | 序列 (seqcplxchan)\n');
    fprintf('-------------------------------------------\n');
    fprintf('噪声功率 (P_N) |    %.6f   |    %.6f\n', P_N_core_sim, P_N_seq_sim);
    fprintf('理论 P_N      |    %.6f   |    %.6f\n', P_N_thy, P_N_thy);
    fprintf('-------------------------------------------\n');
    fprintf('信号功率 (P_S) |    %.6f   |    %.6f\n', P_S_core_sim, P_S_seq_sim);
    fprintf('SNR (dB)      |    %.2f dB      |    %.2f dB\n', SNR_core_sim_dB, SNR_seq_sim_dB);
    fprintf('-------------------------------------------\n');
    fprintf('SNR 增益 (dB): %.2f dB\n', 10*log10(G_sim));
    fprintf('理论增益 G:    %.4f (K * E[|h|^2] / E[|a|^2])\n', G_thy_approx);
    fprintf('仿真增益 G:    %.4f (SNR_seq / SNR_core)\n', G_sim);
    fprintf('K 值:          %.4f\n', K);
end
