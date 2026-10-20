import sys, numpy as np, torch, coremltools as ct
src, out = sys.argv[1], sys.argv[2]
sys.path.insert(0, src)
from blazepalm import BlazePalm
from blazehand_landmark import BlazeHandLandmark

class Palm(torch.nn.Module):
    def __init__(self):
        super().__init__()
        self.m = BlazePalm(); self.m.load_weights(f"{src}/blazepalm.pth")
        self.register_buffer("anchors", torch.tensor(np.load(f"{src}/anchors_palm.npy"), dtype=torch.float32))
    def forward(self, x):
        r, c = self.m(x)
        r = r[0]; a = self.anchors; s = 256.0
        xc = r[:, 0] / s * a[:, 2] + a[:, 0]
        yc = r[:, 1] / s * a[:, 3] + a[:, 1]
        w = r[:, 2] / s * a[:, 2]; h = r[:, 3] / s * a[:, 3]
        cols = [yc - h / 2, xc - w / 2, yc + h / 2, xc + w / 2]
        for k in range(7):
            cols.append(r[:, 4 + 2 * k] / s * a[:, 2] + a[:, 0])
            cols.append(r[:, 5 + 2 * k] / s * a[:, 3] + a[:, 1])
        cols.append(torch.sigmoid(c[0, :, 0].clamp(-100, 100)))
        return torch.stack(cols, 1)

class Landmark(torch.nn.Module):
    def __init__(self):
        super().__init__()
        self.m = BlazeHandLandmark(); self.m.load_weights(f"{src}/blazehand_landmark.pth")
    def forward(self, x):
        flag, handed, lm = self.m(x)
        return torch.cat([flag.view(1, 1), handed.view(1, 1), lm.view(1, 63)], 1)

for name, mod, outname in [("HandPalmDetector", Palm(), "detections"), ("HandLandmarker", Landmark(), "landmarks")]:
    mod.eval()
    ex = torch.rand(1, 3, 256, 256)
    traced = torch.jit.trace(mod, ex)
    ml = ct.convert(traced, inputs=[ct.ImageType(name="image", shape=ex.shape, scale=1 / 255.0, color_layout=ct.colorlayout.RGB)],
                    outputs=[ct.TensorType(name=outname)], minimum_deployment_target=ct.target.macOS14,
                    compute_precision=ct.precision.FLOAT16)
    ml.short_description = f"MediaPipe {name} (Apache-2.0), converted from zmurez/MediaPipePyTorch"
    ml.save(f"{out}/{name}.mlpackage")
    # sanity: torch vs coreml on the same random image
    img = (np.random.rand(256, 256, 3) * 255).astype(np.uint8)
    from PIL import Image
    t = torch.tensor(img).permute(2, 0, 1)[None].float() / 255
    ref = mod(t).detach().numpy()
    got = ml.predict({"image": Image.fromarray(img)})[outname]
    print(name, ref.shape, "max abs diff", float(np.abs(ref - got).max()))
