function [C, B] = constellation_map(M, codec_mode)
% constellation_map 定义 1, 2, 3 比特/符号的星座图
%
% 语法:
%   [C, B] = constellation_map(M, codec_mode)
%
% 输入:
%   M - (scalar) 每个符号的比特数 (1, 2, 或 3)
%   codec_mode - (scalar) 编码模式 (0: BPSK/PAM4/8-QAM, 1: ROTATED_BPSK/QPSK/8-PSK)
%
% 输出:
%   C - (1 x 2^M) 复数星座点 (行向量)
%   B - (M x 2^M) 比特映射矩阵 (每列对应一个星座点)

    %% -----  Constants  -----

    % 1 bit
    BPSK = 0;
    ROTATED_BPSK = 1;

    % 2 bits
    PAM4 = 0;
    QPSK = 1;
    
    % 3 bits
    QAM8 = 0;
    PSK8 = 1;

    %% -----  Mappings  -----

    % 1 bit: BPSK & ROTATED_BPSK
    BPSK_C = [cos(0)+1j*sin(0), cos(pi)+1j*sin(pi)];
    BPSK_B = [0 1];
    ROTATED_BPSK_C = [cos(pi/4)+1j*sin(pi/4), cos(pi*5/4)+1j*sin(pi*5/4)];
    ROTATED_BPSK_B = [0 1];

    % 2 bits: PAM4 & QPSK
    PAM4_C = [-0.75, -0.25, 0.25, 0.75];
    PAM4_B = [0 0 1 1;
              0 1 1 0];
    QPSK_C = [cos(pi/4)+1j*sin(pi/4), cos(pi*3/4)+1j*sin(pi*3/4), cos(pi*5/4)+1j*sin(pi*5/4), cos(pi*7/4)+1j*sin(pi*7/4)];
    QPSK_B = [0 0 1 1;
              0 1 1 0];

    % 3 bits: 8-QAM & 8-PSK
    QAM8_B = [0 0 0; 0 0 1; 0 1 0; 1 0 1; ...
              1 0 0; 0 1 1; 1 1 0; 1 1 1]'; % 转置为 M x 2^M (3x8)
    QAM8_C = [(0-1j)*sqrt(2)/(1+sqrt(3)), (1+1j)/sqrt(2), (1-1j)/sqrt(2), (0+1j)*sqrt(2)/(1+sqrt(3)), (-1-1j)/sqrt(2), (1+0*1j)*sqrt(2)/(1+sqrt(3)), (-1+0*1j)*sqrt(2)/(1+sqrt(3)), (-1+1j)/sqrt(2)];
    PSK8_B = [0 0 0; 0 0 1; 0 1 1; 0 1 0; ...
              1 1 0; 1 1 1; 1 0 1; 1 0 0]'; % 转置为 M x 2^M (3x8)
    PSK8_C = [cos(pi/8)+1j*sin(pi/8), cos(pi*3/8)+1j*sin(pi*3/8), cos(pi*5/8)+1j*sin(pi*5/8), cos(pi*7/8)+1j*sin(pi*7/8), cos(pi*9/8)+1j*sin(pi*9/8), cos(pi*11/8)+1j*sin(pi*11/8), cos(pi*13/8)+1j*sin(pi*13/8), cos(pi*15/8)+1j*sin(pi*15/8)];

    %% -----  选择 Mapping  -----
    switch M
        case 1
            if codec_mode == BPSK
                C = BPSK_C;
                B = BPSK_B;
            else if codec_mode == ROTATED_BPSK
                C = ROTATED_BPSK_C;
                B = ROTATED_BPSK_B;
            else
                error('不支持的编码模式。仅支持 BPSK 或 ROTATED_BPSK。');
            end
        end

        case 2
            if codec_mode == PAM4
                C = PAM4_C;
                B = PAM4_B;
            else if codec_mode == QPSK
                C = QPSK_C;
                B = QPSK_B;
            else
                error('不支持的编码模式。仅支持 PAM4 或 QPSK。');
            end
        end

        case 3
            if codec_mode == QAM8
                C = QAM8_C;
                B = QAM8_B;
            else if codec_mode == PSK8
                C = PSK8_C;
                B = PSK8_B;
            else
                error('不支持的编码模式。仅支持 8-QAM 或 8-PSK。');
            end
        end

        otherwise 
            error('不支持的比特/符号数 M=%d。仅支持 1, 2, 3。', M);

    end

end
