#!/usr/bin/env python3
"""Generate ATC Transcriber app icon for Android and iOS."""

from PIL import Image, ImageDraw
import os
import math

def create_atc_icon(size):
    """Create an ATC-themed icon with radar/radio waves design."""
    # Create image with dark blue background (aviation theme)
    img = Image.new('RGBA', (size, size), (26, 35, 126, 255))  # #1A237E
    draw = ImageDraw.Draw(img)

    center_x = size // 2
    center_y = size // 2

    # Draw radar/radio waves (concentric arcs)
    wave_color = (0, 188, 212, 255)  # Cyan #00BCD4
    wave_color_faded = (0, 188, 212, 180)
    wave_color_more_faded = (0, 188, 212, 100)

    # Calculate proportional sizes
    base_radius = size * 0.15
    wave_spacing = size * 0.12
    stroke_width = max(2, size // 48)

    # Draw three radio wave arcs (bottom-right quadrant to suggest transmission)
    for i, (radius_mult, color) in enumerate([
        (0.25, wave_color),
        (0.38, wave_color_faded),
        (0.51, wave_color_more_faded),
    ]):
        radius = int(size * radius_mult)
        bbox = [
            center_x - radius,
            center_y - radius,
            center_x + radius,
            center_y + radius,
        ]
        # Draw arc in upper-right area
        draw.arc(bbox, start=-60, end=60, fill=color, width=stroke_width)

    # Draw headset shape (simplified)
    headset_color = (255, 255, 255, 255)

    # Headband arc
    headband_radius = int(size * 0.28)
    headband_bbox = [
        center_x - headband_radius,
        center_y - int(size * 0.15) - headband_radius,
        center_x + headband_radius,
        center_y - int(size * 0.15) + headband_radius,
    ]
    draw.arc(headband_bbox, start=200, end=340, fill=headset_color, width=stroke_width * 2)

    # Left ear cup
    ear_width = int(size * 0.15)
    ear_height = int(size * 0.20)
    left_ear_x = center_x - headband_radius + int(size * 0.02)
    left_ear_y = center_y - int(size * 0.05)
    draw.rounded_rectangle(
        [left_ear_x, left_ear_y, left_ear_x + ear_width, left_ear_y + ear_height],
        radius=size // 20,
        fill=headset_color,
    )

    # Right ear cup
    right_ear_x = center_x + headband_radius - ear_width - int(size * 0.02)
    right_ear_y = center_y - int(size * 0.05)
    draw.rounded_rectangle(
        [right_ear_x, right_ear_y, right_ear_x + ear_width, right_ear_y + ear_height],
        radius=size // 20,
        fill=headset_color,
    )

    # Microphone boom (from left ear)
    mic_start_x = left_ear_x + ear_width // 2
    mic_start_y = left_ear_y + ear_height - int(size * 0.02)
    mic_end_x = center_x - int(size * 0.05)
    mic_end_y = center_y + int(size * 0.25)
    draw.line(
        [(mic_start_x, mic_start_y), (mic_end_x, mic_end_y)],
        fill=headset_color,
        width=stroke_width,
    )

    # Microphone head
    mic_radius = int(size * 0.06)
    draw.ellipse(
        [mic_end_x - mic_radius, mic_end_y - mic_radius,
         mic_end_x + mic_radius, mic_end_y + mic_radius],
        fill=wave_color,
    )

    return img


def create_adaptive_foreground(size):
    """Create foreground layer for Android adaptive icons."""
    # Adaptive icons need extra padding (safe zone is 66% of full size)
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # The actual icon should be in the center 66%
    icon_size = int(size * 0.66)
    offset = (size - icon_size) // 2

    center_x = size // 2
    center_y = size // 2

    # Draw the same design but scaled to fit safe zone
    scale = icon_size / size

    wave_color = (0, 188, 212, 255)
    wave_color_faded = (0, 188, 212, 180)
    wave_color_more_faded = (0, 188, 212, 100)
    headset_color = (255, 255, 255, 255)

    stroke_width = max(2, icon_size // 48)

    # Radio waves
    for i, (radius_mult, color) in enumerate([
        (0.25, wave_color),
        (0.38, wave_color_faded),
        (0.51, wave_color_more_faded),
    ]):
        radius = int(icon_size * radius_mult)
        bbox = [
            center_x - radius,
            center_y - radius,
            center_x + radius,
            center_y + radius,
        ]
        draw.arc(bbox, start=-60, end=60, fill=color, width=stroke_width)

    # Headband
    headband_radius = int(icon_size * 0.28)
    headband_bbox = [
        center_x - headband_radius,
        center_y - int(icon_size * 0.15) - headband_radius,
        center_x + headband_radius,
        center_y - int(icon_size * 0.15) + headband_radius,
    ]
    draw.arc(headband_bbox, start=200, end=340, fill=headset_color, width=stroke_width * 2)

    # Ear cups
    ear_width = int(icon_size * 0.15)
    ear_height = int(icon_size * 0.20)

    left_ear_x = center_x - headband_radius + int(icon_size * 0.02)
    left_ear_y = center_y - int(icon_size * 0.05)
    draw.rounded_rectangle(
        [left_ear_x, left_ear_y, left_ear_x + ear_width, left_ear_y + ear_height],
        radius=icon_size // 20,
        fill=headset_color,
    )

    right_ear_x = center_x + headband_radius - ear_width - int(icon_size * 0.02)
    right_ear_y = center_y - int(icon_size * 0.05)
    draw.rounded_rectangle(
        [right_ear_x, right_ear_y, right_ear_x + ear_width, right_ear_y + ear_height],
        radius=icon_size // 20,
        fill=headset_color,
    )

    # Mic boom
    mic_start_x = left_ear_x + ear_width // 2
    mic_start_y = left_ear_y + ear_height - int(icon_size * 0.02)
    mic_end_x = center_x - int(icon_size * 0.05)
    mic_end_y = center_y + int(icon_size * 0.25)
    draw.line(
        [(mic_start_x, mic_start_y), (mic_end_x, mic_end_y)],
        fill=headset_color,
        width=stroke_width,
    )

    mic_radius = int(icon_size * 0.06)
    draw.ellipse(
        [mic_end_x - mic_radius, mic_end_y - mic_radius,
         mic_end_x + mic_radius, mic_end_y + mic_radius],
        fill=wave_color,
    )

    return img


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_dir = os.path.dirname(script_dir)
    android_res = os.path.join(project_dir, 'android', 'app', 'src', 'main', 'res')

    # Android mipmap sizes
    android_sizes = {
        'mipmap-mdpi': 48,
        'mipmap-hdpi': 72,
        'mipmap-xhdpi': 96,
        'mipmap-xxhdpi': 144,
        'mipmap-xxxhdpi': 192,
    }

    # Generate Android icons
    for folder, size in android_sizes.items():
        folder_path = os.path.join(android_res, folder)
        os.makedirs(folder_path, exist_ok=True)

        # Legacy icon
        icon = create_atc_icon(size)
        icon.save(os.path.join(folder_path, 'ic_launcher.png'))
        print(f"Created {folder}/ic_launcher.png ({size}x{size})")

        # Round icon
        icon_round = create_atc_icon(size)
        # Create circular mask
        mask = Image.new('L', (size, size), 0)
        mask_draw = ImageDraw.Draw(mask)
        mask_draw.ellipse([0, 0, size, size], fill=255)
        icon_round.putalpha(mask)
        icon_round.save(os.path.join(folder_path, 'ic_launcher_round.png'))
        print(f"Created {folder}/ic_launcher_round.png ({size}x{size})")

    # Adaptive icon foreground (108dp for each density)
    adaptive_sizes = {
        'mipmap-mdpi': 108,
        'mipmap-hdpi': 162,
        'mipmap-xhdpi': 216,
        'mipmap-xxhdpi': 324,
        'mipmap-xxxhdpi': 432,
    }

    for folder, size in adaptive_sizes.items():
        folder_path = os.path.join(android_res, folder)
        foreground = create_adaptive_foreground(size)
        foreground.save(os.path.join(folder_path, 'ic_launcher_foreground.png'))
        print(f"Created {folder}/ic_launcher_foreground.png ({size}x{size})")

    # iOS icons
    ios_path = os.path.join(project_dir, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
    os.makedirs(ios_path, exist_ok=True)

    ios_sizes = [20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180, 1024]
    for size in ios_sizes:
        icon = create_atc_icon(size)
        # iOS doesn't support transparency, convert to RGB
        icon_rgb = Image.new('RGB', icon.size, (26, 35, 126))
        icon_rgb.paste(icon, mask=icon.split()[3])
        icon_rgb.save(os.path.join(ios_path, f'Icon-App-{size}x{size}.png'))
        print(f"Created iOS icon {size}x{size}")

    print("\nDone! Icons generated successfully.")
    print("\nNote: For Android adaptive icons, you may need to update")
    print("android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml")


if __name__ == '__main__':
    main()
