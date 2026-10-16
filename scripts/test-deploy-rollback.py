#!/usr/bin/env python3
"""Run deployment failure/rollback tests in an isolated temporary Git repository.

No real systemd, network, Maven, or DEV JAR is touched.
"""
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
DEPLOY = ROOT / "scripts" / "deploy-branch.sh"


def run(cmd, cwd=None, env=None, check=True):
    return subprocess.run(cmd, cwd=cwd, env=env, text=True, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT, check=check)


def write_executable(path, data):
    path.write_text(data, encoding="utf-8")
    path.chmod(0o755)


def scenario(name, jar_value, build_value, fail_mode, expected, expect_restart):
    with tempfile.TemporaryDirectory(prefix="msa-rollback-test-") as temp:
        base = pathlib.Path(temp)
        repo = base / "repo"
        repo.mkdir()
        (repo / "scripts").mkdir()
        shutil.copy2(DEPLOY, repo / "scripts" / "deploy-branch.sh")
        (repo / ".env.dev").write_text("PORT=7012\nDEPLOY_EMAIL_ENABLED=false\n")
        (repo / "pom.xml").write_text("<project/>\n")
        run(["git", "init", "-q", "-b", "dev"], cwd=repo)
        run(["git", "config", "user.name", "Rollback Test"], cwd=repo)
        run(["git", "config", "user.email", "rollback-test@example.invalid"], cwd=repo)
        run(["git", "add", "scripts/deploy-branch.sh", "pom.xml"], cwd=repo)
        run(["git", "commit", "-qm", "test fixture"], cwd=repo)
        origin = base / "origin.git"
        run(["git", "init", "--bare", "-q", str(origin)])
        run(["git", "remote", "add", "origin", str(origin)], cwd=repo)
        run(["git", "push", "-q", "-u", "origin", "dev"], cwd=repo)
        jar = repo / "run" / "dev" / "application.jar"
        jar.parent.mkdir(parents=True)
        jar.write_text(jar_value)
        fake = base / "bin"
        fake.mkdir()
        state = base / "state"
        state.mkdir()
        (state / "restarts").write_text("0")
        (state / "mode").write_text(fail_mode)
        (state / "build").write_text(build_value)
        write_executable(fake / "mvn", """#!/usr/bin/env bash
if [[ "$(cat "$TEST_STATE/mode")" == build_fail ]]; then exit 1; fi
mkdir -p target
cp "$TEST_STATE/build" target/main-api-spring-0.1.0.jar
""")
        write_executable(fake / "sudo", """#!/usr/bin/env bash
[[ "$1" == -n ]] && shift
[[ "$1" == systemctl ]] || exit 2
shift
case "$1" in
  cat) exit 0 ;;
  show)
    case "$4" in
      WorkingDirectory) printf '%s\\n' "$TEST_REPO" ;;
      ExecStart) printf 'java -jar %s/run/dev/application.jar\\n' "$TEST_REPO" ;;
      *) exit 3 ;;
    esac ;;
  restart)
    count="$(cat "$TEST_STATE/restarts")"
    echo "$((count+1))" > "$TEST_STATE/restarts"
    if [[ "$(cat "$TEST_STATE/mode")" == restart_fail ]] && [[ "$count" == 0 ]]; then exit 1; fi
    exit 0 ;;
  is-active) exit 0 ;;
  *) exit 4 ;;
esac
""")
        write_executable(fake / "curl", """#!/usr/bin/env bash
[[ "$(cat "$TEST_REPO/run/dev/application.jar")" == good ]] && exit 0
exit 22
""")
        write_executable(fake / "python3", "#!/usr/bin/env bash\nexit 0\n")
        write_executable(fake / "sleep", "#!/usr/bin/env bash\nexit 0\n")
        env = dict(os.environ, PATH=str(fake) + os.pathsep + os.environ["PATH"],
                   TEST_STATE=str(state), TEST_REPO=str(repo))
        result = run(["bash", "scripts/deploy-branch.sh", "dev"], cwd=repo, env=env, check=False)
        actual = jar.read_text()
        restarts = int((state / "restarts").read_text())
        logs = "\n".join(p.read_text() for p in (repo / "logs" / "dev" / "deployment").glob("*"))
        success = (actual == expected and
                   ((result.returncode == 0) == (fail_mode == "normal")) and
                   ((restarts >= 2) if expect_restart else (restarts == (1 if fail_mode == "normal" else 0))) and
                   (("event=ROLLBACK result=succeeded" in logs) if expect_restart else True))
        print(("[PASS]" if success else "[FAIL]") + " " + name +
              " | jar=" + actual + " | restarts=" + str(restarts) +
              " | exit=" + str(result.returncode))
        if not success:
            print(result.stdout[-3000:])
            print(logs[-2000:])
        return success


def main():
    for tool in ("git", "tar", "flock", "bash"):
        if not shutil.which(tool):
            sys.exit("Missing test dependency: " + tool)
    if not DEPLOY.is_file():
        sys.exit("Missing scripts/deploy-branch.sh")
    tests = [
        ("T1 normal deployment", "good", "good", "normal", "good", False),
        ("T2 build failure preserves JAR", "good", "new", "build_fail", "good", False),
        ("T3 startup failure rolls back", "good", "bad", "restart_fail", "good", True),
        ("T4 health failure rolls back", "good", "bad", "health_fail", "good", True),
    ]
    passed = sum(scenario(*test) for test in tests)
    print("Result: " + str(passed) + "/" + str(len(tests)) + " passed")
    return 0 if passed == len(tests) else 1


if __name__ == "__main__":
    sys.exit(main())
