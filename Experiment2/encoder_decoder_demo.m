% 测试硬判决
% (2,1,4)
binstream = randi([0,1], 1, 1000);
encoded_binstream = encoder214(binstream, 2);
decoded_binstream = decoder214_hard(encoded_binstream, 2);
all(binstream == decoded_binstream)
% (3,1,4)
binstream = randi([0,1], 1, 1000);
encoded_binstream = encoder314(binstream, 2);
decoded_binstream = decoder314_hard(encoded_binstream, 2);
all(binstream == decoded_binstream)

% 测试软判决
p = [0.99, 0.01, 0.01, 0.99]; % 信道转移概率 0->0,0->1,1->0,1->1
% (2,1,4)
binstream = randi([0,1], 1, 1000);
encoded_binstream = encoder214(binstream, 2);
pstream = p(2.^encoded_binstream + encoded_binstream + 1); % 计算似然比
llrstream = log(pstream ./ (1 - pstream)); % 转化为对数似然比
decoded_binstream = decoder214_soft(llrstream, 2);
all(binstream == decoded_binstream)
% (3,1,4)
binstream = randi([0,1], 1, 1000);
encoded_binstream = encoder314(binstream, 2);
pstream = p(2.^encoded_binstream + encoded_binstream + 1); % 计算似然比
llrstream = log(pstream ./ (1 - pstream)); % 转化为对数似然比
decoded_binstream = decoder314_soft(llrstream, 2);
all(binstream == decoded_binstream)
