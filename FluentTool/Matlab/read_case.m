function [data, meta, coords] = read_case(result_dir)
% READ_CASE 读取单个工况的结果
%
% 输入:
%   result_dir - Results/CaseName 目录路径（字符串或 char）
%
% 输出:
%   data  - table，包含 Time 和各监测点物理量列
%   meta  - struct，来自 metadata.json
%   coords - table，监测点坐标
%
% 示例:
%   [data, meta, coords] = read_case('Results/40Hz_1mm_0.2ms');

    result_dir = char(result_dir);

    % 读取 CSV
    csv_file = fullfile(result_dir, [meta_case_name(result_dir), '.csv']);
    if ~isfile(csv_file)
        error('找不到 CSV 文件: %s', csv_file);
    end
    data = readtable(csv_file);

    % 读取 metadata
    meta_file = fullfile(result_dir, 'metadata.json');
    if isfile(meta_file)
        meta = jsondecode(fileread(meta_file));
    else
        meta = struct();
    end

    % 读取坐标
    coord_file = fullfile(result_dir, 'coordinates.csv');
    if isfile(coord_file)
        coords = readtable(coord_file);
    else
        coords = table();
    end
end

function name = meta_case_name(result_dir)
    % 从 metadata.json 中提取 case_name，若不存在则从目录名推断
    meta_file = fullfile(result_dir, 'metadata.json');
    if isfile(meta_file)
        meta = jsondecode(fileread(meta_file));
        name = meta.case_name;
    else
        [~, name, ~] = fileparts(result_dir);
    end
end
