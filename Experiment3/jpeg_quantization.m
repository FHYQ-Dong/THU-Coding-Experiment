function procImage = jpeg_quantization(srcImage, quant_factor)
    if quant_factor > 100 || quant_factor < 1
        error('No factor input[1-100]!');
    end
    JPEGQuantTableOri = [ 
        16,11,10,16,24,40,51,61,12,12,14,19,26,58,60,55, ...
        14,13,16,24,40,57,69,56,14,17,22,29,51,87,80,62, ...
        18,22,37,56,68,109,103,77,24,35,55,64,81,104,113,92,...
        49,64,78,87,103,121,120,101,72,92,95,98,112,100,103,99
    ]';
    JPEGQuantTable = double(round(JPEGQuantTableOri .* quant_factor ./ 10));

    [img_height, img_width] = size(srcImage);
    procImage = zeros(img_height, img_width);
    
    for i = 1:fix(img_height/8)
        for j = 1:fix(img_width/8)
            img_block8x8 = srcImage(8*(i-1)+1:8*(i-1)+8, 8*(j-1)+1:8*(j-1)+8);
            img_block64 = dct2D(img_block8x8);
            img_block64 = round(img_block64 ./ JPEGQuantTable);
            img_block8x8 = reshape(img_block64, [8,8]);
            procImage(8*(i-1)+1:8*(i-1)+8, 8*(j-1)+1:8*(j-1)+8) = uint8(img_block8x8 + 128);
        end
    end
end
