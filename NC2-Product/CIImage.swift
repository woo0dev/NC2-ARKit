//
//  CIImage.swift
//  NC2-Product
//
//  Created by woo0 on 2022/08/30.
//

import UIKit

extension CIImage {
	func resize(size: CGSize) -> CIImage {
		let scale = min(size.width,size.height) / min(self.extent.size.width, self.extent.size.height)
		
		let resizedImage = self.transformed(
			by: CGAffineTransform(
				scaleX: scale,
				y: scale))
		
		let width = resizedImage.extent.width
		let height = resizedImage.extent.height
		let xOffset = (CGFloat(width) - size.width) / 2.0
		let yOffset = (CGFloat(height) - size.height) / 2.0
		let rect = CGRect(x: xOffset,
						  y: yOffset,
						  width: size.width,
						  height: size.height)
		
		return resizedImage
			.clamped(to: rect)
			.cropped(to: CGRect(
				x: 0, y: 0,
				width: size.width,
				height: size.height))
	}
	
	func toPixelBuffer(context:CIContext, gray:Bool=false) -> CVPixelBuffer?{
		let attributes = [
			kCVPixelBufferCGImageCompatibilityKey:kCFBooleanTrue,
			kCVPixelBufferCGBitmapContextCompatibilityKey:kCFBooleanTrue
			] as CFDictionary
		
		var nullablePixelBuffer: CVPixelBuffer? = nil
		let status = CVPixelBufferCreate(kCFAllocatorDefault,
										 Int(self.extent.size.width),
										 Int(self.extent.size.height),
										 gray ? kCVPixelFormatType_OneComponent8 : kCVPixelFormatType_32ARGB,
										 attributes,
										 &nullablePixelBuffer)
		
		guard status == kCVReturnSuccess, let pixelBuffer = nullablePixelBuffer
			else { return nil }
		
		CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
		
		context.render(self,
					   to: pixelBuffer,
					   bounds: CGRect(x: 0,
									  y: 0,
									  width: self.extent.size.width,
									  height: self.extent.size.height),
					   colorSpace:gray ?
						CGColorSpaceCreateDeviceGray() :
						self.colorSpace)
		
		CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
		
		return pixelBuffer
	}
}
