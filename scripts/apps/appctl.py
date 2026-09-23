#!/usr/bin/env python3
"""Backend do menu de apps (modules/ii/appDrawer).

Subcomandos (saída em JSON no stdout):
  <app> é o caminho do .desktop ou o id do app (como o DesktopEntry.id do Quickshell)

  info <app>                        origem, pacote, versão, tamanho, data e o que a remoção levaria
  search <repo|aur|flatpak> <termo> pacotes disponíveis para instalar
  edit <app> <nome> <ícone>         cria/atualiza override em ~/.local/share/applications
  restore <app>                     apaga (lixeira) o override criado por "edit"
  uninstall <origem> <alvo> [atalho] abre o terminal com a remoção (o usuário confirma lá);
                                    [atalho] é um override local que vai para a lixeira depois
  install <origem> <alvo>           abre o terminal com a instalação (o usuário confirma lá)
"""
import configparser
import datetime
import json
import os
import re
import shlex
import shutil
import subprocess
import sys

ENV = dict(os.environ, LC_ALL="C")
HOME = os.path.expanduser("~")
LOCAL_APPS = os.path.join(HOME, ".local/share/applications")
SYSTEM_APP_DIRS = [
    "/usr/share/applications",
    "/usr/local/share/applications",
    "/var/lib/flatpak/exports/share/applications",
    os.path.join(HOME, ".local/share/flatpak/exports/share/applications"),
]
FLATPAK_EXPORTS = ("/var/lib/flatpak/exports/", os.path.join(HOME, ".local/share/flatpak/exports/"))
OVERRIDE_KEY = "X-AppDrawer-Override"
TERMINAL = os.environ.get("TERMINAL", "kitty")
SEARCH_LIMIT = 8
TERMINALS = {"kitty", "alacritty", "foot", "footclient", "wezterm", "ghostty", "konsole", "gnome-terminal", "xterm"}


def run(cmd, timeout=30):
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, env=ENV, timeout=timeout)
        return p.returncode, p.stdout, p.stderr
    except (OSError, subprocess.TimeoutExpired) as e:
        return 1, "", str(e)


def read_entry(path):
    c = configparser.RawConfigParser(strict=False, interpolation=None, delimiters=("=",))
    c.optionxform = str
    try:
        c.read(path, encoding="utf-8")
    except (configparser.Error, UnicodeDecodeError):
        return {}
    return dict(c["Desktop Entry"]) if c.has_section("Desktop Entry") else {}


def human_size(n):
    for unit in ("B", "KiB", "MiB", "GiB"):
        if n < 1024 or unit == "GiB":
            return f"{n:.1f} {unit}" if unit != "B" else f"{int(n)} B"
        n /= 1024



def iso_date(text):
    try:
        return datetime.datetime.strptime(text, "%a %b %d %H:%M:%S %Y").isoformat(timespec="seconds")
    except ValueError:
        return text


def pacman_fields(pkg):
    rc, out, _ = run(["pacman", "-Qi", pkg])
    fields, key = {}, None
    for line in out.splitlines():
        if line[:1].isspace() and key:
            fields[key] += " " + line.strip()
            continue
        k, _, v = line.partition(":")
        key = k.strip()
        fields[key] = v.strip()
    return fields


def app_dirs():
    """Pastas de .desktop na ordem de precedência do XDG (a primeira vence)."""
    data_home = os.environ.get("XDG_DATA_HOME") or os.path.join(HOME, ".local/share")
    data_dirs = os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share"
    dirs = [data_home] + [d for d in data_dirs.split(":") if d]
    return [os.path.join(d, "applications") for d in dict.fromkeys(dirs)]


def resolve(app):
    """Aceita caminho ou id ("org.kde.foo", "kde4-foo" para kde4/foo.desktop)."""
    if os.path.isfile(app):
        return os.path.abspath(app)
    for d in app_dirs():
        direct = os.path.join(d, app + ".desktop")
        if os.path.isfile(direct):
            return direct
        if "-" in app:
            for root, _, files in os.walk(d):
                for f in files:
                    full = os.path.join(root, f)
                    if f.endswith(".desktop") and os.path.relpath(full, d)[:-8].replace("/", "-") == app:
                        return full
    return app


def system_original(path):
    """Arquivo de sistema que um .desktop local sobrepõe (mesmo nome), se houver."""
    name = os.path.basename(path)
    for d in SYSTEM_APP_DIRS:
        cand = os.path.join(d, name)
        if os.path.isfile(cand) and os.path.realpath(cand) != os.path.realpath(path):
            return cand
    return None


def info_pacman(path, result):
    rc, out, _ = run(["pacman", "-Qqo", path])
    if rc != 0:
        return False
    pkg = out.strip().splitlines()[0]
    f = pacman_fields(pkg)
    rc_m, _, _ = run(["pacman", "-Qqm", pkg])
    result.update({
        "source": "aur" if rc_m == 0 else "pacman",
        "package": pkg,
        "version": f.get("Version", ""),
        "description": f.get("Description", ""),
        "repository": "AUR" if rc_m == 0 else f.get("Installed From", "None").replace("None", "") or "pacman",
        "size": f.get("Installed Size", ""),
        "installDate": iso_date(f.get("Install Date", "")),
        "requiredBy": [x for x in f.get("Required By", "None").split() if x != "None"],
        "url": f.get("URL", ""),
        "removeTarget": pkg,
    })
    _, files, _ = run(["pacman", "-Qlq", pkg])
    result["siblings"] = sorted({
        os.path.basename(x) for x in files.splitlines()
        if x.endswith(".desktop") and "/applications/" in x and os.path.realpath(x) != os.path.realpath(path)
    })
    rc, out, err = run(["pacman", "-Rsp", "--print-format", "%n %s", pkg])
    if rc == 0:
        removed = []
        total = 0
        for line in out.splitlines():
            parts = line.split()
            if len(parts) == 2 and parts[1].isdigit():
                removed.append(parts[0])
                total += int(parts[1])
        result["removes"] = removed
        result["freed"] = human_size(total)
    else:
        # pacman escreve o motivo em stdout (":: removing X breaks dependency ...")
        result["removeBlocked"] = sorted({m.group(1) for m in re.finditer(r"required by (\S+)", out + err)}) or ["?"]
    return True


def info_flatpak(path, result):
    real = os.path.realpath(path)
    if not any(path.startswith(p) or real.startswith(p) for p in FLATPAK_EXPORTS) and "/flatpak/" not in real:
        return False
    app_id = os.path.basename(path)[:-len(".desktop")]
    _, out, _ = run(["flatpak", "list", "--app", "--columns=application,version,size,origin,installation,description"])
    for line in out.splitlines():
        cols = line.split("\t")
        if cols and cols[0] == app_id:
            cols += [""] * 6
            result.update({
                "source": "flatpak",
                "package": app_id,
                "version": cols[1],
                "size": cols[2],
                "repository": f"{cols[3]} ({cols[4]})",
                "description": cols[5],
                "removeTarget": app_id,
                "removes": [app_id],
                "freed": cols[2],
            })
            break
    else:
        result.update({"source": "flatpak", "package": app_id, "removeTarget": app_id})
    result["installDate"] = datetime.datetime.fromtimestamp(os.path.getmtime(real)).isoformat(timespec="seconds")
    return True


def info(path):
    path = os.path.abspath(path)
    entry = read_entry(path)
    result = {
        "path": path,
        "exec": entry.get("Exec", ""),
        "name": entry.get("Name", ""),
        "icon": entry.get("Icon", ""),
        "source": "local",
        "package": "",
        "version": "",
        "description": entry.get("Comment", ""),
        "repository": "",
        "size": "",
        "installDate": "",
        "requiredBy": [],
        "siblings": [],
        "removes": [],
        "removeBlocked": [],
        "freed": "",
        "removeTarget": path,
        "overridden": False,
        "override": entry.get(OVERRIDE_KEY, "").lower() == "true",
        "original": "",
    }
    if not os.path.isfile(path):
        result["error"] = "arquivo não encontrado"
        return result

    target = path
    if path.startswith(LOCAL_APPS + "/"):
        orig = system_original(path)
        if orig:
            # Override local de um app do sistema: a origem é a do original
            result["overridden"] = True
            result["original"] = orig
            target = orig

    if info_flatpak(target, result) or info_pacman(target, result):
        return result

    exe = shlex.split(entry.get("Exec", "") or "true", posix=True)[0] if entry.get("Exec") else ""
    if re.search(r"--app-id=|--app=https?:", entry.get("Exec", "")) or os.path.basename(path).startswith(("chrome-", "brave-", "msedge-")):
        result["source"] = "webapp"
        result["repository"] = os.path.basename(exe) or "navegador"
    elif exe.lower().endswith(".appimage"):
        result["source"] = "appimage"
        result["appimage"] = exe
        if os.path.isfile(exe):
            result["size"] = human_size(os.path.getsize(exe))
    else:
        result["source"] = "local"
        # "kitty -e codex" diria que o app vem do pacote kitty; só vale para executável próprio
        if exe and not os.path.isabs(exe) and exe not in TERMINALS:
            exe_path = shutil.which(exe)
            if exe_path:
                rc, out, _ = run(["pacman", "-Qqo", exe_path])
                if rc == 0:
                    result["repository"] = f"executável do pacote {out.strip()}"
    result["installDate"] = datetime.datetime.fromtimestamp(os.path.getmtime(path)).isoformat(timespec="seconds")
    return result


def search_repo(query):
    rc, out, _ = run(["pacman", "-Ss", query])
    return parse_ss(out)


def search_aur(query):
    if not shutil.which("paru"):
        return []
    rc, out, _ = run(["paru", "-Ssa", "--limit", str(SEARCH_LIMIT * 3), query], timeout=20)
    return parse_ss(out)


def parse_ss(out):
    items, cur = [], None
    for line in out.splitlines():
        if not line.startswith(" ") and "/" in line.split(" ")[0]:
            head = line.split()
            repo, _, name = head[0].partition("/")
            cur = {
                "source": "aur" if repo == "aur" else "pacman",
                "repository": repo,
                "id": name,
                "name": name,
                "version": head[1] if len(head) > 1 else "",
                "description": "",
                "installed": "[installed" in line or "[instalado" in line or "[Installed" in line,
            }
            items.append(cur)
        elif cur is not None:
            cur["description"] = (cur["description"] + " " + line.strip()).strip()
    return items


def search_flatpak(query):
    if not shutil.which("flatpak"):
        return []
    rc, out, _ = run(["flatpak", "search", "--columns=application,name,version,description,remotes", query], timeout=30)
    _, inst, _ = run(["flatpak", "list", "--app", "--columns=application"])
    installed = set(inst.split())
    items = []
    for line in out.splitlines():
        cols = line.split("\t")
        if len(cols) < 5 or cols[0].startswith("org.gtk.Gtk3theme") or ".Platform" in cols[0] or cols[0].endswith((".Locale", ".Debug")):
            continue
        items.append({
            "source": "flatpak",
            "repository": cols[4].split(",")[0],
            "id": cols[0],
            "name": cols[1],
            "version": cols[2],
            "description": cols[3],
            "installed": cols[0] in installed,
        })
    return items


def rank(items, query):
    q = query.lower()

    def score(it):
        n, i = it["name"].lower(), it["id"].lower()
        if q in (n, i) or i.endswith("." + q):
            return 0
        if n.startswith(q) or i.startswith(q):
            return 1
        if q in n or q in i:
            return 2
        return 3
    # Mesmo pacote em dois repositórios (cachyos-extra-v3 e extra): fica o primeiro, que o pacman prefere
    seen, unique = set(), []
    for it in items:
        if (it["source"], it["id"]) not in seen:
            seen.add((it["source"], it["id"]))
            unique.append(it)
    # Estável: mantém a ordem da ferramenta dentro de cada grupo
    return sorted(unique, key=score)[:SEARCH_LIMIT]


def edit(path, name, icon):
    os.makedirs(LOCAL_APPS, exist_ok=True)
    path = os.path.abspath(path)
    dest = path if path.startswith(LOCAL_APPS + "/") else os.path.join(LOCAL_APPS, os.path.basename(path))
    with open(path, encoding="utf-8") as f:
        lines = f.read().splitlines()
    out, section, seen = [], None, set()
    for line in lines:
        s = line.strip()
        if s.startswith("[") and s.endswith("]"):
            if section == "Desktop Entry":
                out[len(out):] = missing(seen, name, icon, dest != path)
            section = s[1:-1]
        elif section == "Desktop Entry" and "=" in line:
            key = line.split("=", 1)[0].strip()
            if key == "Name" and name:
                line = f"Name={name}"
                seen.add("Name")
            elif re.fullmatch(r"Name\[[^\]]+\]", key) and name:
                continue  # sem isso a tradução pt_BR venceria o nome novo
            elif key == "Icon" and icon:
                line = f"Icon={icon}"
                seen.add("Icon")
            elif key == OVERRIDE_KEY:
                seen.add(OVERRIDE_KEY)
        out.append(line)
    if section == "Desktop Entry":
        out += missing(seen, name, icon, dest != path)
    tmp = dest + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")
    os.replace(tmp, dest)
    return {"ok": True, "path": dest}


def missing(seen, name, icon, is_override):
    extra = []
    if name and "Name" not in seen:
        extra.append(f"Name={name}")
    if icon and "Icon" not in seen:
        extra.append(f"Icon={icon}")
    if is_override and OVERRIDE_KEY not in seen:
        extra.append(f"{OVERRIDE_KEY}=true")
    return extra


def restore(path):
    path = os.path.abspath(path)
    if not path.startswith(LOCAL_APPS + "/") or read_entry(path).get(OVERRIDE_KEY, "").lower() != "true":
        return {"ok": False, "error": "não é um override do menu de apps"}
    rc, _, err = run(["gio", "trash", path])
    return {"ok": rc == 0, "error": err.strip()}


def in_terminal(title, script):
    wrapped = f"{script}\nstatus=$?\necho\nif [ $status -eq 0 ]; then echo 'Concluído.'; else echo \"Terminou com erro ($status).\"; fi\nread -rsn1 -p 'Pressione qualquer tecla para fechar...'"
    subprocess.Popen(["uwsm-app", "--", TERMINAL, "--class", "appdrawer-terminal", "--title", title, "bash", "-c", wrapped],
                     start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return {"ok": True}


def uninstall(source, target, leftover=""):
    q = shlex.quote(target)
    # Sem o pacote, um override em ~/.local/share/applications viraria atalho quebrado
    after = f" && gio trash {shlex.quote(leftover)}" if leftover else ""
    if source in ("pacman", "aur"):
        return in_terminal(f"Remover {target}", f"echo 'Removendo {target} e dependências órfãs...'; echo; paru -Rns {q}{after}")
    if source == "flatpak":
        return in_terminal(f"Remover {target}", f"flatpak uninstall {q}{after} && echo && echo 'Runtimes que ficaram sem uso:' && flatpak uninstall --unused")
    if source in ("webapp", "local", "appimage"):
        rc, _, err = run(["gio", "trash", target])
        return {"ok": rc == 0, "error": err.strip()}
    return {"ok": False, "error": f"origem desconhecida: {source}"}


def install(source, target):
    q = shlex.quote(target)
    if source in ("pacman", "aur"):
        return in_terminal(f"Instalar {target}", f"paru -S {q}")
    if source == "flatpak":
        return in_terminal(f"Instalar {target}", f"flatpak install flathub {q}")
    return {"ok": False, "error": f"origem desconhecida: {source}"}


def main(argv):
    if len(argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    cmd, args = argv[1], argv[2:]
    if cmd in ("info", "edit", "restore") and args:
        args[0] = resolve(args[0])
    if cmd == "info" and len(args) == 1:
        res = info(args[0])
    elif cmd == "search" and len(args) == 2:
        fn = {"repo": search_repo, "aur": search_aur, "flatpak": search_flatpak}.get(args[0])
        if not fn:
            return 2
        res = rank(fn(args[1]), args[1])
    elif cmd == "edit" and len(args) == 3:
        res = edit(*args)
    elif cmd == "restore" and len(args) == 1:
        res = restore(args[0])
    elif cmd == "uninstall" and len(args) in (2, 3):
        res = uninstall(*args)
    elif cmd == "install" and len(args) == 2:
        res = install(*args)
    else:
        print(__doc__, file=sys.stderr)
        return 2
    print(json.dumps(res, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
