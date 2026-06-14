#!/usr/bin/env python3
"""macOS pet notification — AppKit (PyObjC) or osascript fallback."""
import sys
import os
import glob
import subprocess
import time

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


def show_osascript(message):
    msg = message.replace('"', '\\"')
    subprocess.run(
        ["osascript", "-e", f'display notification "{msg}" with title "Claude Code"'],
        check=False,
    )


# ── AppKit implementation ────────────────────────────────────────────────────
def show_appkit(message, pet_dir, pet_base, label_path, disp_secs, pet_size=100):
    _done[0] = False

    app = NSApplication.sharedApplication()
    app.setActivationPolicy_(NSApplicationActivationPolicyAccessory)
    app.finishLaunching()

    frames = []
    if pet_dir and os.path.isdir(pet_dir):
        for fp in sorted(glob.glob(os.path.join(pet_dir, f"{pet_base}_*.png"))):
            img = NSImage.alloc().initWithContentsOfFile_(fp)
            if img:
                frames.append(img)

    PET_W = PET_H = pet_size
    BUBBLE_W, BUBBLE_H = 200, 64
    PAD = 12
    MARGIN_R = 16
    MARGIN_B = 80  # above the Dock

    form_w = max(BUBBLE_W, PET_W) + PAD * 2
    form_h = BUBBLE_H + PET_H

    sf = NSScreen.mainScreen().visibleFrame()
    x = sf.origin.x + sf.size.width - form_w - MARGIN_R
    y = sf.origin.y + MARGIN_B

    panel = NSPanel.alloc().initWithContentRect_styleMask_backing_defer_(
        NSMakeRect(x, y, form_w, form_h),
        NSBorderlessWindowMask | (1 << 7),  # NSNonactivatingPanelMask: don't steal focus
        NSBackingStoreBuffered,
        False,
    )
    panel.setLevel_(NSFloatingWindowLevel)
    panel.setOpaque_(False)
    panel.setBackgroundColor_(NSColor.clearColor())

    hit = _ClickView.alloc().initWithFrame_(NSMakeRect(0, 0, form_w, form_h))
    panel.setContentView_(hit)

    bx = (form_w - BUBBLE_W) // 2
    by = form_h - BUBBLE_H
    if label_path and os.path.exists(label_path):
        lbl_img = NSImage.alloc().initWithContentsOfFile_(label_path)
        lv = NSImageView.alloc().initWithFrame_(NSMakeRect(bx, by, BUBBLE_W, BUBBLE_H))
        lv.setImage_(lbl_img)
        lv.setImageScaling_(NSImageScaleAxesIndependently)
        hit.addSubview_(lv)

    tf = NSTextField.alloc().initWithFrame_(
        NSMakeRect(bx + 10, by, BUBBLE_W - 20, BUBBLE_H)
    )
    tf.setStringValue_(message)
    tf.setBezeled_(False)
    tf.setDrawsBackground_(False)
    tf.setEditable_(False)
    tf.setSelectable_(False)
    tf.setAlignment_(NSTextAlignmentCenter)
    tf.setFont_(NSFont.boldSystemFontOfSize_(10))
    tf.setTextColor_(NSColor.blackColor())
    tf.sizeToFit()
    th = tf.frame().size.height
    body_cy = by + BUBBLE_H * 0.58  # vertical center of ellipse body (above tail)
    tf.setFrame_(NSMakeRect(bx + 10, body_cy - th / 2.0, BUBBLE_W - 20, th))
    hit.addSubview_(tf)

    iv = NSImageView.alloc().initWithFrame_(
        NSMakeRect((form_w - PET_W) // 2, 0, PET_W, PET_H)
    )
    if frames:
        iv.setImage_(frames[0])
    iv.setImageScaling_(NSImageScaleProportionallyUpOrDown)
    hit.addSubview_(iv)

    panel.orderFrontRegardless()

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


# ── main ─────────────────────────────────────────────────────────────────────
def main():
    a = sys.argv[1:]
    message    = a[0] if len(a) > 0 else "Hello!"
    pet_dir    = a[1] if len(a) > 1 else ""
    pet_base   = a[2] if len(a) > 2 else "cat1"
    label_path = a[3] if len(a) > 3 else ""
    disp_secs  = int(a[4]) if len(a) > 4 else 5
    pet_size   = int(a[5]) if len(a) > 5 else 100

    if HAS_APPKIT:
        show_appkit(message, pet_dir, pet_base, label_path, disp_secs, pet_size)
    else:
        show_osascript(message)


if __name__ == "__main__":
    main()
