% 卷积码编码演示
close all;
clear;
clc;

% tailing_mode = 2; % 收尾方式选择，0为不收尾，1为收尾，2为咬尾
% binstream = [0 1 0 0 1]; % 待编码的二进制串
% encoded_stream = encoder214(binstream, tailing_mode); % 编码结果

binstream = randi([0,1], 1, 100);
res1 = encoder214(binstream, 0);
res2 = encoder214_test(binstream, 0);
ok = res1 == res2;
disp(ok);
all(ok)