# ComfyUI RunPod Template

Tato šablona spouští ComfyUI na RunPod pomocí vlastního Dockerfile. Obsahuje základní prostředí pro generování obrázků a workflow.

## Port
Webové rozhraní běží na portu `8188`.

## Instalace
Použij tuto šablonu při vytváření RunPod Podu. Doporučené GPU: L40S (pro Wan 2.2 14B), minimum RTX A5000.

**Důležité:** image obsahuje torch 2.14.1 s CUDA 12.6, který potřebuje NVIDIA driver 525 a vyšší.
Při vytváření podu nastav filtr CUDA verze na 12.4 nebo vyšší (nebo ho vynech). Na starším driveru se pod zastaví s hláškou v logu.
Běží na A40, L40S, RTX 4090, A100, H100 apod. Karty Blackwell (RTX 5090, RTX PRO 6000, B200) potřebují CUDA 12.8+ a na tomhle image nepoběží.

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

