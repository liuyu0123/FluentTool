#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
run.py
Fluent 一键仿真平台主控脚本

功能：
  1. 读取 config.yaml
  2. 自动生成 temp/params.scm（含 605 个监测点坐标、变量列表等）
  3. 确保 Case/ 目录下存在 cas/dat 文件（支持从上级目录自动复制）
  4. 启动 Fluent 并执行 run.jou
  5. Fluent 退出后，将报告文件整理为 CSV，并生成 metadata.json

使用：
  python run.py
"""

import os
import sys
import shutil
import json
import yaml
import subprocess
import glob
from pathlib import Path
from itertools import product

# ============================================================
# 路径常量
# ============================================================
ROOT = Path(__file__).parent.resolve()
CASE_DIR = ROOT / "Case"
TEMP_DIR = ROOT / "temp"
RESULTS_DIR = ROOT / "Results"
CONFIG_FILE = ROOT / "config.yaml"
PARAMS_FILE = TEMP_DIR / "params.scm"
JOURNAL_FILE = ROOT / "run.jou"

# ============================================================
# 工具函数
# ============================================================
def load_config():
    """读取 config.yaml"""
    with open(CONFIG_FILE, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def ensure_case_files(cfg):
    """确保 Case/ 目录下存在 .cas.h5 和 .dat.h5"""
    case_name = cfg["case"]["case_file"]
    data_name = cfg["case"]["data_file"]
    case_src = CASE_DIR / case_name
    data_src = CASE_DIR / data_name

    # 如果 Case/ 下没有，尝试从工作区根目录复制
    if not case_src.exists() or not data_src.exists():
        root_case = ROOT.parent / case_name
        root_data = ROOT.parent / data_name
        if root_case.exists() and not case_src.exists():
            shutil.copy2(root_case, case_src)
            print(f"[INFO] 已从上级目录复制 {case_name} 到 Case/")
        if root_data.exists() and not data_src.exists():
            shutil.copy2(root_data, data_src)
            print(f"[INFO] 已从上级目录复制 {data_name} 到 Case/")

    if not case_src.exists():
        raise FileNotFoundError(f"找不到 case 文件: {case_src}")
    if not data_src.exists():
        raise FileNotFoundError(f"找不到 data 文件: {data_src}")


def generate_probe_list(cfg):
    """根据网格参数生成监测点列表"""
    g = cfg["probe_grid"]
    Nx, Ny, Nz = g["Nx"], g["Ny"], g["Nz"]
    dx, dy, dz = g["dx"], g["dy"], g["dz"]
    xmin, ymin, zmin = g["xmin"], g["ymin"], g["zmin"]

    probes = []
    for iz in range(Nz):
        for iy in range(Ny):
            for ix in range(Nx):
                x = xmin + ix * dx
                y = ymin + iy * dy
                z = zmin + iz * dz
                # 命名格式：P_x00_y-05_z04（单位 cm，保留两位整数）
                x_cm = int(round(x * 100))
                y_cm = int(round(y * 100))
                z_cm = int(round(z * 100))
                name = f"P_x{x_cm:02d}_y{y_cm:+03d}_z{z_cm:02d}"
                probes.append((name, x, y, z))
    return probes


def variable_mapping(cfg):
    """根据配置生成变量映射（短名 -> Fluent field 名）"""
    v = cfg["variables"]
    mapping = []
    if v.get("pressure", False):
        mapping.append(("P", "pressure"))
    if v.get("velocity_x", False):
        mapping.append(("Ux", "x-velocity"))
    if v.get("velocity_y", False):
        mapping.append(("Uy", "y-velocity"))
    if v.get("velocity_z", False):
        mapping.append(("Uz", "z-velocity"))
    if not mapping:
        # 至少监测压力
        mapping.append(("P", "pressure"))
    return mapping


def case_name(cfg):
    """生成当前工况结果目录名"""
    fmt = cfg["paths"]["case_name_format"]
    g = cfg["probe_grid"]
    c = cfg["condition"]
    return fmt.format(
        frequency_hz=c["frequency_hz"],
        amplitude_mm=c["amplitude_mm"],
        velocity_ms=c["velocity_ms"],
        Nx=g["Nx"],
        Ny=g["Ny"],
        Nz=g["Nz"],
    )


def write_params_scm(cfg):
    """生成 temp/params.scm"""
    TEMP_DIR.mkdir(parents=True, exist_ok=True)
    probes = generate_probe_list(cfg)
    var_list = variable_mapping(cfg)
    g = cfg["probe_grid"]
    s = cfg["solver"]

    case_name_str = case_name(cfg)
    case_file_rel = f"Case/{cfg['case']['case_file']}"
    result_dir = RESULTS_DIR / case_name_str
    result_dir.mkdir(parents=True, exist_ok=True)
    report_out = result_dir / f"{case_name_str}.out"
    final_data = result_dir / f"{case_name_str}.dat.h5"

    lines = []
    lines.append(";;; temp/params.scm")
    lines.append(";;; 由 run.py 自动生成，请勿手动修改")
    lines.append("")
    lines.append(";;; 网格参数")
    lines.append(f"(define Nx {g['Nx']})")
    lines.append(f"(define Ny {g['Ny']})")
    lines.append(f"(define Nz {g['Nz']})")
    lines.append(f"(define dx {g['dx']})")
    lines.append(f"(define dy {g['dy']})")
    lines.append(f"(define dz {g['dz']})")
    lines.append(f"(define xmin {g['xmin']})")
    lines.append(f"(define ymin {g['ymin']})")
    lines.append(f"(define zmin {g['zmin']})")
    lines.append("")
    lines.append(";;; 工况参数")
    c = cfg["condition"]
    lines.append(f"(define frequency-hz {c['frequency_hz']})")
    lines.append(f"(define amplitude-mm {c['amplitude_mm']})")
    lines.append(f"(define velocity-ms {c['velocity_ms']})")
    lines.append(f"(define vibration-direction {c['vibration_direction']})")
    lines.append("")
    lines.append(";;; 求解参数")
    lines.append(f"(define time-step-size {s['time_step_size']})")
    lines.append(f"(define number-of-time-steps {s['number_of_time_steps']})")
    lines.append(f"(define max-iterations-per-time-step {s['max_iterations_per_time_step']})")
    lines.append("")
    lines.append(";;; 文件路径")
    # 使用双反斜杠或正斜杠处理 Windows 路径
    case_path = str((ROOT / case_file_rel).resolve()).replace("\\", "/")
    report_path = str(report_out.resolve()).replace("\\", "/")
    final_data_path = str(final_data.resolve()).replace("\\", "/")
    lines.append(f'(define case-data-path "{case_path}")')
    lines.append(f'(define report-file-object-name "pressure_signal_record")')
    lines.append(f'(define report-file-output-name "{report_path}")')
    lines.append(f'(define final-data-path "{final_data_path}")')
    lines.append("")
    lines.append(";;; 监测点列表 ((name x y z) ...)")
    lines.append("(define probe-list '( ")
    for name, x, y, z in probes:
        lines.append(f'  ("{name}" {x:.6f} {y:.6f} {z:.6f})')
    lines.append("))")
    lines.append("")
    lines.append(";;; 变量列表 ((短名 . Fluent field) ...)")
    lines.append("(define var-list '( ")
    for short, field in var_list:
        lines.append(f'  ("{short}" . "{field}")')
    lines.append("))")
    lines.append("")

    with open(PARAMS_FILE, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    print(f"[INFO] 已生成 {PARAMS_FILE}")
    print(f"[INFO] 监测点数量: {len(probes)}")
    print(f"[INFO] 变量: {[v[0] for v in var_list]}")
    print(f"[INFO] 结果目录: {result_dir}")
    return result_dir, report_out


def find_fluent_executable(cfg):
    """查找 Fluent 可执行文件"""
    exe = cfg["fluent"].get("executable", "").strip()
    if exe:
        exe_path = Path(exe)
        if exe_path.exists():
            return str(exe_path)
        # 尝试在 PATH 中查找
        found = shutil.which(exe)
        if found:
            return found
        raise FileNotFoundError(f"配置的 Fluent 可执行文件不存在: {exe}")

    # 自动查找
    found = shutil.which("fluent")
    if found:
        return found

    # 常见 Windows 安装路径
    candidates = [
        r"C:\Program Files\ANSYS Inc\v252\fluent\ntbin\win64\fluent.exe",
        r"C:\Program Files\ANSYS Inc\v251\fluent\ntbin\win64\fluent.exe",
        r"C:\Program Files\ANSYS Inc\v250\fluent\ntbin\win64\fluent.exe",
        r"C:\Program Files\ANSYS Inc\v242\fluent\ntbin\win64\fluent.exe",
        r"C:\Program Files\ANSYS Inc\v241\fluent\ntbin\win64\fluent.exe",
    ]
    for cand in candidates:
        if Path(cand).exists():
            return cand

    raise FileNotFoundError("找不到 fluent 可执行文件。请在 config.yaml 中配置 fluent.executable。")


def run_fluent(cfg):
    """启动 Fluent 执行 run.jou"""
    fluent_exe = find_fluent_executable(cfg)
    dim = cfg["fluent"]["dimension"]
    np = cfg["fluent"]["num_processors"]
    show_gui = cfg["fluent"].get("show_gui", False)

    cmd = [
        fluent_exe,
        dim,
        f"-t{np}",
        f"-i{JOURNAL_FILE}",
    ]
    if not show_gui:
        cmd.append("-hidden")

    print("[INFO] 启动 Fluent...")
    print(f"[CMD] {' '.join(cmd)}")

    try:
        subprocess.run(cmd, cwd=ROOT, check=True)
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] Fluent 运行失败，返回码: {e.returncode}")
        sys.exit(1)


def find_report_file(result_dir, cfg):
    """
    查找 Fluent 生成的报告文件。
    优先查找 Results/<case_name>/<case_name>.out，
    回退到工作目录下的 pressure_signal_record.out。
    """
    case_name_str = case_name(cfg)
    candidates = [
        result_dir / f"{case_name_str}.out",
        ROOT / "pressure_signal_record.out",
    ]
    for cand in candidates:
        if cand.exists():
            return cand
    return candidates[0]  # 返回默认路径，供后续报错使用


def convert_report_to_csv(report_out, result_dir, cfg):
    """将 Fluent report file (.out) 转换为 CSV"""
    if not report_out.exists():
        print(f"[WARN] 找不到报告文件: {report_out}")
        return None

    case_name_str = case_name(cfg)
    csv_path = result_dir / f"{case_name_str}.csv"
    try:
        with open(report_out, "r", encoding="utf-8") as f:
            lines = f.readlines()

        # Fluent report file 格式示例：
        # ("time" "P_x00_y-05_z00_P" "P_x00_y-04_z00_P" ...)
        # 0.001 101325 101326 ...
        # 简单解析：去掉括号，按空白分隔
        cleaned = []
        for line in lines:
            line = line.strip()
            if not line:
                continue
            line = line.replace("(", "").replace(")", "").replace('"', "")
            cleaned.append(line)

        with open(csv_path, "w", encoding="utf-8") as f:
            for line in cleaned:
                f.write(",".join(line.split()) + "\n")

        print(f"[INFO] 已转换为 CSV: {csv_path}")
        return csv_path
    except Exception as e:
        print(f"[WARN] CSV 转换失败: {e}")
        return None


def write_metadata(result_dir, cfg, csv_path=None):
    """生成 metadata.json"""
    g = cfg["probe_grid"]
    c = cfg["condition"]
    meta = {
        "case_name": case_name(cfg),
        "frequency_hz": c["frequency_hz"],
        "amplitude_mm": c["amplitude_mm"],
        "velocity_ms": c["velocity_ms"],
        "vibration_direction": c["vibration_direction"],
        "probe_grid": {
            "Nx": g["Nx"],
            "Ny": g["Ny"],
            "Nz": g["Nz"],
            "dx": g["dx"],
            "dy": g["dy"],
            "dz": g["dz"],
            "xmin": g["xmin"],
            "ymin": g["ymin"],
            "zmin": g["zmin"],
        },
        "variables": cfg["variables"],
        "solver": cfg["solver"],
        "csv_file": str(csv_path) if csv_path else None,
    }
    meta_path = result_dir / "metadata.json"
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2, ensure_ascii=False)
    print(f"[INFO] 已生成 metadata: {meta_path}")


def write_coordinates_csv(result_dir, cfg):
    """生成监测点坐标表，方便 MATLAB/Python 后处理"""
    probes = generate_probe_list(cfg)
    coord_path = result_dir / "coordinates.csv"
    with open(coord_path, "w", encoding="utf-8") as f:
        f.write("PointID,Name,x_m,y_m,z_m\n")
        for i, (name, x, y, z) in enumerate(probes, start=1):
            f.write(f"{i},{name},{x:.6f},{y:.6f},{z:.6f}\n")
    print(f"[INFO] 已生成监测点坐标表: {coord_path}")


def run_case(cfg):
    """执行单个工况"""
    print("=" * 60)
    print(" Fluent 一键仿真平台")
    print("=" * 60)

    ensure_case_files(cfg)
    result_dir, _ = write_params_scm(cfg)
    write_coordinates_csv(result_dir, cfg)

    # 清理可能存在的旧 report file，避免误读上一工况数据
    stale_report = ROOT / "pressure_signal_record.out"
    if stale_report.exists():
        stale_report.unlink()
        print(f"[INFO] 已清理旧报告文件: {stale_report}")

    run_fluent(cfg)

    report_out = find_report_file(result_dir, cfg)
    csv_path = convert_report_to_csv(report_out, result_dir, cfg)
    write_metadata(result_dir, cfg, csv_path)

    print("=" * 60)
    print("[DONE] 仿真完成")
    print(f"[DONE] 结果目录: {result_dir}")
    print("=" * 60)
    return result_dir


def main():
    cfg = load_config()
    run_case(cfg)


if __name__ == "__main__":
    main()
