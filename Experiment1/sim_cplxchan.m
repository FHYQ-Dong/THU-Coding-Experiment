clc; clear; close all;

% -----  参数  -----
N = 100;          % 符号数量
b = 0.7;          % 信道参数 b
rho = 0.996;        % 信道参数 rho
sigma_n_sq = 0.1; % 信道参数 sigma_n^2
seed = 42;

% -----  随机 QPSK 输入符号  -----
symbols = [1+0i, -1+0i, 0+1i, 0-1i];
idx = randi(4, N, 1);
X = symbols(idx);
X = X(:);

% -----  复采样信道仿真  -----
opts.seed = seed;
[Y, A] = cplxchan(X, b, rho, sigma_n_sq, opts);

% -----  可视化  -----
figure;
% A 的实部
subplot(2, 1, 1);
plot(real(A), "DisplayName","Re(a_i)");
hold on;
plot(imag(A), "DisplayName","Im(a_i)");
title('信道系数 a_i');
xlabel('符号索引 i');
ylabel('a_i')
grid on;
legend show;
hold off;

figure;
% Y 的星座图 - 按输入符号分颜色
colors = ['r', 'g', 'b', 'm'];
markers = ['o', 's', '^', 'd'];
labels = {'X=1+0i', 'X=-1+0i', 'X=0+1i', 'X=0-1i'};
hold on;
for k = 1:length(symbols)
    idx = (X == symbols(k)); 
    if any(idx)
        plot(real(Y(idx)), imag(Y(idx)), '.', 'Color', colors(k), 'MarkerSize', 8);
        plot(real(X(idx)), imag(X(idx)), markers(k), 'Color', colors(k), 'MarkerSize', 6, 'LineWidth', 1.5);
    end
end 
title('接收信号 y_i 星座图 (按输入符号 x_i 分颜色)');
xlabel('实部');
ylabel('虚部');
axis equal;
grid on;
% 创建图例
legend_entries = {};
for k = 1:length(symbols)
    if any(X == symbols(k))
        legend_entries{end+1} = ['接收 Y (' labels{k} ')'];
        legend_entries{end+1} = ['发送 X (' labels{k} ')'];
    end
end
legend(legend_entries, 'Location', 'best');
hold off;
