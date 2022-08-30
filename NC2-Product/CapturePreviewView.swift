//
//  CapturePreviewView.swift
//  NC2-Product
//
//  Created by woo0 on 2022/08/30.
//

import AVFoundation
import UIKit

class CapturePreviewView : UIView {
	override class var layerClass: AnyClass{
		return AVCaptureVideoPreviewLayer.self
	}
}
