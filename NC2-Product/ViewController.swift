//
//  ViewController.swift
//  NC2-Product
//
//  Created by woo0 on 2022/08/30.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
	var trackingStateOK: Bool = false
	let sphereNode = SCNNode(geometry: SCNSphere(radius: 0.01))
	var tappedPointNodeOrigin: SCNNode?
	var tappedPointNodeDest: SCNNode?
	var lineNode = SCNNode()
	var objectNode: SCNNode!
	var distanceLabel = UILabel()
	let coachingOverlayView = UIView()
	var printDistanceTimer = Timer()
	let descriptionLabel = UILabel()
	
	var cameraPosition = [Float]()
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		sceneView = ARSCNView(frame: view.bounds)
		view.addSubview(sceneView)
		
		sceneView.scene.rootNode.addChildNode(lineNode)
		
		distanceLabel.text = ""
		distanceLabel.frame = CGRect(x: 0, y: view.bounds.maxY - 200, width: view.bounds.width, height: 200)
		view.addSubview(distanceLabel)
		distanceLabel.textColor = .red
		distanceLabel.textAlignment = .center
		distanceLabel.numberOfLines = 3
		distanceLabel.font = .systemFont(ofSize: 40, weight: .bold)
		
		descriptionLabel.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 200)
		descriptionLabel.numberOfLines = 3
		descriptionLabel.textAlignment = .center
		descriptionLabel.textColor = .white
		view.addSubview(descriptionLabel)
		
		let markLabel = UILabel(frame: CGRect(x: view.center.x, y: view.center.y, width: 30, height: 20))
		markLabel.text = "🔴"
		view.addSubview(markLabel)
		
		sceneView.delegate = self
		sceneView.showsStatistics = true
		
		let scene = SCNScene()
		
		sceneView.scene = scene
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		let worldtracking = ARWorldTrackingConfiguration()
		worldtracking.planeDetection = [.horizontal, .vertical]
		sceneView.session.run(worldtracking, options: [.removeExistingAnchors])
		sceneView.session.delegate = self
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		
		sceneView.session.pause()
	}
	
//	func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
//		if !(anchor is ARPlaneAnchor) {
//			return
//		}
//
//		let plane = OverlayPlane(anchor: anchor as! ARPlaneAnchor)
//		self.planes.append(plane)
//		node.addChildNode(plane)
//	}
//
//	func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
//		let plane = self.planes.filter { plane in
//			return plane.anchor.identifier == anchor.identifier
//		}.first
//
//		if plane == nil {
//			return
//		}
//
//		plane?.update(anchor: anchor as! ARPlaneAnchor)
//	}
	
	func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
		switch camera.trackingState {
		case .normal:
			coachingOverlayView.isHidden = true
			trackingStateOK = true
			descriptionLabel.text = "작동중"
		default:
			coachingOverlayView.isHidden = false
			trackingStateOK = false
			descriptionLabel.text = "앱이 평면을 찾지 못하고 있습니다. 기기를 움직여 주변을 파악해주세요."
		}
	}
	
	func session(_ session: ARSession, didUpdate frame: ARFrame) {
		let transform = frame.camera.transform
		cameraPosition.append(transform.columns.3.x)
		cameraPosition.append(transform.columns.3.y)
		cameraPosition.append(transform.columns.3.z)
		printDistance(x: transform.columns.3.x, y: transform.columns.3.y, z: transform.columns.3.z)
	}
	
	func printDistance(x: Float, y: Float, z: Float) {
		guard trackingStateOK == true else { return }
		let hitTestResults = sceneView.hitTest(sceneView.center, types: .estimatedHorizontalPlane)

		guard let result = hitTestResults.first else { return }
		// 수정
		let worldCoordinates = simd_float3(x: result.worldTransform.columns.3.x, y: result.worldTransform.columns.3.y, z: result.worldTransform.columns.3.z)
		
		
//		guard let cameraPosition = sceneView.pointOfView?.position else { return }
		let cameraCoordinates = simd_float3(x: x, y: y, z: z)
//		print(cameraPosition)
		let distance = distance(cameraCoordinates, worldCoordinates)
		
		distanceLabel.text = String(floor(distance*10000)/100) + "cm"
	}
	
	func printDistance(x: Float, y: Float, z: Float, result: ARHitTestResult) {
		guard trackingStateOK == true else { return }
		let worldCoordinates = simd_float3(x: result.worldTransform.columns.3.x, y: result.worldTransform.columns.3.y, z: result.worldTransform.columns.3.z)
		
		let cameraCoordinates = simd_float3(x: x, y: y, z: z)
		let distance = distance(cameraCoordinates, worldCoordinates)
		
		distanceLabel.text = String(floor(distance*10000)/100) + "cm"
	}
	
	// 물체를 인식했을 때 그 물체와의 거리를 측정하기
	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		if let touchLocation = touches.first?.location(in: view) {
			let hitTestResults = sceneView.hitTest(touchLocation, types: .featurePoint)

			if let hitResult = hitTestResults.first {
				printDistance(x: cameraPosition[0], y: cameraPosition[1], z: cameraPosition[2], result: hitResult)
			}
		}
	}
}
