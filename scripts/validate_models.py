#!/usr/bin/env python3
"""
dbt 模型发布前校验脚本
检查命名规范、文档完整性、Owner 分配、测试覆盖等

使用方式:
    python scripts/validate_models.py
    python scripts/validate_models.py --changed-only  # 只检查 git 变更的文件

输出: 信息(📊) 和 警告(⚠️)，不阻断部署
"""

import os
import re
import sys
import yaml
import subprocess
from pathlib import Path
from collections import defaultdict

# 项目路径
PROJECT_ROOT = Path(__file__).parent.parent
DBT_PROJECT = PROJECT_ROOT / "dbt_project"
MODELS_DIR = DBT_PROJECT / "models"
STAGING_DIR = MODELS_DIR / "staging"
MARTS_DIR = MODELS_DIR / "marts"

# 规则配置
RULES = {
    "ods_prefix": "ods_",
    "stg_prefix": "stg_",
    "valid_schemas": ["analytics", "marts"],
    "required_tags": ["staging", "marts"],
}


def get_changed_files():
    """获取 git 变更的文件"""
    try:
        result = subprocess.run(
            ["git", "diff", "--name-only", "HEAD~1", "HEAD"],
            capture_output=True, text=True, cwd=PROJECT_ROOT
        )
        if result.returncode == 0:
            return [f for f in result.stdout.strip().split("\n") if f]
    except:
        pass
    # fallback: 检查所有文件
    return None


def read_sql_file(path):
    """读取 SQL 文件内容"""
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def read_yml_file(path):
    """读取 YAML 文件"""
    with open(path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def check_naming_convention(sql_files):
    """检查命名规范"""
    issues = []
    
    for f in sql_files:
        name = f.stem
        parent = f.parent.name
        
        # staging 模型必须 stg_ 开头
        if parent == "staging" and not name.startswith("stg_"):
            issues.append(f"⚠️ [{f.name}] staging 模型应以 stg_ 开头")
        
        # 检查 snake_case
        if not re.match(r'^[a-z][a-z0-9_]*$', name):
            issues.append(f"⚠️ [{f.name}] 文件名不符合 snake_case 规范")
    
    return issues


def check_config(sql_files):
    """检查模型 config 配置"""
    issues = []
    
    for f in sql_files:
        content = read_sql_file(f)
        parent = f.parent.name
        
        # 检查是否有 config
        if "config(" not in content:
            issues.append(f"⚠️ [{f.name}] 缺少 config 配置")
            continue
        
        # 检查 tags
        if "tags=" not in content and "tags =" not in content:
            issues.append(f"⚠️ [{f.name}] config 中缺少 tags 配置")
        
        # 检查 schema
        if "schema=" not in content and "schema =" not in content:
            issues.append(f"⚠️ [{f.name}] config 中缺少 schema 配置（可能写入错误 schema）")
        
        # marts 模型检查 owner post_hook
        if parent == "marts":
            if "set_owner_tag" not in content and "post_hook" not in content:
                issues.append(f"⚠️ [{f.name}] marts 模型缺少 owner tag（post_hook）")
    
    return issues


def check_documentation(yml_files, sql_files):
    """检查文档完整性"""
    issues = []
    
    # 收集 yml 中定义的模型
    documented_models = set()
    for yml_path in yml_files:
        try:
            data = read_yml_file(yml_path)
            if data and "models" in data:
                for model in data["models"]:
                    if model.get("description"):
                        documented_models.add(model["name"])
                    else:
                        issues.append(f"⚠️ [{model['name']}] yml 中缺少 description")
        except:
            pass
    
    # 检查哪些 SQL 模型没有对应的 yml 文档
    for f in sql_files:
        name = f.stem
        if name not in documented_models:
            issues.append(f"📊 [{name}] 模型未在 yml 中定义 description")
    
    return issues


def check_tests(yml_files):
    """检查测试覆盖"""
    issues = []
    models_with_tests = set()
    
    for yml_path in yml_files:
        try:
            data = read_yml_file(yml_path)
            if data and "models" in data:
                for model in data["models"]:
                    has_test = False
                    for col in model.get("columns", []):
                        if col.get("tests"):
                            has_test = True
                            break
                    if has_test:
                        models_with_tests.add(model["name"])
                    else:
                        issues.append(f"⚠️ [{model['name']}] 无字段级测试定义（建议至少添加 unique + not_null）")
        except:
            pass
    
    return issues, models_with_tests


def check_impact(sql_files):
    """分析变更影响范围（基于 ref 依赖）"""
    # 构建依赖图
    dependencies = defaultdict(set)  # model -> set of models it depends on
    dependents = defaultdict(set)    # model -> set of models that depend on it
    
    all_sql = list(STAGING_DIR.glob("*.sql")) + list(MARTS_DIR.glob("*.sql"))
    
    for f in all_sql:
        content = read_sql_file(f)
        name = f.stem
        # 找到所有 ref('xxx') 引用
        refs = re.findall(r"\{\{\s*ref\(['\"](\w+)['\"]\)\s*\}\}", content)
        for ref in refs:
            dependencies[name].add(ref)
            dependents[ref].add(name)
    
    # 对变更的文件，计算下游影响
    impacts = []
    for f in sql_files:
        name = f.stem
        downstream = dependents.get(name, set())
        if downstream:
            impacts.append({
                "model": name,
                "downstream": list(downstream),
                "count": len(downstream),
            })
    
    return impacts


def main():
    changed_only = "--changed-only" in sys.argv
    
    print("=" * 60)
    print("🔍 dbt 模型发布前校验")
    print("=" * 60)
    
    # 收集文件
    if changed_only:
        changed = get_changed_files()
        if changed:
            sql_files = [PROJECT_ROOT / f for f in changed if f.endswith(".sql") and "models" in f]
            yml_files = [PROJECT_ROOT / f for f in changed if f.endswith(".yml") and "models" in f]
            print(f"📂 检查变更文件: {len(sql_files)} SQL, {len(yml_files)} YML")
        else:
            sql_files = list(STAGING_DIR.glob("*.sql")) + list(MARTS_DIR.glob("*.sql"))
            yml_files = list(MODELS_DIR.rglob("*.yml"))
    else:
        sql_files = list(STAGING_DIR.glob("*.sql")) + list(MARTS_DIR.glob("*.sql"))
        yml_files = list(MODELS_DIR.rglob("*.yml"))
    
    sql_files = [f for f in sql_files if f.exists()]
    yml_files = [f for f in yml_files if f.exists()]
    
    print(f"📂 检查范围: {len(sql_files)} 个模型, {len(yml_files)} 个 YML 文件\n")
    
    all_issues = []
    
    # 1. 命名规范
    print("📏 命名规范检查...")
    issues = check_naming_convention(sql_files)
    all_issues.extend(issues)
    if not issues:
        print("   ✅ 全部合规")
    else:
        for i in issues:
            print(f"   {i}")
    
    # 2. Config 配置
    print("\n⚙️  Config 配置检查...")
    issues = check_config(sql_files)
    all_issues.extend(issues)
    if not issues:
        print("   ✅ 全部合规")
    else:
        for i in issues:
            print(f"   {i}")
    
    # 3. 文档完整性
    print("\n📝 文档完整性检查...")
    issues = check_documentation(yml_files, sql_files)
    all_issues.extend(issues)
    if not issues:
        print("   ✅ 全部有文档")
    else:
        for i in issues[:5]:
            print(f"   {i}")
        if len(issues) > 5:
            print(f"   ... 还有 {len(issues)-5} 项")
    
    # 4. 测试覆盖
    print("\n🧪 测试覆盖检查...")
    issues, tested = check_tests(yml_files)
    all_issues.extend(issues)
    if not issues:
        print("   ✅ 全部有测试")
    else:
        for i in issues[:5]:
            print(f"   {i}")
        if len(issues) > 5:
            print(f"   ... 还有 {len(issues)-5} 项")
    
    # 5. 影响范围
    print("\n🔗 影响范围分析...")
    impacts = check_impact(sql_files)
    if impacts:
        for imp in impacts:
            level = "🔴" if imp["count"] >= 3 else "🟡" if imp["count"] >= 1 else "🟢"
            print(f"   {level} {imp['model']} → 影响 {imp['count']} 个下游: {', '.join(imp['downstream'])}")
    else:
        print("   📊 无下游依赖影响")
    
    # 总结
    warnings = [i for i in all_issues if i.startswith("⚠️")]
    infos = [i for i in all_issues if i.startswith("📊")]
    
    print("\n" + "=" * 60)
    print("📋 校验总结")
    print("=" * 60)
    print(f"   ⚠️  警告: {len(warnings)} 项")
    print(f"   📊 信息: {len(infos)} 项")
    print(f"   🔗 影响: {sum(i['count'] for i in impacts)} 个下游模型")
    
    if warnings:
        print(f"\n   建议修复 {len(warnings)} 项警告后再发布。")
    else:
        print("\n   ✅ 无警告，可以安全发布！")
    
    return 0


if __name__ == "__main__":
    main()
