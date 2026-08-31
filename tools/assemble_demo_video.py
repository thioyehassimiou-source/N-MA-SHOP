import os
import subprocess
from PIL import Image, ImageDraw, ImageFont
from gtts import gTTS

FFMPEG = '/home/thioye/.local/lib/python3.12/site-packages/imageio_ffmpeg/binaries/ffmpeg-linux-x86_64-v7.0.2'
RAW_VIDEO = '/home/thioye/2026-08-27 11-51-22.mkv'
AUDIO_DIR = '/home/thioye/Téléchargements/audio_demo_nmashop'
OUTPUT_DIR = '/home/thioye/Vidéos'

os.makedirs(OUTPUT_DIR, exist_ok=True)
os.makedirs('/home/thioye/Téléchargements', exist_ok=True)
os.makedirs(AUDIO_DIR, exist_ok=True)

# 1. Générer le fichier audio de conclusion WhatsApp s'il n'existe pas encore
cta_audio_path = f"{AUDIO_DIR}/10_cta_whatsapp.mp3"
if not os.path.exists(cta_audio_path):
    print("🎙️ Génération de la voix-off pour la conclusion WhatsApp...")
    cta_text = "Merci d'avoir suivi cette présentation de N'MaShop ! Pour réserver votre licence ou démarrer dès aujourd'hui, contactez-nous directement sur WhatsApp au 624, 19, 30, 69. N'MaShop, le partenaire de réussite de votre commerce !"
    tts = gTTS(text=cta_text, lang='fr', slow=False)
    tts.save(cta_audio_path)

# 2. Générer l'image de la slide de fin WhatsApp (1280x720)
cta_image_path = "/tmp/cta_slide.png"
print("🎨 Génération du visuel de conclusion WhatsApp...")
w, h = 1280, 720
img = Image.new('RGB', (w, h), color='#0f172a')
draw = ImageDraw.Draw(img)

# Fond dégradé sombre élégant
for y in range(h):
    r = int(15 + (30 - 15) * (y / h))
    g = int(23 + (45 - 23) * (y / h))
    b = int(42 + (90 - 42) * (y / h))
    draw.line([(0, y), (w, y)], fill=(r, g, b))

try:
    font_large = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 54)
    font_sub = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 26)
    font_number = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 62)
    font_btn = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 28)
except Exception:
    font_large = font_sub = font_number = font_btn = ImageFont.load_default()

draw.text((w//2, 90), "N'MaShop", font=font_large, fill='#FFFFFF', anchor='mm')
draw.text((w//2, 150), "Logiciel de Gestion Commerciale & Caisse POS", font=font_sub, fill='#94A3B8', anchor='mm')

card_box = [w//2 - 400, 210, w//2 + 400, 560]
draw.rounded_rectangle([card_box[0]-4, card_box[1]+4, card_box[2]+4, card_box[3]+8], radius=24, fill='#020617')
draw.rounded_rectangle(card_box, radius=24, fill='#1E293B', outline='#334155', width=3)

draw.rounded_rectangle([w//2 - 270, 250, w//2 + 270, 305], radius=16, fill='#10B981')
draw.text((w//2, 277), "📱 CONTACTEZ-NOUS SUR WHATSAPP", font=font_btn, fill='#FFFFFF', anchor='mm')

draw.text((w//2, 375), "+224 624 19 30 69", font=font_number, fill='#38BDF8', anchor='mm')
draw.text((w//2, 435), "( 624 19 30 69 )", font=font_sub, fill='#F8FAFC', anchor='mm')

draw.rounded_rectangle([w//2 - 320, 480, w//2 + 320, 535], radius=12, fill='#2563EB')
draw.text((w//2, 507), "⚡ Commandez votre licence N'MaShop !", font=font_sub, fill='#FFFFFF', anchor='mm')

draw.text((w//2, 650), "N'MaShop • La solution moderne pour votre boutique", font=font_sub, fill='#64748B', anchor='mm')
img.save(cta_image_path)

# 3. Créer le segment vidéo de la slide de fin
cta_seg_path = "/tmp/seg_10_cta.mp4"
cmd_cta_video = [
    FFMPEG, '-y',
    '-loop', '1', '-i', cta_image_path,
    '-i', cta_audio_path,
    '-c:v', 'libx264', '-preset', 'fast', '-tune', 'stillimage', '-pix_fmt', 'yuv420p',
    '-c:a', 'aac', '-b:a', '192k',
    '-shortest',
    cta_seg_path
]
subprocess.run(cmd_cta_video, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

# 4. Séquences à découper de la vidéo originale
segments = [
    {"name": "01_intro", "start": 5, "duration": 7, "audio": f"{AUDIO_DIR}/01_intro.mp3"},
    {"name": "02_dashboard", "start": 65, "duration": 10, "audio": f"{AUDIO_DIR}/02_dashboard.mp3"},
    {"name": "03_stocks", "start": 140, "duration": 9, "audio": f"{AUDIO_DIR}/03_stocks.mp3"},
    {"name": "04_ventes", "start": 210, "duration": 8, "audio": f"{AUDIO_DIR}/04_ventes_caisse.mp3"},
    {"name": "05_logistique", "start": 280, "duration": 8, "audio": f"{AUDIO_DIR}/05_commandes_logistique.mp3"},
    {"name": "06_equipe", "start": 460, "duration": 8, "audio": f"{AUDIO_DIR}/06_equipe_roles.mp3"},
    {"name": "07_compta", "start": 370, "duration": 8, "audio": f"{AUDIO_DIR}/07_compta_depenses.mp3"},
    {"name": "08_licence", "start": 550, "duration": 8, "audio": f"{AUDIO_DIR}/08_licence_admin.mp3"},
    {"name": "09_conclusion", "start": 610, "duration": 6, "audio": f"{AUDIO_DIR}/09_conclusion.mp3"},
]

temp_files = []
concat_list_path = "/tmp/concat_list.txt"

print("🎬 Découpage et ré-assemblage des séquences vidéo avec conclusion CTA...")

for i, seg in enumerate(segments):
    tmp_v = f"/tmp/seg_{i:02d}.mp4"
    cmd = [
        FFMPEG, '-y',
        '-ss', str(seg["start"]),
        '-i', RAW_VIDEO,
        '-i', seg["audio"],
        '-t', str(seg["duration"]),
        '-map', '0:v:0',
        '-map', '1:a:0',
        '-c:v', 'libx264', '-preset', 'fast', '-crf', '22', '-pix_fmt', 'yuv420p',
        '-c:a', 'aac', '-b:a', '192k',
        '-shortest',
        tmp_v
    ]
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    temp_files.append(tmp_v)

# Ajouter la slide WhatsApp en conclusion
temp_files.append(cta_seg_path)

with open(concat_list_path, "w") as f:
    for tf in temp_files:
        f.write(f"file '{tf}'\n")

final_output = f"{OUTPUT_DIR}/demo_nmashop_montage_voix.mp4"
final_download = "/home/thioye/Téléchargements/demo_nmashop_montage_voix.mp4"

print("🎵 Génération du montage vidéo final avec écran WhatsApp...")
cmd_concat = [
    FFMPEG, '-y',
    '-f', 'concat', '-safe', '0',
    '-i', concat_list_path,
    '-c:v', 'libx264', '-preset', 'fast', '-crf', '20',
    '-c:a', 'aac', '-b:a', '192k',
    final_output
]
subprocess.run(cmd_concat, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
subprocess.run(["cp", final_output, final_download])

print(f"✅ Montage avec conclusion WhatsApp terminé avec succès !")
print(f"🎥 Fichier final : {final_output}")
