#!/usr/bin/env python3
"""macOS pet notification — tries AppKit (PyObjC) then tkinter then osascript."""
import sys
import os
import glob
import subprocess

# ── AppKit (PyObjC) ──────────────────────────────────────────────────────────
HAS_APPKIT = False
try:
    import objc  # noqa: F401
    from AppKit import (
        NSApplication, NSPanel, NSView, NSImageView, NSImage, NSScreen,
        NSBorderlessWindowMask, NSBackingStoreBuffered,
        NSFloatingWindowLevel, NSColor, NSTextField, NSFont,
        NSTextAlignmentCenter, NSApplicationActivationPolicyAccessory,
        NSImageScaleProportionallyUpOrDown, NSImageScaleAxesIndependently,
    )
    from Foundation import NSMakeRect, NSRunLoop, NSDate, NSDefaultRunLoopMode
    HAS_APPKIT = True

    _done = [False]

    class _ClickView(NSView):
        def mouseDown_(self, event):
            _done[0] = True

        def acceptsFirstMouse_(self, event):
            return True

except ImportError:
    pass

# ── tkinter ──────────────────────────────────────────────────────────────────
HAS_TK = False
try:
    import tkinter as tk
    HAS_TK = True
except ImportError:
    pass


# ── helpers ──────────────────────────────────────────────────────────────────
def _frontmost_app():
    try:
        r = subprocess.run(
            ["osascript", "-e",
             "tell application \"System Events\" to get name of first application process whose frontmost is true"],
            capture_output=True, text=True, check=False,
        )
        return r.stdout.strip()
    except Exception:
        return ""


def _refocus(app_name):
    if app_name:
        subprocess.Popen(
            ["osascript", "-e", f'tell application "{app_name}" to activate'],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )


def show_osascript(message):
    msg = message.replace('"', '\\"')
    subprocess.run(
        ["osascript", "-e", f'display notification "{msg}" with title "Claude Code"'],
        check=False,
    )


# ── AppKit implementation ────────────────────────────────────────────────────
def show_appkit(message, pet_dir, pet_base, label_path, disp_secs):
    import time
    _done[0] = False

    app = NSApplication.sharedApplication()
    app.setActivationPolicy_(NSApplicationActivationPolicyAccessory)
    app.finishLaunching()

    # Load cat frames
    frames = []
    if pet_dir and os.path.isdir(pet_dir):
        for fp in sorted(glob.glob(os.path.join(pet_dir, f"{pet_base}_*.png"))):
            img = NSImage.alloc().initWithContentsOfFile_(fp)
            if img:
                frames.append(img)

    # Layout
    PET_W = PET_H = 100
    BUBBLE_W, BUBBLE_H = 200, 64
    PAD = 12
    MARGIN_R = 16
    MARGIN_B = 80  # above the Dock

    form_w = max(BUBBLE_W, PET_W) + PAD * 2
    form_h = BUBBLE_H + PET_H

    sf = NSScreen.mainScreen().visibleFrame()
    x = sf.origin.x + sf.size.width - form_w - MARGIN_R
    y = sf.origin.y + MARGIN_B

    # Borderless transparent window
    panel = NSPanel.alloc().initWithContentRect_styleMask_backing_defer_(
        NSMakeRect(x, y, form_w, form_h),
        NSBorderlessWindowMask | (1 << 7),  # NSNonactivatingPanelMask: don't steal focus
        NSBackingStoreBuffered,
        False,
    )
    panel.setLevel_(NSFloatingWindowLevel)
    panel.setOpaque_(False)
    panel.setBackgroundColor_(NSColor.clearColor())

    # Click-to-close view
    hit = _ClickView.alloc().initWithFrame_(NSMakeRect(0, 0, form_w, form_h))
    panel.setContentView_(hit)

    # Bubble image
    bx = (form_w - BUBBLE_W) // 2
    by = form_h - BUBBLE_H
    if label_path and os.path.exists(label_path):
        lbl_img = NSImage.alloc().initWithContentsOfFile_(label_path)
        lv = NSImageView.alloc().initWithFrame_(NSMakeRect(bx, by, BUBBLE_W, BUBBLE_H))
        lv.setImage_(lbl_img)
        lv.setImageScaling_(NSImageScaleAxesIndependently)
        hit.addSubview_(lv)

    # Message text
    tf = NSTextField.alloc().initWithFrame_(
        NSMakeRect(bx + 10, by + 12, BUBBLE_W - 20, BUBBLE_H - 16)
    )
    tf.setStringValue_(message)
    tf.setBezeled_(False)
    tf.setDrawsBackground_(False)
    tf.setEditable_(False)
    tf.setSelectable_(False)
    tf.setAlignment_(NSTextAlignmentCenter)
    tf.setFont_(NSFont.boldSystemFontOfSize_(10))
    tf.setTextColor_(NSColor.blackColor())
    hit.addSubview_(tf)

    # Cat image view
    iv = NSImageView.alloc().initWithFrame_(
        NSMakeRect((form_w - PET_W) // 2, 0, PET_W, PET_H)
    )
    if frames:
        iv.setImage_(frames[0])
    iv.setImageScaling_(NSImageScaleProportionallyUpOrDown)
    hit.addSubview_(iv)

    panel.orderFrontRegardless()

    # Animate + auto-dismiss
    frame_idx = 0
    ANIM = 0.8
    end = time.time() + disp_secs

    while not _done[0] and time.time() < end:
        wait = min(ANIM, max(0.05, end - time.time()))
        NSRunLoop.mainRunLoop().runMode_beforeDate_(
            NSDefaultRunLoopMode,
            NSDate.dateWithTimeIntervalSinceNow_(wait),
        )
        if len(frames) >= 2 and not _done[0]:
            frame_idx = (frame_idx + 1) % len(frames)
            iv.setImage_(frames[frame_idx])

    panel.close()


# ── tkinter implementation ───────────────────────────────────────────────────
def show_tkinter(message, pet_dir, pet_base, label_path, disp_secs):
    MARGIN_R = 16
    MARGIN_B = 80
    BG = "black"

    root = tk.Tk()
    root.overrideredirect(True)
    root.attributes("-topmost", True)
    try:
        root.wm_attributes("-transparent", True)
    except Exception:
        pass
    root.configure(bg=BG)

    def _load(path, tw, th):
        p = tk.PhotoImage(file=path)
        n = max(1, p.width() // tw, p.height() // th)
        return p.subsample(n, n) if n > 1 else p

    lbl_photo = None
    if label_path and os.path.exists(label_path):
        try:
            lbl_photo = _load(label_path, 200, 64)
        except Exception:
            pass

    if lbl_photo:
        lbl = tk.Label(root, image=lbl_photo, text=message, compound="center",
                       font=("Helvetica", 10, "bold"), fg="black", bg=BG)
    else:
        lbl = tk.Label(root, text=message, font=("Helvetica", 10, "bold"),
                       bg="white", fg="black", relief="solid", bd=1, wraplength=180)
    lbl.update_idletasks()
    BW = lbl_photo.width()  if lbl_photo else lbl.winfo_reqwidth()
    BH = lbl_photo.height() if lbl_photo else lbl.winfo_reqheight()

    frames = []
    if pet_dir and os.path.isdir(pet_dir):
        for fp in sorted(glob.glob(os.path.join(pet_dir, f"{pet_base}_*.png"))):
            try:
                frames.append(_load(fp, 100, 100))
            except Exception:
                pass

    if frames:
        pet = tk.Label(root, image=frames[0], bg=BG, bd=0)
        PW = frames[0].width()
        PH = frames[0].height()
    else:
        pet = tk.Label(root, text="\U0001f431", font=("Helvetica", 52), bg=BG, fg="black")
        pet.update_idletasks()
        PW = pet.winfo_reqwidth()
        PH = pet.winfo_reqheight()

    PAD = 12
    FW = max(BW, PW) + PAD * 2
    FH = BH + PH + 4

    sw = root.winfo_screenwidth()
    sh = root.winfo_screenheight()
    root.geometry(f"{FW}x{FH}+{sw - FW - MARGIN_R}+{sh - FH - MARGIN_B}")

    lbl.place(x=(FW - BW) // 2, y=0, width=BW, height=BH)
    pet.place(x=(FW - PW) // 2, y=BH - 4, width=PW, height=PH)

    idx = [0]

    def _animate():
        if len(frames) >= 2:
            idx[0] = (idx[0] + 1) % len(frames)
            pet.configure(image=frames[idx[0]])
        root.after(800, _animate)

    if len(frames) >= 2:
        root.after(800, _animate)

    for w in (root, lbl, pet):
        w.bind("<Button-1>", lambda e: root.destroy())

    frontmost = _frontmost_app()
    if frontmost:
        root.after(50, lambda: subprocess.run(
            ["osascript", "-e", f'tell application "{frontmost}" to activate'],
            check=False,
        ))

    root.after(disp_secs * 1000, root.destroy)
    root.mainloop()


# ── main ─────────────────────────────────────────────────────────────────────
def main():
    a = sys.argv[1:]
    message    = a[0] if len(a) > 0 else "Hello!"
    pet_dir    = a[1] if len(a) > 1 else ""
    pet_base   = a[2] if len(a) > 2 else "cat1"
    label_path = a[3] if len(a) > 3 else ""
    disp_secs  = int(a[4]) if len(a) > 4 else 5

    if HAS_APPKIT:
        show_appkit(message, pet_dir, pet_base, label_path, disp_secs)
    elif HAS_TK:
        show_tkinter(message, pet_dir, pet_base, label_path, disp_secs)
    else:
        show_osascript(message)


if __name__ == "__main__":
    main()
