# ComfyUI RunPod Template

Tato šablona spouští ComfyUI na RunPod pomocí vlastního Dockerfile. Obsahuje základní prostředí pro generování obrázků a workflow.

## Port
Webové rozhraní běží na portu `8188`.

## Instalace
Použij tuto šablonu při vytváření RunPod Podu. Doporučené GPU: RTX A5000 nebo vyšší.

## Mounty
- `/workspace/ComfyUI/models` – modely
- `/workspace/ComfyUI/custom_nodes` – vlastní nody
- `/workspace/ComfyUI/workflows` – workflow `.json`
- `/workspace/ComfyUI/output` – výstupy

