# Fluent 一键仿真平台（FluentTool）

本项目用于自动化执行 ANSYS Fluent 瞬态仿真，自动生成 605 个监测点（可扩展），并将所有监测点的时序数据汇总到一个文件中，便于后续 MATLAB/Python 后处理。

## 目录结构

```text
FluentTool/
│
├── config.yaml              # 所有参数的入口，改这里即可
├── run.py                   # 一键运行单个工况
├── batch.py                 # 批量参数扫描
├── run.jou                  # Fluent 主控 Journal（纯 TUI/Scheme）
├── create_points.scm        # 自动生成监测点 Point Surface
├── setup_reports.scm        # 创建 Report Definitions 与 Report File
│
├── Case/                    # 存放 .cas.h5 / .dat.h5
│   ├── fluent_inited.cas.h5
│   └── fluent_inited.dat.h5
│
├── temp/                    # 运行时自动生成的临时文件
│   └── params.scm           # Python 根据 config.yaml 生成的 Scheme 参数
│
├── Results/                 # 仿真结果
│   └── 40Hz_1mm_0.2ms/
│       ├── 40Hz_1mm_0.2ms.out   # Fluent 原始报告文件
│       ├── 40Hz_1mm_0.2ms.csv   # 转换后的 CSV
│       ├── coordinates.csv      # 监测点坐标表
│       └── metadata.json        # 工况参数记录
│
├── Matlab/
│   ├── read_case.m          # 读取单个工况
│   ├── fft_analysis.m       # FFT 分析
│   └── batch_process.m      # 批量可视化
│
└── README.md                # 本文件
```

## 快速开始

### 1. 准备环境

- **ANSYS Fluent 2025 R2**（或相近版本）
- **Python 3.8+**，并安装 PyYAML：

```bash
pip install pyyaml
```

- 将你的 `.cas.h5` 和 `.dat.h5` 放入 `Case/` 目录，或在 `config.yaml` 中指定正确的文件名，脚本会自动从 `FluentTool` 上级目录复制同名文件。

### 2. 配置参数

编辑 [config.yaml](config.yaml)。关键参数：

```yaml
probe_grid:
  Nx: 11        # x 方向点数
  Ny: 11        # y 方向点数
  Nz: 5         # z 方向点数
  dx: 0.01      # 间距 [m]
  dy: 0.01
  dz: 0.01
  xmin: 0.00    # x 起点 [m]
  ymin: -0.05   # y 起点 [m]
  zmin: 0.00    # z 起点 [m]

condition:
  frequency_hz: 40
  amplitude_mm: 1.0
  velocity_ms: 0.2
  vibration_direction: 2  # 0=x, 1=y, 2=z

solver:
  time_step_size: 0.001
  number_of_time_steps: 100
  max_iterations_per_time_step: 20
```

**监测点总数 = Nx × Ny × Nz = 11 × 11 × 5 = 605。**

以后想改成 `21×21×11 = 4851` 个点，只需改 `Nx/Ny/Nz`，其他文件完全不用动。

### 3. 运行单个工况

```bash
python run.py
```

脚本会：

1. 根据 `config.yaml` 生成 `temp/params.scm`
2. 启动 Fluent（默认后台运行）
3. 自动创建 605 个 Point Surface
4. 创建 605 个 Report Definition 并加入一个 Report File
5. 初始化并开始 Transient 计算
6. 计算结束后保存 `.dat.h5` 并退出 Fluent
7. 将 `.out` 转换为 `.csv`，并生成 `metadata.json` 和 `coordinates.csv`

### 4. 批量参数扫描

编辑 [batch.py](batch.py) 底部的 `parameter_grid`，例如：

```python
parameter_grid = {
    "condition.frequency_hz": [20, 40, 60, 80],
    "condition.amplitude_mm": [0.5, 1.0, 2.0],
    "condition.velocity_ms": [0.2, 0.4, 0.6],
}
```

然后运行：

```bash
python batch.py
```

会自动跑完所有 `4 × 3 × 3 = 36` 组工况，每个工况一个结果文件夹。

### 5. MATLAB 后处理

```matlab
% 读取单个工况
[data, meta, coords] = read_case('Results/40Hz_1mm_0.2ms');

% 查看表头
head(data)

% 对某个点做 FFT
[f, Pxx] = fft_analysis(data, 'P_x00_y-05_z00_P');
figure; plot(f, Pxx);
xlabel('Frequency [Hz]'); ylabel('Amplitude');

% 批量可视化所有工况
batch_process('../Results');
```

## 设计说明

### 为什么用 Report Definitions + Report File？

Fluent 的 **Report File** 可以把多个 **Report Definitions** 的数据按时间步写入**同一个文件**。这正好满足：

> "一个 case 运行完应该一个数据文件就行了，所有监测点信号都放在一起。"

最终每个工况只有一个 `.out` / `.csv` 文件，而不是 605 个文件。

### 为什么用 Scheme 而不是 GUI 录制？

GUI 录制的 `.jou` 包含大量鼠标点击、窗口移动等脆弱操作。本方案全部使用 Fluent TUI/Scheme 命令：

- `/surface/point-surface` 创建点
- `/solve/report-definitions/add` 创建报告定义
- `/solve/report-files/add` 创建报告文件
- `/solve/dual-time-iterate` 运行瞬态计算

运行稳定、速度快、便于扩展。

## 故障排查

### Fluent 找不到

在 `config.yaml` 中设置：

```yaml
fluent:
  executable: "C:/Program Files/ANSYS Inc/v252/fluent/ntbin/win64/fluent.exe"
```

### Report File 命令不兼容

不同 Fluent 版本的 TUI 命令可能略有差异。如果 `/solve/report-files/edit ... add-report-defs` 报错，请尝试在 Fluent 控制台中输入：

```text
/solve/report-files/?
/solve/report-files/edit/?
```

查看当前版本的确切语法，并相应修改 `setup_reports.scm`。

### 监测点命名

监测点按坐标命名，例如：

```text
P_x00_y-05_z00
P_x00_y-05_z01
...
P_x10_y05_z04
```

对应的 Report Definition 名称为：

```text
P_x00_y-05_z00_P
P_x00_y-05_z00_Ux
...
```

这种命名方式可以直接从列名读出物理位置和物理量。

## 版本规划

- **V1.0（当前）**：单工况一键运行、605 监测点、CSV 输出、MATLAB 读取
- **V2.0**：批量参数扫描、HDF5 输出、自动保存中间 data
- **V3.0**：MATLAB 自动 FFT、频谱图、流场重建、论文图片输出

## 作者

自动化框架根据你的仿真需求搭建，后续可根据实际 Fluent 版本和工况进一步调优。
