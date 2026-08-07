#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
batch.py
批量参数扫描脚本

功能：
  自动遍历 frequency / amplitude / velocity 等参数组合，
  对每个组合修改 config.yaml 并调用 run.run_case()。

使用：
  编辑本文件底部的 parameter_grid 后运行：
    python batch.py

注意：
  - 本脚本会临时修改 config.yaml，运行结束后恢复原始配置。
  - 每个工况结果会自动保存在 Results/<case_name>/ 下。
"""

import copy
import yaml
from pathlib import Path
from run import load_config, run_case

ROOT = Path(__file__).parent.resolve()
CONFIG_FILE = ROOT / "config.yaml"


def save_config(cfg):
    """保存 config.yaml"""
    with open(CONFIG_FILE, "w", encoding="utf-8") as f:
        yaml.dump(cfg, f, allow_unicode=True, sort_keys=False)


def run_parameter_sweep(parameter_grid):
    """
    parameter_grid: dict
      键为 config 中嵌套路径，例如 "condition.frequency_hz"
      值为参数列表
    """
    # 读取原始配置
    with open(CONFIG_FILE, "r", encoding="utf-8") as f:
        original_text = f.read()
    base_cfg = load_config()

    # 构建参数组合
    keys = list(parameter_grid.keys())
    values = [parameter_grid[k] for k in keys]
    import itertools

    combinations = list(itertools.product(*values))
    total = len(combinations)
    print(f"[INFO] 共 {total} 组工况需要计算")

    for idx, combo in enumerate(combinations, start=1):
        cfg = copy.deepcopy(base_cfg)
        # 更新参数
        for key, val in zip(keys, combo):
            parts = key.split(".")
            node = cfg
            for p in parts[:-1]:
                node = node[p]
            node[parts[-1]] = val

        print("\n" + "=" * 70)
        print(f"[Batch] Case {idx} / {total}")
        for key, val in zip(keys, combo):
            print(f"  {key} = {val}")
        print("=" * 70)

        save_config(cfg)
        try:
            run_case(cfg)
        except Exception as e:
            print(f"[ERROR] Case {idx} 失败: {e}")
            # 继续下一组

    # 恢复原始配置
    with open(CONFIG_FILE, "w", encoding="utf-8") as f:
        f.write(original_text)
    print("[INFO] 已恢复原始 config.yaml")


def main():
    # ============================================================
    # 在此定义参数扫描网格
    # 键为 config.yaml 中的嵌套路径
    # ============================================================
    parameter_grid = {
        # "condition.frequency_hz": [20, 40, 60, 80],
        # "condition.amplitude_mm": [0.5, 1.0, 2.0],
        # "condition.velocity_ms": [0.2, 0.4, 0.6],

        # 示例：只跑两个频率，取消注释即可使用
        # "condition.frequency_hz": [20, 40],
    }

    if not parameter_grid:
        print("[WARN] parameter_grid 为空，请在 batch.py 中配置参数组合。")
        return

    run_parameter_sweep(parameter_grid)


if __name__ == "__main__":
    main()
