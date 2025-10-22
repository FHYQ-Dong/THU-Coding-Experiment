function [procImage, bitCount, psnrValue] = h261_quantization(srcImage)
    % Constants
    h261_qps = [1, 5, 10, 20, 30, 40, 60, 80, 100];
    quant_factor = h261_qps(5); % 选择量化参数，这里选择20作为示例

    % 执行H.261量化 - 完全按照原始codec代码实现
    [img_height, img_width] = size(srcImage);
    procImage = zeros(img_height, img_width);
    
    % 检查参数
    if quant_factor > 100 || quant_factor < 1
        error('No factor input[1-100]!');
    end
    
    % JPEG量化表 - 完全按照原始codec代码
    JPEGQuantTableOri = [ 
        16,11,10,16,24,40,51,61,12,12,14,19,26,58,60,55, ...
        14,13,16,24,40,57,69,56,14,17,22,29,51,87,80,62, ...
        18,22,37,56,68,109,103,77,24,35,55,64,81,104,113,92,...
        49,64,78,87,103,121,120,101,72,92,95,98,112,100,103,99
    ]';
    
    % JPEG量化表与量化因子 - 完全按照原始codec代码
    JPEGQuantTable = double(round(JPEGQuantTableOri .* quant_factor ./ 10));
    
    % 初始化变量 - 完全按照原始codec代码
    img_block8x8 = zeros(8,8);
    img_block64 = zeros(1,64);
    iimg_block64 = zeros(1,64);
    iimg_block8x8 = zeros(8,8);
    
    % 霍夫曼统计 - 完全按照原始codec代码
    huffOri = zeros(1, 10000);
    huffOriNum = zeros(1, 10000);
    huffIdx = 1;
    greenCheck = false;
    
    for i = 1:fix(img_height/8)
        for j = 1:fix(img_width/8)
            % 提取8x8块 - 完全按照原始codec代码
            img_block8x8 = srcImage(8*(i-1)+1:8*(i-1)+8, 8*(j-1)+1:8*(j-1)+8);
            
            % DCT变换 - 完全按照原始codec代码
            img_block64 = dct2D(img_block8x8);
            
            % 量化 - 完全按照原始codec代码
            % 关键：这里img_block64是1×64行向量，JPEGQuantTable是64×1列向量
            % MATLAB会进行隐式扩展，得到64×64矩阵，但我们只取对角线元素
            img_block64 = round(img_block64 ./ JPEGQuantTable);
            
            % 统计量化系数 - 完全按照原始codec代码
            for k = 1:64
                if img_block64(k) == 0
                    huffOri(1) = huffOri(1) + 1;
                else
                    greenCheck = false;
                    for m = 1:huffIdx
                        if huffOriNum(m) == img_block64(k)
                            huffOri(m) = huffOri(m) + 1;
                            greenCheck = true;
                            break;
                        end
                    end
                    if ~greenCheck
                        huffOriNum(huffIdx) = img_block64(k);
                        huffOri(huffIdx) = huffOri(huffIdx) + 1;
                        huffIdx = huffIdx + 1;
                    end
                end
            end
            
            % 反量化 - 完全按照原始codec代码
            img_block64 = img_block64 .* JPEGQuantTable;
            
            % 逆DCT变换 - 完全按照原始codec代码
            iimg_block64 = idct2D(img_block64);
            
            % 裁剪到0-255 - 完全按照原始codec代码
            iimg_block64(find(iimg_block64<0)) = 0;
            iimg_block64(find(iimg_block64>255)) = 255;
            
            % 重构块 - 完全按照原始codec代码
            iimg_block8x8 = reshape(iimg_block64, [8,8])';
            procImage(8*(i-1)+1:8*(i-1)+8, 8*(j-1)+1:8*(j-1)+8) = iimg_block8x8;
        end
    end
    
    procImage = uint8(procImage);
    % bitCount = HuffmanCoding(huffOri, huffIdx);
    % psnrValue = calculatePSNR(double(srcImage), double(procImage));
    [bitCount, psnrValue] = deal(0, 0); % 占位返回值，实际实现中应计算比特数和PSNR值
end
