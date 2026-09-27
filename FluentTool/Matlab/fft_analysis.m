function [f, Pxx] = fft_analysis(data, column_name, Fs)
% FFT_ANALYSIS 对指定监测点时序做 FFT
%
% 输入:
%   data        - read_case 返回的 table
%   column_name - 要分析的列名，例如 'P_x00_y-05_z00_P'
%   Fs          - 采样频率 [Hz]，若省略则自动根据 Time 列估算
%
% 输出:
%   f   - 频率向量 [Hz]
%   Pxx - 单边幅值谱
%
% 示例:
%   [f, Pxx] = fft_analysis(data, 'P_x00_y-05_z00_P');

    if ~istable(data)
        error('data 必须是 table');
    end
    if ~ismember(column_name, data.Properties.VariableNames)
        error('data 中不存在列: %s', column_name);
    end

    t = data.Time;
    x = data.(column_name);

    % 去掉 NaN
    valid = ~isnan(t) & ~isnan(x);
    t = t(valid);
    x = x(valid);

    if nargin < 3 || isempty(Fs)
        dt = mean(diff(t));
        Fs = 1 / dt;
        fprintf('自动估算采样频率: %.2f Hz\n', Fs);
    end

    N = length(x);
    if N < 2
        error('时序数据点不足，无法做 FFT');
    end

    % 去均值
    x = x - mean(x);

    % FFT
    X = fft(x);
    P2 = abs(X) / N;
    Pxx = P2(1:floor(N/2)+1);
    Pxx(2:end-1) = 2 * Pxx(2:end-1);

    f = Fs * (0:floor(N/2)) / N;
end
