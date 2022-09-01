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
	
	private var detectionOverlay: CALayer! = nil
	
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
	
	let context = CIContext()
	let modelFile = YOLOv3Tiny()
	var bufferSize: CGSize = .zero
	var label = ""
	var pixelBuffer: CVBuffer?
	
	let check = UIView()
	
	override func viewDidLoad() {
		super.viewDidLoad()
		setupComponents()
		
		bufferSize.width = sceneView.frame.width
		bufferSize.height = sceneView.frame.height
		
		sceneView.delegate = self
		let scene = SCNScene()
		sceneView.scene = scene
		
		sceneView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapGesture)))
		
		Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(tapGesture), userInfo: nil, repeats: true)
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
	
	func setupComponents() {
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
		
		sceneView.addSubview(check)
	}
	
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
		cameraPosition.removeAll()
		cameraPosition.append(transform.columns.3.x)
		cameraPosition.append(transform.columns.3.y)
		cameraPosition.append(transform.columns.3.z)
		
		pixelBuffer = frame.capturedImage
	}
	
	func printDistance(x: Float, y: Float, z: Float, point: CGPoint) {
		guard trackingStateOK == true else { return }
		
		guard let query = sceneView.raycastQuery(from: point, allowing: .existingPlaneInfinite, alignment: .any) else { return }
		let results = sceneView.session.raycast(query)
		guard let position = results.first?.worldTransform else { return }
		let worldCoordinates = simd_float3(x: position.columns.3.x, y: position.columns.3.y, z: position.columns.3.z)
		let cameraCoordinates = simd_float3(x: x, y: y, z: z)
		let distanceResult = distance(cameraCoordinates, worldCoordinates)
		
		distanceLabel.text = "\(label): " + String(floor(distanceResult*10000)/100) + "cm"
		TTSManager.shared.play("\(String(floor(distanceResult*10000)/100))cm 앞에 \(label)가 있습니다.")
	}
	
	func myResultsMethod(request: VNRequest, error: Error?) {
		guard let results = request.results as? [VNRecognizedObjectObservation] else {
			fatalError("could not get results from ML Vision request.")
		}
		
		for observation in results {
			let objectObservation = observation
			let topLabelObservation = objectObservation.labels[0]
			let objectBounds = VNImageRectForNormalizedRect(objectObservation.boundingBox, Int(bufferSize.width), Int(bufferSize.height))
			label = topLabelObservation.identifier
			check.frame = CGRect(x: objectBounds.midX, y: objectBounds.midY, width: 10, height: 10)
			check.backgroundColor = .blue
			
			printDistance(x: cameraPosition[0], y: cameraPosition[1], z: cameraPosition[2], point: check.center)
		}
	}
	
	@objc func tapGesture() {
		if pixelBuffer != nil {
			guard let model = try? VNCoreMLModel(for: modelFile.model) else {
				fatalError("can't load Places ML model")
			}
			
			let handler = VNImageRequestHandler(ciImage: CIImage(cvImageBuffer: pixelBuffer!).resize(size: CGSize(width: 299, height: 299)))
			try! handler.perform( [ VNCoreMLRequest(model: model, completionHandler: myResultsMethod) ] )
		}
	}
}
