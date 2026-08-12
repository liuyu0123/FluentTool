function batch_process(results_root)
% BATCH_PROCESS 批量读取 Results 下所有工况并做简单可视化
%
% 输入:
%   results_root - Results 目录路径，默认 '../Results'
%
% 示例:
%   batch_process('../Results');

    if nargin < 1 || isempty(results_root)
        results_root = '../Results';
    end

    case_dirs = dir(fullfile(results_root, '*Hz_*mm_*ms'));
    case_dirs = case_dirs([case_dirs.isdir]);

    fprintf('发现 %d 个工况\n', length(case_dirs));

    figure('Position', [100 100 1200 400]);
    hold on;

    for i = 1:length(case_dirs)
        case_path = fullfile(results_root, case_dirs(i).name);
        try
            [data, meta, coords] = read_case(case_path);
            fprintf('[%d] %s: %d 行数据\n', i, case_dirs(i).name, height(data));

            % 示例：画出第一个监测点的压力时序
            var_names = data.Properties.VariableNames;
            % 找到第一个非 Time 的压力列
            p_cols = var_names(startsWith(var_names, 'P_') & endsWith(var_names, '_P'));
            if ~isempty(p_cols)
                col = p_cols{1};
                plot(data.Time, data.(col), 'DisplayName', case_dirs(i).name);
            end
        catch ME
            warning('读取 %s 失败: %s', case_dirs(i).name, ME.message);
        end
    end

    xlabel('Time [s]');
    ylabel('Pressure [Pa]');
    title('所有工况第一个监测点压力时序');
    legend('Location', 'bestoutside');
    grid on;
    hold off;
end
