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
	@IBOutlet weak var previewView: CapturePreviewView!
	
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
	let modelFile = Inceptionv3()
	let videoCapture: VideoCapture = VideoCapture()
	
	override func viewDidLoad() {
		super.viewDidLoad()
		setupComponents()
		
		sceneView.delegate = self
		let scene = SCNScene()
		sceneView.scene = scene
		
		self.videoCapture.delegate = self
		
		if self.videoCapture.initCamera(){
			(self.previewView.layer as! AVCaptureVideoPreviewLayer).session =
			self.videoCapture.captureSession
			
			(self.previewView.layer as! AVCaptureVideoPreviewLayer).videoGravity =
			AVLayerVideoGravity.resizeAspectFill
			
			self.videoCapture.asyncStartCapturing()
		}else{
			fatalError("Fail to init Video Capture")
		}
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
		
		let markLabel = UILabel(frame: CGRect(x: view.center.x, y: view.center.y, width: 30, height: 20))
		markLabel.text = "🔴"
		view.addSubview(markLabel)
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
		let cameraCoordinates = simd_float3(x: x, y: y, z: z)
		let distance = distance(cameraCoordinates, worldCoordinates)
		
		distanceLabel.text = String(floor(distance*10000)/100) + "cm"
	}
}

extension ViewController: VideoCaptureDelegate {
	func onFrameCaptured(videoCapture: VideoCapture, pixelBuffer: CVPixelBuffer?, timestamp: CMTime){
		guard let pixelBuffer = pixelBuffer else{ return }
		
		let image = CIImage(cvImageBuffer: pixelBuffer)
		
		guard let model = try? VNCoreMLModel(for: modelFile.model) else {
			fatalError("can't load Places ML model")
		}
		
		let handler = VNImageRequestHandler(ciImage: image)
		let request = VNCoreMLRequest(model: model, completionHandler: myResultsMethod)
		try! handler.perform( [ request ] )
	}
	
	func myResultsMethod(request: VNRequest, error: Error?) {
		guard let results = request.results as? [VNClassificationObservation] else {
			fatalError("could not get results from ML Vision request.")
		}
		
		var bestPrediction = ""
		var bestConfidence: VNConfidence = 0
		
		for classification in results {
			print(classification.accessibilityPath?.bounds)
			if(classification.confidence > bestConfidence) {
				bestConfidence = classification.confidence
				bestPrediction = classification.identifier
			}
		}
		
		print("predicted: \(bestPrediction) with confidence of \(bestConfidence) out of 1")
	}
	
}
