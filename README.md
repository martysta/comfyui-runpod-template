# ComfyUI RunPod Template

Tato šablona spouští ComfyUI na RunPod pomocí vlastního Dockerfile. Obsahuje základní prostředí pro generování obrázků a workflow.

## Port
Webové rozhraní běží na portu `8188`.

## Instalace
Použij tuto šablonu při vytváření RunPod Podu. Doporučené GPU: L40S (pro Wan 2.2 14B), minimum RTX A5000.

**Důležité:** image obsahuje torch s CUDA 13.0, který potřebuje NVIDIA driver 580 a vyšší.
Při vytváření podu nastav filtr CUDA verze na 13.0. Na starším driveru se pod zastaví s hláškou v logu.

## Složky na volume (/workspace)
- `/workspace/models` – modely (stahují se automaticky při prvním startu)
- `/workspace/input` – vstupní obrázky a audio
- `/workspace/output` – výstupy
- `/workspace/user` – nastavení a uložené workflow

## Workflow
Používej oficiální šablony z menu Templates v ComfyUI:
- **Wan 2.2 14B Image to Video** – záběry klipu
- **Wan2.1 InfiniteTalk** – lip sync (přepni režim na `single_speaker`)
- **Qwen-Image 2512** – výchozí obrázky (text → obrázek)
- **Qwen-Image-Edit 2511** – obrázky záběrů s referencí postavy

Všechny potřebné modely pro obě šablony stahuje `start.sh`.

