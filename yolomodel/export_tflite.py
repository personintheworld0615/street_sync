"""Export urban_multi best.pt to the TFLite file the phone runs.

The graph input is NCHW float32 [1, 3, 640, 640] in 0..1.
The output is [1, 14, 8400]: xywh normalized to the 640 canvas, then 10
class scores. The app letterboxes, thresholds, and runs NMS itself.
"""

from pathlib import Path

from ultralytics import YOLO

ROOT = Path(__file__).resolve().parents[1]
WEIGHTS = ROOT / "runs/detect/runs/urban_multi_v1/weights/best.pt"
TARGET = ROOT / "assets/models/urban_multi.tflite"


def main() -> None:
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    model = YOLO(str(WEIGHTS))
    model.model.eval()
    exported = Path(model.export(format="tflite", imgsz=640, nms=False))
    TARGET.write_bytes(exported.read_bytes())
    print(f"wrote {TARGET} ({TARGET.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
