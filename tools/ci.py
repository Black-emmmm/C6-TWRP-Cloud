#!/usr/bin/env python3
"""
C6 TWRP 云构建辅助脚本（无第三方依赖）

用法：
    export GITHUB_TOKEN=ghp_xxx
    python3 ci.py create            # 建仓库（已存在则跳过）
    python3 ci.py push              # 推送 main
    python3 ci.py dispatch          # 触发 workflow
    python3 ci.py watch             # 轮询运行状态，失败时打印步骤
    python3 ci.py log               # 取 artifacts 分支的 build.log（走 gh-proxy）
    python3 ci.py img               # 取 artifacts 分支的 recovery.img

环境变量：
    GITHUB_TOKEN  必填
    GITHUB_OWNER  默认 Black-emmmm
    GITHUB_REPO   默认 C6-TWRP-Cloud
"""
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

API = "https://api.github.com"
OWNER = os.environ.get("GITHUB_OWNER", "Black-emmmm")
REPO = os.environ.get("GITHUB_REPO", "C6-TWRP-Cloud")
TOKEN = os.environ.get("GITHUB_TOKEN", "")
WORKDIR = "/home/black/WorkBuddy/Work/C6_twrp_cloud"
PROXY = "https://gh-proxy.com/"


def req(path, method="GET", data=None, raw=False, accept=None):
    url = path if path.startswith("http") else f"{API}{path}"
    body = json.dumps(data).encode() if data is not None else None
    r = urllib.request.Request(url, data=body, method=method)
    r.add_header("User-Agent", "c6-ci")
    r.add_header("Accept", accept or "application/vnd.github+json")
    if TOKEN:
        r.add_header("Authorization", f"Bearer {TOKEN}")
    if body:
        r.add_header("Content-Type", "application/json")
    resp = urllib.request.urlopen(r, timeout=60)
    payload = resp.read()
    if raw:
        return payload
    return json.loads(payload) if payload else {}


def need_token():
    if not TOKEN:
        sys.exit("缺少 GITHUB_TOKEN 环境变量")


def cmd_create():
    need_token()
    try:
        r = req("/user/repos", "POST", {
            "name": REPO,
            "description": "TWRP cloud build for iFLYTEK C6 / ud710_2h10 (twrp-9.0 omni minimal manifest)",
            "private": False,
            "has_issues": False,
            "has_wiki": False,
            "auto_init": False,
        })
        print(f"已创建 {r['full_name']}  ->  {r['html_url']}")
    except urllib.error.HTTPError as e:
        if e.code == 422:
            print(f"{OWNER}/{REPO} 已存在，跳过创建")
        else:
            raise


def cmd_push(branch="main"):
    need_token()
    url = f"https://x-access-token:{TOKEN}@github.com/{OWNER}/{REPO}.git"
    subprocess.run(["git", "-C", WORKDIR, "push", "-f", url, f"{branch}:{branch}"], check=True)
    print(f"已推送 {branch} -> https://github.com/{OWNER}/{REPO}")


def cmd_dispatch(ref="main"):
    need_token()
    wf = req(f"/repos/{OWNER}/{REPO}/actions/workflows")["workflows"]
    target = next((w for w in wf if w["path"].endswith("build-twrp.yml")), None)
    if not target:
        sys.exit("仓库里找不到 build-twrp.yml，先 push")
    req(f"/repos/{OWNER}/{REPO}/actions/workflows/{target['id']}/dispatches",
        "POST", {"ref": ref, "inputs": {"twrp_branch": "twrp-9.0"}})
    print(f"已触发 workflow id={target['id']} ref={ref}")


def latest_run():
    runs = req(f"/repos/{OWNER}/{REPO}/actions/runs?per_page=1")["workflow_runs"]
    return runs[0] if runs else None


def cmd_watch(run_id=None, timeout=7200):
    need_token()
    if run_id is None:
        run = latest_run()
        if not run:
            sys.exit("还没有任何运行记录")
        run_id = run["id"]
    print(f"跟踪 run {run_id}: https://github.com/{OWNER}/{REPO}/actions/runs/{run_id}")

    seen = set()
    deadline = time.time() + timeout
    while time.time() < deadline:
        run = req(f"/repos/{OWNER}/{REPO}/actions/runs/{run_id}")
        status, concl = run["status"], run["conclusion"]
        jobs = req(f"/repos/{OWNER}/{REPO}/actions/runs/{run_id}/jobs")["jobs"]
        for j in jobs:
            for s in j["steps"]:
                key = (j["name"], s["number"])
                if key in seen:
                    continue
                seen.add(key)
                mark = {"success": "✓", "failure": "✗", "skipped": "-",
                        "cancelled": "c", None: "…"}.get(s["conclusion"], "?")
                print(f"  [{mark}] {j['name']} :: {s['name']}  ({s['status']})")
        if status == "completed":
            print(f"\n结束：{concl}")
            for j in jobs:
                print(f"  job {j['name']}: {j['conclusion']}")
                for s in j["steps"]:
                    if s["conclusion"] == "failure":
                        print(f"    失败步骤: {s['name']}")
            return 0 if concl == "success" else 1
        time.sleep(20)
    print("轮询超时（任务可能还在跑）")
    return 2


def fetch_artifact_file(name, out_path):
    url = f"{PROXY}https://raw.githubusercontent.com/{OWNER}/{REPO}/artifacts/{name}"
    print(f"下载 {url}")
    data = req(url, raw=True)
    with open(out_path, "wb") as f:
        f.write(data)
    print(f"-> {out_path} ({len(data)} bytes)")


def cmd_log(tail=120):
    data = req(f"{PROXY}https://raw.githubusercontent.com/{OWNER}/{REPO}/artifacts/build.log", raw=True)
    text = data.decode("utf-8", "replace")
    lines = text.splitlines()
    print("\n".join(lines[-tail:]))


def cmd_img():
    fetch_artifact_file("recovery.img", f"{WORKDIR}/out/recovery.img")


def cmd_info():
    data = req(f"{PROXY}https://raw.githubusercontent.com/{OWNER}/{REPO}/artifacts/RUN_INFO.txt", raw=True)
    print(data.decode("utf-8", "replace"))


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "help"
    if cmd == "create":
        cmd_create()
    elif cmd == "push":
        cmd_push()
    elif cmd == "dispatch":
        cmd_dispatch()
    elif cmd == "watch":
        rid = int(sys.argv[2]) if len(sys.argv) > 2 else None
        sys.exit(cmd_watch(rid))
    elif cmd == "log":
        cmd_log()
    elif cmd == "img":
        cmd_img()
    elif cmd == "info":
        cmd_info()
    else:
        print(__doc__)


if __name__ == "__main__":
    main()
