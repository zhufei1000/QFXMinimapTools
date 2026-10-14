"""Build a clean WoW addon package and optionally publish via CurseForge Upload API."""
import argparse
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import urllib.error
import urllib.request
import uuid
import zipfile

def build(args):
    root = Path(args.addon_root).resolve()
    repo = Path(subprocess.check_output(['git', 'rev-parse', '--show-toplevel']).decode('utf-8').strip()).resolve()
    addon = root.name
    toc_path = root / (addon + '.toc')
    toc = toc_path.read_text(encoding='utf-8-sig')
    version = re.search(r'^## Version:\s*(\S+)', toc, re.M).group(1)
    if not re.fullmatch(r'\d+\.\d+\.\d+', version):
        raise SystemExit('Expected X.Y.Z addon version')
    if args.expected_version and version != args.expected_version:
        raise SystemExit('Release tag does not match TOC version')
    project = re.search(r'^## X-Curse-Project-ID:\s*(\d+)', toc, re.M)
    if not project or int(project.group(1)) != args.project_id:
        raise SystemExit('CurseForge project does not match TOC')
    if not re.search(r'^## Interface:.*\b120105\b', toc, re.M):
        raise SystemExit('TOC does not declare 12.1.5 support')
    tracked = subprocess.check_output(['git', 'ls-files', '-z'], cwd=repo).decode('utf-8').split('\0')
    members = {}
    excluded_dirs = {'.github', '.vscode', '.zcode', 'docs', 'tests', 'scripts', '__pycache__', '.release', 'dist'}
    for name in tracked:
        if not name:
            continue
        path = (repo / name).resolve()
        if not path.is_relative_to(root) or not path.is_file():
            continue
        rel = path.relative_to(root)
        lower = path.name.lower()
        if rel.parent == Path('.') and lower.startswith('readme'):
            continue
        if any(part in excluded_dirs or 'backup' in part.lower() for part in rel.parts):
            continue
        if lower.startswith(('changelog', 'release_notes', 'test_')) or path.suffix in {'.zip', '.py', '.yml', '.yaml', '.luac'} or lower in {'.gitignore', 'agents.md'}:
            continue
        members[PurePosixPath(addon, *rel.parts).as_posix()] = path
    for line in toc.splitlines():
        line = line.strip()
        if line and not line.startswith('#'):
            member = addon + '/' + line.replace('\\', '/')
            if member not in members:
                raise SystemExit('Missing TOC package member: ' + member)
    output = Path(args.output)
    output.mkdir(parents=True, exist_ok=True)
    package = output / f'{addon}_{version}.zip'
    with zipfile.ZipFile(package, 'w', zipfile.ZIP_DEFLATED) as archive:
        for member, path in sorted(members.items()):
            archive.write(path, member)
    with zipfile.ZipFile(package) as archive:
        if archive.testzip() is not None:
            raise SystemExit('Package integrity failure')
    print(f'Built {package.name}: {len(members)} files; TOC validated')
    return package, version

def request_json(path, token, data=None, content_type=None):
    headers = {'X-Api-Token': token, 'User-Agent': 'QFX-Addon-Release', 'Accept': 'application/json'}
    if content_type:
        headers['Content-Type'] = content_type
    request = urllib.request.Request('https://wow.curseforge.com/api/' + path, data=data, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        raise SystemExit(f'CurseForge request failed: HTTP {error.code}') from None

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--addon-root', required=True)
    parser.add_argument('--project-id', required=True, type=int)
    parser.add_argument('--expected-version')
    parser.add_argument('--game-version', default='12.1.5')
    parser.add_argument('--notes', default='RELEASE_NOTES.md')
    parser.add_argument('--output', default='dist')
    parser.add_argument('--upload', action='store_true')
    args = parser.parse_args()
    package, version = build(args)
    if not args.upload:
        return
    token = os.environ.get('CF_API_TOKEN')
    if not token:
        raise SystemExit('Missing configured CurseForge upload token')
    versions = request_json('game/versions', token)
    ids = sorted({int(item['id']) for item in versions if item['name'] == args.game_version})
    if len(ids) != 1:
        raise SystemExit('Expected one exact CurseForge game version match')
    notes = Path(args.notes).read_text(encoding='utf-8-sig')
    if not notes.strip():
        raise SystemExit('Empty release notes')
    metadata = {'changelog': notes, 'changelogType': 'markdown', 'displayName': package.name,
                'gameVersions': ids, 'releaseType': 'release', 'isMarkedForManualRelease': False}
    boundary = 'qfx-' + uuid.uuid4().hex
    data = (f'--{boundary}\r\nContent-Disposition: form-data; name="metadata"\r\nContent-Type: application/json\r\n\r\n'.encode()
            + json.dumps(metadata, ensure_ascii=False).encode('utf-8')
            + f'\r\n--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{package.name}"\r\nContent-Type: application/zip\r\n\r\n'.encode()
            + package.read_bytes() + f'\r\n--{boundary}--\r\n'.encode())
    response = request_json(f'projects/{args.project_id}/upload-file', token, data, 'multipart/form-data; boundary=' + boundary)
    file_id = response.get('id')
    if not isinstance(file_id, int) or file_id <= 0:
        raise SystemExit('Upload response did not include a valid file ID; do not blindly retry')
    receipt = {'projectId': args.project_id, 'fileId': file_id, 'version': version,
               'gameVersion': args.game_version, 'gameVersionIds': ids, 'filename': package.name}
    (Path(args.output) / 'curseforge-upload.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    print('CurseForge accepted upload: ' + json.dumps(receipt))
    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary, 'a', encoding='utf-8') as file:
            file.write(f'CurseForge project **{args.project_id}**, file **{file_id}**, version **{version}**, WoW **{args.game_version}**.\n')

if __name__ == '__main__':
    main()
