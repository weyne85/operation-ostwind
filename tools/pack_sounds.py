"""
Operation Ostwind - Sprachdateien in die .miz packen

Kopiert alle Ordner aus mission/sounds/ in die Wurzel der .miz-Datei.
AIRBOSS findet die Dateien dann unter "Airboss Soundfiles/".

Aufruf:
    python tools/pack_sounds.py mission/Operation_Ostwind.miz

Das Skript kann beliebig oft laufen. Vorhandene Dateien werden ersetzt.
Nach dem Speichern im Missionseditor erneut ausführen, falls der
Editor die Dateien entfernt hat.

Vor dem Schreiben wird eine Sicherung <name>.miz.bak angelegt.
Benötigt nur Python 3, keine weiteren Pakete.
"""

import os
import shutil
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOUNDS = os.path.join(ROOT, "mission", "sounds")


def collect_sounds():
    """Liefert (Pfad auf der Platte, Pfad in der .miz) für alle .ogg und .wav."""
    files = []
    for folder in sorted(os.listdir(SOUNDS)):
        full = os.path.join(SOUNDS, folder)
        if not os.path.isdir(full):
            continue
        for name in sorted(os.listdir(full)):
            if name.lower().endswith((".ogg", ".wav")):
                files.append((os.path.join(full, name), folder + "/" + name))
    return files


def pack(miz_path):
    if not os.path.isfile(miz_path):
        sys.exit(f"Datei nicht gefunden: {miz_path}")
    if not zipfile.is_zipfile(miz_path):
        sys.exit(f"Keine gültige .miz-Datei: {miz_path}")

    sounds = collect_sounds()
    if not sounds:
        sys.exit(f"Keine Sprachdateien in {SOUNDS}")
    targets = {arc for _, arc in sounds}

    backup = miz_path + ".bak"
    shutil.copy2(miz_path, backup)

    temp = miz_path + ".tmp"
    with zipfile.ZipFile(miz_path, "r") as src, \
         zipfile.ZipFile(temp, "w", zipfile.ZIP_DEFLATED) as dst:
        kept = 0
        for item in src.infolist():
            if item.filename in targets:
                continue  # wird unten neu geschrieben
            dst.writestr(item, src.read(item.filename))
            kept += 1
        for disk, arc in sounds:
            # Ton ist bereits komprimiert, daher ohne erneute Kompression
            dst.write(disk, arc, compress_type=zipfile.ZIP_STORED)

    # Prüfen, bevor die Originaldatei ersetzt wird
    with zipfile.ZipFile(temp, "r") as check:
        bad = check.testzip()
        names = set(check.namelist())
    if bad is not None or not targets.issubset(names) or "mission" not in names:
        os.remove(temp)
        sys.exit("Prüfung fehlgeschlagen, Originaldatei unverändert.")

    os.replace(temp, miz_path)
    print(f"{len(sounds)} Sprachdateien gepackt, {kept} vorhandene Einträge übernommen.")
    print(f"Sicherung: {backup}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Aufruf: python tools/pack_sounds.py <mission.miz>")
    pack(sys.argv[1])
