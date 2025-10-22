clc; clear; close all;

% -----  参数  -----
L = 100;          % 序列长度
K = 10;           % 每个符号的重复次数
b = 0.8;          % 信道参数 b
rho = 0.9;        % 信道参数 rho
sigma_n_sq = 0.1; % 信道参数 sigma_n^2
opts.seed = 42;   % 设置种子


% -----  随机 QPSK 输入符号  -----
symbols = [1+0i, -1+0i, 0+1i, 0-1i];
idx = randi(4, L, 1);
U = symbols(idx);
U = U(:);

% -----  序列信道仿真  -----
[V, H] = seqcplxchan(U, K, b, rho, sigma_n_sq, opts);

% -----  可视化  -----
figure;
% 绘制 H 的实部，观察其时变特性
subplot(2, 1, 1);
plot(real(H));
title('等效信道增益 $h_i$ (实部) 序列');
xlabel('符号索引 $i$');
ylabel('$\mathrm{Re}(h_i)$');
grid on;
% V 的星座图 - 按输入符号分颜色
subplot(2, 1, 2);
colors = {'r', 'g', 'b', 'm'};
markers = {'o', 's', '^', 'd'};
labels = {'U=(1+1i)/√2', 'U=(1-1i)/√2', 'U=(-1+1i)/√2', 'U=(-1-1i)/√2'};
hold on;
for k = 1:length(symbols)
    U_k = symbols(k);
    idx_k = (U == U_k); 
    if any(idx_k)
        plot(real(V(idx_k)), imag(V(idx_k)), '.', 'Color', colors{k}, 'MarkerSize', 10);
        plot(real(U(idx_k)), imag(U(idx_k)), markers{k}, 'Color', colors{k}, 'MarkerSize', 6, 'LineWidth', 1.5);
    end
end 
title('接收信号 v_i 星座图 (按输入符号 u_i 分颜色)');
xlabel('实部');
ylabel('虚部');
axis equal;
grid on;
% 创建图例
legend_entries = {};
for k = 1:length(symbols)
    U_k = symbols(k);
    if any(U == U_k)
        legend_entries{end+1} = ['接收 V (' labels{k} ')'];
        legend_entries{end+1} = ['发送 U (' labels{k} ')'];
    end
end
if ~isempty(legend_entries)
    legend(legend_entries, 'Location', 'best');
end
hold off;
