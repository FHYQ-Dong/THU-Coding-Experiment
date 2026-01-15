clear; clc; close all;

%% 1. 参数设置
correct_key = 666666;       % 正确密钥
wrong_key   = 666667;       % 错误的解密密钥 (只差 1，测试敏感性)
image_name  = 'lena_128_bw.bmp';

%% 2. 准备三张原始图片
% --- P1: Lena (信息丰富) ---
try
    p1 = imread(image_name);
    if size(p1, 3) == 3, p1 = rgb2gray(p1); end
catch
    warning('未找到图片，生成渐变图代替');
    [x, y] = meshgrid(1:128, 1:128);
    p1 = uint8((x+y)/2);
end
[H, W] = size(p1);

% --- P2: 全白 (信息单一) ---
p2 = 255 * ones(H, W, 'uint8');

% --- P3: 全黑 (信息单一) ---
p3 = zeros(H, W, 'uint8');

% 将图片放入 cell 方便循环处理
org_imgs = {p1, p2, p3};
titles   = {'Lena', 'All White', 'All Black'};

%% 3. 核心处理循环
% 存储结果用于画图
encrypted_imgs = cell(1, 3);
wrong_dec_imgs = cell(1, 3);

for i = 1:3
    fprintf('正在处理图片 %d: %s...\n', i, titles{i});
    
    current_img = org_imgs{i};
    prefix = sprintf('temp_img%d', i);
    
    % Step A: 图像 -> 明文比特流文件
    plain_file = [prefix, '_plain.txt'];
    img2file(current_img, plain_file);
    
    % Step B: 加密 (使用正确密钥)
    enc_file = [prefix, '_enc.txt'];
    encrypt_advanced(plain_file, enc_file, correct_key);
    
    % Step C: 读取加密后的样子 (作为图片查看)
    % 注意：加密文件包含 '0'/'1' 字符串，需转回像素矩阵
    encrypted_imgs{i} = file2img(enc_file, H, W);
    
    % Step D: 解密 (使用错误密钥!) -> 得到另外三张图
    wrong_dec_file = [prefix, '_wrong_dec.txt'];
    % 这里的输入是 Step B 产生的密文文件
    decrypt_advanced(enc_file, wrong_dec_file, wrong_key);
    
    % Step E: 读取错误解密后的样子
    wrong_dec_imgs{i} = file2img(wrong_dec_file, H, W);
end

%% 4. 绘制 3x3 结果图
h_fig = figure('Name', 'Encryption & Key Sensitivity Test', 'Color', 'w');
set(h_fig, 'Position', [100, 100, 1200, 900]); % 大窗口

% 遍历每一列 (对应一张原图)
for col = 1:3
    % 第一行: 原始图片
    subplot(3, 3, col);
    imshow(org_imgs{col});
    title(['Original: ', titles{col}], 'FontSize', 11);
    
    % 第二行: 加密后的图片 (应该全是噪声)
    subplot(3, 3, col + 3);
    imshow(encrypted_imgs{col});
    title('Encrypted', 'FontSize', 11);
    
    % 第三行: 错误密钥解密 (应该也是噪声，且与第二行不同)
    subplot(3, 3, col + 6);
    imshow(wrong_dec_imgs{col});
    title(['Decrypted with Wrong Key (', num2str(wrong_key), ')'], 'FontSize', 11, 'Color', 'r');
end

sgtitle(['Encryption System Verification (Correct Key: ', num2str(correct_key), ')'], 'FontSize', 16, 'FontWeight', 'bold');

% 清理临时文件
delete('temp_img*.txt');

%% === 辅助函数 ===

% 将图像矩阵转换为 '0'/'1' 文本文件 (适配你的加密接口)
function img2file(img, filename)
    % 转置是为了按行优先顺序读取，符合常规习惯
    % dec2bin 生成的是字符矩阵，需要转置并拉直
    bin_mat = dec2bin(img', 8); 
    bin_str = bin_mat';        
    bin_str = bin_str(:)';     
    
    fid = fopen(filename, 'w');
    fwrite(fid, bin_str, 'char');
    fclose(fid);
end

% 将 '0'/'1' 文本文件还原为图像矩阵 (用于可视化)
function img = file2img(filename, H, W)
    fid = fopen(filename, 'r');
    if fid == -1, error('文件未找到'); end
    bin_str = fread(fid, '*char')';
    fclose(fid);
    
    % 你的加密算法会添加 padding (10...0)
    % 我们只取前 H*W*8 个比特来还原图像内容
    num_bits_needed = H * W * 8;
    
    if length(bin_str) < num_bits_needed
        % 如果长度不够(极少见)，补0
        bin_str = [bin_str, repmat('0', 1, num_bits_needed - length(bin_str))];
    else
        % 截断多余的 Padding
        bin_str = bin_str(1:num_bits_needed);
    end
    
    % 重塑: 8行 N列 -> 转置 -> bin2dec -> 重塑为 HxW
    % 注意：这里要跟 img2file 的逻辑完全逆向
    bin_mat = reshape(bin_str, 8, [])'; 
    data = uint8(bin2dec(bin_mat));
    
    % img2file 中是 img'，所以这里还原出来后也要转置回去
    img = reshape(data, W, H)'; 
end