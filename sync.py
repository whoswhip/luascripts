###############
# GPT-5 CODED #
###############
import os
import shutil
import argparse
import asyncio
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import pathspec  # Add this import

executor = ThreadPoolExecutor(max_workers=8)

def human_size(num, suffix="B"):
    for unit in ["", "K", "M", "G", "T"]:
        if abs(num) < 1024.0:
            return f"{num:.1f}{unit}{suffix}"
        num /= 1024.0
    return f"{num:.1f}P{suffix}"

def load_syncignore(root: Path):
    ignore_file = root / ".syncignore"
    if ignore_file.exists():
        with ignore_file.open("r") as f:
            patterns = f.read().splitlines()
        return pathspec.PathSpec.from_lines("gitwildmatch", patterns)
    return None

def should_ignore(path: Path, specs, roots):
    # Find which root this path belongs to
    for root, spec in zip(roots, specs):
        try:
            rel_path = str(path.relative_to(root))
            if spec and spec.match_file(rel_path):
                return True
        except ValueError:
            continue
    return any(part.startswith('.') for part in path.parts)

async def copy_file(src: Path, dst: Path):
    old_size = dst.stat().st_size if dst.exists() else 0
    new_size = src.stat().st_size
    delta = new_size - old_size

    os.makedirs(dst.parent, exist_ok=True)
    await asyncio.get_event_loop().run_in_executor(executor, shutil.copy2, src, dst)

    change_str = f"{delta:+}B" if abs(delta) < 1024 else f"{delta/1024:+.1f}KB" if abs(delta) < 1024**2 else f"{delta/(1024**2):+.1f}MB"
    print(f"[+] Copied {src} -> {dst} ({change_str})")


async def delete_file(path: Path):
    if path.exists():
        await asyncio.get_event_loop().run_in_executor(executor, path.unlink)
        print(f"[-] Deleted {path}")

async def sync_two_way(dir1: Path, dir2: Path, specs=None, roots=None, files1=None, files2=None, prev_files1=None, prev_files2=None):
    # If specs/roots not provided, load them (for direct calls)
    if specs is None or roots is None:
        spec1 = load_syncignore(dir1)
        spec2 = load_syncignore(dir2)
        specs = [spec1, spec2]
        roots = [dir1, dir2]
    # Gather all relative paths if not provided
    if files1 is None:
        files1 = {f.relative_to(dir1) for f in dir1.rglob('*') if f.is_file() and not should_ignore(f, specs, roots)}
    if files2 is None:
        files2 = {f.relative_to(dir2) for f in dir2.rglob('*') if f.is_file() and not should_ignore(f, specs, roots)}
    if prev_files1 is None:
        prev_files1 = files1
    if prev_files2 is None:
        prev_files2 = files2

    all_files = files1.union(files2)
    tasks = []

    for rel_path in all_files:
        f1 = dir1 / rel_path
        f2 = dir2 / rel_path

        exists1 = f1.exists()
        exists2 = f2.exists()

        # Only propagate deletion if file existed in both dirs previously
        previously_in_both = rel_path in prev_files1 and rel_path in prev_files2

        if exists1 and exists2:
            # Both exist → conflict check
            size1, size2 = f1.stat().st_size, f2.stat().st_size
            mtime1, mtime2 = f1.stat().st_mtime, f2.stat().st_mtime
            if size1 != size2 or abs(mtime1 - mtime2) > 0.5:
                if mtime1 > mtime2:
                    tasks.append(copy_file(f1, f2))
                else:
                    tasks.append(copy_file(f2, f1))
        elif exists1 and not exists2:
            if previously_in_both:
                # File deleted from dir2 → delete from dir1
                tasks.append(delete_file(f1))
            else:
                # New file in dir1 → copy to dir2
                tasks.append(copy_file(f1, f2))
        elif exists2 and not exists1:
            if previously_in_both:
                # File deleted from dir1 → delete from dir2
                tasks.append(delete_file(f2))
            else:
                # New file in dir2 → copy to dir1
                tasks.append(copy_file(f2, f1))

    await asyncio.gather(*tasks)

async def watch_and_sync(dir1: Path, dir2: Path, interval=2):
    print(f"Watching {dir1} <-> {dir2} (Ctrl+C to stop)")
    prev_files1 = set()
    prev_files2 = set()
    while True:
        spec1 = load_syncignore(dir1)
        spec2 = load_syncignore(dir2)
        specs = [spec1, spec2]
        roots = [dir1, dir2]

        # Gather current files
        files1 = {f.relative_to(dir1) for f in dir1.rglob('*') if f.is_file() and not should_ignore(f, specs, roots)}
        files2 = {f.relative_to(dir2) for f in dir2.rglob('*') if f.is_file() and not should_ignore(f, specs, roots)}

        await sync_two_way(dir1, dir2, specs, roots, files1, files2, prev_files1, prev_files2)

        prev_files1 = files1
        prev_files2 = files2
        await asyncio.sleep(interval)

async def main():
    parser = argparse.ArgumentParser(description="Two-way async file sync with conflict resolution")
    parser.add_argument("dir1", type=str, help="First directory path")
    parser.add_argument("dir2", type=str, help="Second directory path")
    parser.add_argument("--interval", type=int, default=2, help="Sync interval in seconds")
    args = parser.parse_args()

    dir1 = Path(args.dir1).resolve()
    dir2 = Path(args.dir2).resolve()

    if not dir1.is_dir() or not dir2.is_dir():
        raise ValueError("Both paths must be valid directories")

    await watch_and_sync(dir1, dir2, args.interval)

if __name__ == "__main__":
    asyncio.run(main())
