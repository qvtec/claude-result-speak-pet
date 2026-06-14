#!/usr/bin/env python3
"""
macOS pet notification window.
Requires: Python 3 with Tk 8.6+ (Homebrew / python.org build)
No third-party packages needed.
"""
import sys
import os
import glob

try:
    import tkinter as tk
    HAS_TK = True
except ImportError:
    HAS_TK = False


def show_osascript(message):
    import subprocess
    subprocess.run(
        ["osascript", "-e", f'display notification "{message}" with title "Claude Code"'],
        check=False,
    )


def _load_photo(root, path, target_w, target_h):
    """Load PNG via tkinter PhotoImage and subsample to fit target size."""
    photo = tk.PhotoImage(file=path)
    n = max(1, photo.width() // target_w, photo.height() // target_h)
    if n > 1:
        photo = photo.subsample(n, n)
    return photo


def main():
    a = sys.argv[1:]
    message    = a[0] if len(a) > 0 else "Hello!"
    pet_dir    = a[1] if len(a) > 1 else ""
    pet_base   = a[2] if len(a) > 2 else "cat1"
    label_path = a[3] if len(a) > 3 else ""
    disp_secs  = int(a[4]) if len(a) > 4 else 5

    if not HAS_TK:
        show_osascript(message)
        return

    MARGIN_R = 16
    MARGIN_B = 80   # room for macOS Dock
    BG       = "black"

    root = tk.Tk()
    root.overrideredirect(True)
    root.attributes("-topmost", True)
    try:
        root.wm_attributes("-transparent", True)
    except Exception:
        pass
    root.configure(bg=BG)

    # bubble label
    lbl_photo = None
    if label_path and os.path.exists(label_path):
        try:
            lbl_photo = _load_photo(root, label_path, 200, 64)
        except Exception:
            pass

    if lbl_photo:
        lbl = tk.Label(root, image=lbl_photo, text=message, compound="center",
                       font=("Helvetica", 10, "bold"), fg="black", bg=BG)
    else:
        lbl = tk.Label(root, text=message, font=("Helvetica", 10, "bold"),
                       bg="white", fg="black", relief="solid", bd=1,
                       wraplength=180)

    lbl.update_idletasks()
    BUBBLE_W = lbl_photo.width()  if lbl_photo else lbl.winfo_reqwidth()
    BUBBLE_H = lbl_photo.height() if lbl_photo else lbl.winfo_reqheight()

    # pet frames
    frames = []
    if pet_dir and os.path.isdir(pet_dir):
        for fp in sorted(glob.glob(os.path.join(pet_dir, f"{pet_base}_*.png"))):
            try:
                frames.append(_load_photo(root, fp, 100, 100))
            except Exception:
                pass

    if frames:
        pet_w = tk.Label(root, image=frames[0], bg=BG, bd=0)
        PET_W = frames[0].width()
        PET_H = frames[0].height()
    else:
        pet_w = tk.Label(root, text="\U0001f431", font=("Helvetica", 52), bg=BG, fg="black")
        pet_w.update_idletasks()
        PET_W = pet_w.winfo_reqwidth()
        PET_H = pet_w.winfo_reqheight()

    PAD   = 12
    FORM_W = max(BUBBLE_W, PET_W) + PAD * 2
    FORM_H = BUBBLE_H + PET_H + 4

    sw = root.winfo_screenwidth()
    sh = root.winfo_screenheight()
    root.geometry(f"{FORM_W}x{FORM_H}+{sw - FORM_W - MARGIN_R}+{sh - FORM_H - MARGIN_B}")

    lbl.place(x=(FORM_W - BUBBLE_W) // 2, y=0, width=BUBBLE_W, height=BUBBLE_H)
    pet_w.place(x=(FORM_W - PET_W) // 2, y=BUBBLE_H - 4, width=PET_W, height=PET_H)

    # animation
    idx = [0]
    def _animate():
        if len(frames) >= 2:
            idx[0] = (idx[0] + 1) % len(frames)
            pet_w.configure(image=frames[idx[0]])
        root.after(800, _animate)
    if len(frames) >= 2:
        root.after(800, _animate)

    for w in (root, lbl, pet_w):
        w.bind("<Button-1>", lambda e: root.destroy())

    root.after(disp_secs * 1000, root.destroy)
    root.mainloop()


if __name__ == "__main__":
    main()
