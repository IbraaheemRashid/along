import SceneKit
import simd
import SwiftUI
import UIKit

// MARK: - Asset

/// Areas, camera focus and spot positions exported by tools/body-model/export_asset.py.
struct BodySiteManifest: Decodable {
    struct Area: Decodable, Identifiable {
        struct Spot: Decodable {
            let id: String
            let p: [Float]
            let n: [Float]
        }
        let id: String
        let region: BodyRegion
        let side: BodySide?
        /// Body rotation (degrees about +y) that faces this area to the camera.
        let yaw: Double
        let center: [Float]
        /// Half of the visible height, in metres, when zoomed into this area.
        let halfHeight: Double
        let spots: [Spot]
    }
    struct Zone: Decodable {
        let mesh: String
        let rim: String
        let area: String
        let color: [Double]
    }
    let version: Int
    let areas: [Area]
    let zones: [Zone]
}

enum BodyAsset {
    /// Reads `InjectionBodyMesh` (binary meshes) and `InjectionBodySites` (JSON)
    /// from the asset catalog. Returns nil if either is missing or malformed.
    static func load() -> (meshes: [String: SCNGeometry], manifest: BodySiteManifest)? {
        guard let meshData = NSDataAsset(name: "InjectionBodyMesh")?.data,
              let siteData = NSDataAsset(name: "InjectionBodySites")?.data,
              let manifest = try? JSONDecoder().decode(BodySiteManifest.self, from: siteData),
              let meshes = parseMeshes(meshData), meshes["body"] != nil else { return nil }
        return (meshes, manifest)
    }

    /// "ABM1" | u32 count | count × (u8 nameLen | name | u32 vertexCount | u32 indexCount
    /// | f32 positions[3v] | f32 normals[3v] | u32 indices[i]) — little endian.
    static func parseMeshes(_ raw: Data) -> [String: SCNGeometry]? {
        let data = Data(raw)            // zero-based indices
        var offset = 0
        func read<T: FixedWidthInteger>(_ type: T.Type) -> T? {
            let size = MemoryLayout<T>.size
            guard offset + size <= data.count else { return nil }
            let value = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: T.self) }
            offset += size
            return T(littleEndian: value)
        }
        func bytes(_ count: Int) -> Data? {
            guard count >= 0, offset + count <= data.count else { return nil }
            defer { offset += count }
            return data.subdata(in: offset..<(offset + count))
        }
        guard bytes(4) == Data("ABM1".utf8), let count = read(UInt32.self), count < 256 else { return nil }
        var meshes: [String: SCNGeometry] = [:]
        for _ in 0..<count {
            guard let nameLength = read(UInt8.self), let nameData = bytes(Int(nameLength)),
                  let vertexCount = read(UInt32.self), let indexCount = read(UInt32.self),
                  vertexCount > 0, indexCount % 3 == 0,
                  let positions = bytes(Int(vertexCount) * 12), let normals = bytes(Int(vertexCount) * 12),
                  let indices = bytes(Int(indexCount) * 4) else { return nil }
            let name = String(decoding: nameData, as: UTF8.self)
            let positionSource = SCNGeometrySource(data: positions, semantic: .vertex, vectorCount: Int(vertexCount),
                                                   usesFloatComponents: true, componentsPerVector: 3, bytesPerComponent: 4,
                                                   dataOffset: 0, dataStride: 12)
            let normalSource = SCNGeometrySource(data: normals, semantic: .normal, vectorCount: Int(vertexCount),
                                                 usesFloatComponents: true, componentsPerVector: 3, bytesPerComponent: 4,
                                                 dataOffset: 0, dataStride: 12)
            let element = SCNGeometryElement(data: indices, primitiveType: .triangles,
                                             primitiveCount: Int(indexCount) / 3, bytesPerIndex: 4)
            meshes[name] = SCNGeometry(sources: [positionSource, normalSource], elements: [element])
        }
        return offset == data.count ? meshes : nil
    }
}

// MARK: - Scene model

/// Owns the SceneKit scene for the injection-site picker: spinning, tapping
/// an area, zooming the camera to it and projecting its spots to the screen.
@MainActor
@Observable
final class BodySceneModel {
    static let fullCenter = SIMD2<Float>(0, 0.86)
    static let fullHalfHeight: Double = 0.95
    static let focusDuration: Double = 0.85

    private(set) var isAvailable = false
    private(set) var focusedArea: BodySiteManifest.Area?
    /// Spot id → point in the SceneKit view's coordinate space, for the overlay.
    private(set) var spotPoints: [String: CGPoint] = [:]
    private(set) var spotsVisible = false
    private(set) var isAnimating = false
    /// Current body rotation in radians. 0 = front.
    private(set) var yaw: Double = 0
    var reduceMotion = false

    let scene = SCNScene()
    private let bodyRoot = SCNNode()
    private let cameraNode = SCNNode()
    @ObservationIgnored private var areaNodes: [String: [SCNNode]] = [:]
    @ObservationIgnored private var meshArea: [String: String] = [:]
    @ObservationIgnored private(set) var areas: [String: BodySiteManifest.Area] = [:]
    @ObservationIgnored weak var view: SCNView?
    @ObservationIgnored private var dragStartYaw: Double?
    @ObservationIgnored private var yawBeforeFocus: Double = 0

    init() {
        buildCamera()
        buildLights()
        scene.rootNode.addChildNode(bodyRoot)
        guard let loaded = BodyAsset.load() else { return }
        let meshes = loaded.meshes, manifest = loaded.manifest
        areas = Dictionary(uniqueKeysWithValues: manifest.areas.map { ($0.id, $0) })

        let body = SCNNode(geometry: meshes["body"])
        body.name = "body"
        body.geometry?.firstMaterial = Self.skinMaterial()
        bodyRoot.addChildNode(body)

        for zone in manifest.zones {
            let color = UIColor(red: zone.color[0], green: zone.color[1], blue: zone.color[2], alpha: 1)
            for (name, material, order) in [(zone.mesh, Self.zoneMaterial(color), 10), (zone.rim, Self.rimMaterial(), 11)] {
                guard let geometry = meshes[name] else { continue }
                geometry.firstMaterial = material
                let node = SCNNode(geometry: geometry)
                node.name = name
                node.renderingOrder = order
                bodyRoot.addChildNode(node)
                areaNodes[zone.area, default: []].append(node)
                meshArea[name] = zone.area
            }
        }
        isAvailable = true
    }

    // MARK: Look

    private func buildCamera() {
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = Self.fullHalfHeight
        camera.zNear = 0.1
        camera.zFar = 10
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(Self.fullCenter.x, Self.fullCenter.y, 3)
        scene.rootNode.addChildNode(cameraNode)
    }

    private func buildLights() {
        func light(_ type: SCNLight.LightType, _ intensity: CGFloat, from position: SCNVector3?) {
            let light = SCNLight()
            light.type = type
            light.intensity = intensity
            light.color = UIColor.white
            let node = SCNNode()
            node.light = light
            if let position {
                node.position = position
                node.look(at: SCNVector3(0, 0.9, 0))
            }
            scene.rootNode.addChildNode(node)
        }
        light(.ambient, 420, from: nil)
        light(.directional, 820, from: SCNVector3(-1.3, 2.6, 2.6))   // key, upper left front
        light(.directional, 260, from: SCNVector3(1.6, 1.2, 2.0))    // fill
        light(.directional, 340, from: SCNVector3(0.0, 2.2, -2.4))   // rim from behind
    }

    private static func skinMaterial() -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .blinn
        m.diffuse.contents = UIColor(white: 0.9, alpha: 1)
        m.specular.contents = UIColor(white: 0.28, alpha: 1)
        m.shininess = 0.32
        return m
    }

    private static func zoneMaterial(_ color: UIColor) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .lambert
        m.diffuse.contents = color
        m.emission.contents = color.withAlphaComponent(0.18)
        m.transparency = 0.9
        return m
    }

    private static func rimMaterial() -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = UIColor.white
        m.transparency = 0.8
        return m
    }

    // MARK: Spin

    /// Front / Back / Left side / Right side, from the person's perspective.
    var viewLabel: String {
        var degrees = (yaw * 180 / .pi).truncatingRemainder(dividingBy: 360)
        if degrees < 0 { degrees += 360 }
        if degrees < 45 || degrees > 315 { return "Front" }
        if degrees > 135 && degrees < 225 { return "Back" }
        return degrees > 180 ? "Left side" : "Right side"
    }

    func drag(translation: CGFloat) {
        guard focusedArea == nil, !isAnimating else { return }
        if dragStartYaw == nil { dragStartYaw = yaw }
        setYaw((dragStartYaw ?? 0) + Double(translation) * 0.012)
    }

    func endDrag(velocity: CGFloat) {
        guard dragStartYaw != nil else { return }
        dragStartYaw = nil
        guard !reduceMotion else { return }
        let target = yaw + Double(velocity) * 0.012 * 0.22
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.6
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)
        bodyRoot.eulerAngles.y = Float(target)
        SCNTransaction.commit()
        yaw = target
    }

    private func setYaw(_ value: Double) {
        yaw = value
        bodyRoot.eulerAngles.y = Float(value)
    }

    // MARK: Tap

    /// The area under a tap in the SceneKit view, if any.
    func area(at point: CGPoint) -> BodySiteManifest.Area? {
        guard let view else { return nil }
        let hits = view.hitTest(point, options: [.searchMode: SCNHitTestSearchMode.all.rawValue, .ignoreHiddenNodes: true])
        guard let first = hits.first else { return nil }
        if let id = first.node.name.flatMap({ meshArea[$0] }) { return areas[id] }
        // Decals float ~1 mm above the skin; accept one just behind the first hit.
        for hit in hits.dropFirst().prefix(3) {
            let a = first.worldCoordinates, b = hit.worldCoordinates
            let distance = simd_distance(SIMD3<Float>(a.x, a.y, a.z), SIMD3<Float>(b.x, b.y, b.z))
            if distance < 0.004, let id = hit.node.name.flatMap({ meshArea[$0] }) { return areas[id] }
        }
        return nil
    }

    // MARK: Focus

    func focus(areaID: String) {
        guard let area = areas[areaID] else { return }
        focus(area)
    }

    func focus(_ area: BodySiteManifest.Area) {
        guard !isAnimating, focusedArea?.id != area.id else { return }
        if focusedArea == nil { yawBeforeFocus = yaw }
        focusedArea = area
        spotsVisible = false
        spotPoints = [:]
        let targetYaw = Self.nearestAngle(to: area.yaw * .pi / 180, from: yaw)
        let center = Self.rotate(SIMD3(area.center[0], area.center[1], area.center[2]), by: targetYaw)
        animate {
            self.bodyRoot.eulerAngles.y = Float(targetYaw)
            self.cameraNode.position = SCNVector3(center.x, center.y, 3)
            self.cameraNode.camera?.orthographicScale = area.halfHeight
            for (id, nodes) in self.areaNodes {
                nodes.forEach { $0.opacity = id == area.id ? 1 : 0.15 }
            }
        } completion: {
            self.yaw = targetYaw
            self.refreshSpotPoints()
            self.spotsVisible = true
        }
    }

    func showWholeBody() {
        guard focusedArea != nil, !isAnimating else { return }
        focusedArea = nil
        spotsVisible = false
        spotPoints = [:]
        let targetYaw = Self.nearestAngle(to: yawBeforeFocus, from: yaw)
        animate {
            self.bodyRoot.eulerAngles.y = Float(targetYaw)
            self.cameraNode.position = SCNVector3(Self.fullCenter.x, Self.fullCenter.y, 3)
            self.cameraNode.camera?.orthographicScale = Self.fullHalfHeight
            for nodes in self.areaNodes.values { nodes.forEach { $0.opacity = 1 } }
        } completion: {
            self.yaw = targetYaw
        }
    }

    private func animate(_ changes: @escaping () -> Void, completion: @escaping @MainActor () -> Void) {
        isAnimating = true
        SCNTransaction.begin()
        SCNTransaction.animationDuration = reduceMotion ? 0 : Self.focusDuration
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        SCNTransaction.completionBlock = {
            Task { @MainActor in
                self.isAnimating = false
                completion()
            }
        }
        changes()
        SCNTransaction.commit()
    }

    /// Re-projects the focused area's spots; call after the camera settles or the view resizes.
    func refreshSpotPoints() {
        guard let view, let area = focusedArea else { return }
        var points: [String: CGPoint] = [:]
        for spot in area.spots {
            let p = Self.rotate(SIMD3(spot.p[0], spot.p[1], spot.p[2]), by: yaw)
            let n = Self.rotate(SIMD3(spot.n[0], spot.n[1], spot.n[2]), by: yaw)
            guard n.z > 0.05 else { continue }      // facing away from the camera
            let projected = view.projectPoint(SCNVector3(p.x, p.y, p.z))
            points[spot.id] = CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y))
        }
        spotPoints = points
    }

    // MARK: Math

    /// SceneKit rotation about +y: x' = x cos θ + z sin θ, z' = −x sin θ + z cos θ.
    static func rotate(_ p: SIMD3<Float>, by yaw: Double) -> SIMD3<Float> {
        let c = Float(cos(yaw)), s = Float(sin(yaw))
        return SIMD3(p.x * c + p.z * s, p.y, -p.x * s + p.z * c)
    }

    /// `target` shifted by whole turns to be as close as possible to `current`.
    static func nearestAngle(to target: Double, from current: Double) -> Double {
        let turn = 2 * Double.pi
        return target + (((current - target) / turn).rounded()) * turn
    }
}

// MARK: - View

/// SceneKit view hosting the body. Drag spins it; tapping an area calls `onTapArea`.
struct BodySceneView: UIViewRepresentable {
    var model: BodySceneModel
    var background: UIColor
    var onTapArea: (BodySiteManifest.Area) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> SCNView {
        let view = LayoutAwareSCNView(frame: .zero)
        // Re-project spots once the view has its new bounds (rotation, resize);
        // SwiftUI's size change arrives before SceneKit's viewport updates.
        view.onResize = { [weak model] in model?.refreshSpotPoints() }
        view.scene = model.scene
        view.backgroundColor = background
        view.antialiasingMode = .multisampling4X
        view.allowsCameraControl = false
        view.rendersContinuously = false
        view.isPlaying = true
        view.preferredFramesPerSecond = 60
        view.isAccessibilityElement = false
        model.view = view
        view.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tap(_:))))
        view.addGestureRecognizer(UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pan(_:))))
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.parent = self
        view.backgroundColor = background
    }

    final class LayoutAwareSCNView: SCNView {
        var onResize: (() -> Void)?
        private var lastSize: CGSize = .zero

        override func layoutSubviews() {
            super.layoutSubviews()
            guard bounds.size != lastSize else { return }
            lastSize = bounds.size
            onResize?()
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        var parent: BodySceneView
        init(_ parent: BodySceneView) { self.parent = parent }

        @objc func tap(_ recognizer: UITapGestureRecognizer) {
            guard let view = recognizer.view else { return }
            if let area = parent.model.area(at: recognizer.location(in: view)) { parent.onTapArea(area) }
        }

        @objc func pan(_ recognizer: UIPanGestureRecognizer) {
            guard let view = recognizer.view else { return }
            switch recognizer.state {
            case .changed: parent.model.drag(translation: recognizer.translation(in: view).x)
            case .ended, .cancelled, .failed: parent.model.endDrag(velocity: recognizer.velocity(in: view).x)
            default: break
            }
        }
    }
}
