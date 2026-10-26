"""Monta capturas de widgets en un MP4 rotulado con su alcance real."""
from pathlib import Path
import json
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
local_tools = ROOT / '.tools/python'
if local_tools.is_dir():
    sys.path.insert(0, str(local_tools))
from PIL import Image, ImageDraw, ImageFont, ImageOps
import imageio_ffmpeg


def main():
    scenes = json.loads((ROOT / 'build/demo_portafolio/escenas.json').read_text(encoding='utf-8'))
    work = ROOT / 'build/demo_portafolio/video'
    work.mkdir(parents=True, exist_ok=True)
    output = ROOT / 'docs/demo'
    output.mkdir(parents=True, exist_ok=True)
    regular = ROOT / 'assets/fonts/Roboto-Regular.ttf'
    bold = ROOT / 'assets/fonts/Roboto-Bold.ttf'
    title_font = ImageFont.truetype(str(bold), 36)
    detail_font = ImageFont.truetype(str(regular), 24)
    label_font = ImageFont.truetype(str(bold), 22)
    manifest = []
    for index, scene in enumerate(scenes):
        canvas = Image.new('RGB', (1920, 1080), '#eeeeef')
        with Image.open(ROOT / scene['file']) as source:
            screenshot = ImageOps.contain(source.convert('RGB'), (1860, 870))
        canvas.paste(screenshot, ((1920 - screenshot.width) // 2, 15))
        draw = ImageDraw.Draw(canvas)
        draw.rectangle((0, 900, 1920, 1080), fill='#a41930')
        draw.text((45, 917), scene['title'], font=title_font, fill='white')
        draw.text((45, 970), scene['subtitle'], font=detail_font, fill='white')
        draw.text((45, 1025), 'PROTOTIPO · DATOS FICTICIOS · OCR SIMULADO · CAPTURAS DE PRUEBA', font=label_font, fill='white')
        frame_name = f'escena-{index:02}.png'
        canvas.save(work / frame_name)
        manifest.extend([f"file '{frame_name}'", f"duration {int(scene['seconds'])}"])
        if index == 2:
            canvas.save(output / 'portada.png')
    manifest.append(f"file 'escena-{len(scenes) - 1:02}.png'")
    concat = work / 'escenas.txt'
    concat.write_text('\n'.join(manifest) + '\n', encoding='utf-8')
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    video = output / 'flujo-pedidos.mp4'
    subprocess.run([ffmpeg, '-y', '-v', 'error', '-f', 'concat', '-safe', '1', '-i', str(concat), '-r', '24', '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '23', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', str(video)], check=True)
    subprocess.run([ffmpeg, '-v', 'error', '-i', str(video), '-f', 'null', '-'], check=True)
    print(f'Video generado y decodificado: {video.name}, {sum(s["seconds"] for s in scenes)} segundos, {video.stat().st_size / 1048576:.2f} MiB.')


if __name__ == '__main__':
    main()
