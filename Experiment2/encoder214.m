% (2,1,4)卷积码编码
% 输入：待编码消息binstream，收尾方式tailing_mode（0不收尾，1收尾，2咬尾）
% 输出：编码后的消息encoded_binstream
function encoded_binstream = encoder214(binstream, tailing_mode)

    % 预处理
    binstream = binstream(:).'; % 确保是行向量
    if tailing_mode == 1
        binstream = [binstream zeros(1, 3)]; % 收尾 <-- 修改：4 => 3
    end
    
    buffer = zeros(4, 1);
    if tailing_mode == 2
        buffer(1:3) = binstream(end:-1:end-2);
    end

    % 卷积编码
    L = length(binstream);
    kernel = [1 1 0 1; 1 1 1 1]; % 多项式(15, 17)
    encoded_binstream = zeros(1, L*2, "uint8"); % 修改：预分配空间
    for i = 1:L
        buffer = [binstream(i); buffer(1:3)];
        encoded_binstream(i*2-1:i*2) = bitget(kernel * buffer, 1).'; % 修改：一次算完
    end
end
