# 3D body for the injection-site picker

`body3d.py` defines a gender-neutral mannequin as a signed distance field (smooth-blended
primitives) plus the site zones. `export_asset.py` turns it into the two data assets the app
loads with `NSDataAsset`:

- `Assets.xcassets/InjectionBodyMesh.dataset/injection-body.bin`: body mesh plus one decal mesh
  (and white rim) per tappable zone. The binary layout is documented at the top of `export_asset.py`
  and parsed by `BodyAsset.parseMeshes` in `BodyScene.swift`.
- `Assets.xcassets/InjectionBodySites.dataset/injection-sites.json`: areas, camera focus (yaw and
  half-height) and exact spot positions and normals.

`preview_asset.py out.png` reads both files the way the app does and renders front, left-oblique
and back views, so you can check changes without Xcode.

```bash
pip install numpy scikit-image fast-simplification pillow
python3 tools/body-model/export_asset.py      # ~5 min
python3 tools/body-model/preview_asset.py /tmp/check.png
```

Coordinates are in metres, with y up. The body faces +z, and the person's left is +x.
Spot counts per region must match `BodyRegion.spotCount` in `InjectionSpot.swift`
(the protocol tests check that there are 52 in total).
