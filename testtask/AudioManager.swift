//
//  ExportManager.swift
//  testtask
//
//  Created by Leonid Kibukevich on 03.10.2022.
//

import Foundation
import AVKit

class AudioManager {
    
    private let audioEngine = AVAudioEngine()
    private let audioPlayerNode = AVAudioPlayerNode()
    
    let pitch = AVAudioUnitTimePitch()
    let reverb = AVAudioUnitReverb()
    let eqNode = AVAudioUnitEQ(numberOfBands: 2)
    
    // MARK: - Public
    
    func prepareAudioEngine(buffer: AVAudioPCMBuffer?) {
        if let buffer = buffer {
            audioEngine.connect(audioPlayerNode, to: reverb, format: buffer.format)
            audioEngine.connect(reverb, to: pitch, format: buffer.format)
            audioEngine.connect(pitch, to: eqNode, format: buffer.format)
            audioEngine.connect(eqNode, to: audioEngine.mainMixerNode, format: buffer.format)
            
            audioPlayerNode.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        }
        
        setStartState()
        audioEngine.prepare()
    }
    
    func prepareAudio(for asset: AVAsset, success: @escaping (() -> Void), failure: @escaping ((String)-> Void)) {
        let audioExport = configureAudioExportSession(with: asset)
        
        audioEngine.attach(audioPlayerNode)
        audioEngine.attach(pitch)
        audioEngine.attach(reverb)
        audioEngine.attach(eqNode)
        
        audioExport?.exportAsynchronously(completionHandler: { [weak self] in
            var playerLoopBuffer: AVAudioPCMBuffer?
            
            do {
                let audioFile = try AVAudioFile(forReading: audioExport!.outputURL!)
                let processingFormat = audioFile.processingFormat
                let fileLength = AVAudioFrameCount(audioFile.length)
                playerLoopBuffer = AVAudioPCMBuffer(pcmFormat: processingFormat, frameCapacity: fileLength)
                try audioFile.read(into: playerLoopBuffer!)
            } catch let error {
                failure(error.localizedDescription)
            }
            
            self?.prepareAudioEngine(buffer: playerLoopBuffer)
            
            do {
                try self?.audioEngine.start()
            } catch let error {
                failure(error.localizedDescription)
            }
            
            success()
        })
    }
    
    // TODO: Возможно появление рассинхрона при использовании pitch на пониженном звучании
    func playAudio(with offsetTime: UInt64) {
        audioPlayerNode.play(at: AVAudioTime(hostTime: offsetTime))
    }
    
    // MARK: - Private
    
    private func getAudioExportUrl() -> URL? {
        let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let fileName = "audioExport" + ".m4a"
        let url = path?.appendingPathComponent(fileName)
        
        if let url = url, FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        
        return url
    }
    
    private func configureAudioExportSession(with asset: AVAsset) -> AVAssetExportSession? {
        var audioExport: AVAssetExportSession?
        
        let presetNames = AVAssetExportSession.exportPresets(compatibleWith: asset)
        if presetNames.contains(AVAssetExportPresetAppleM4A) {
            audioExport = AVAssetExportSession.init(asset: asset, presetName: AVAssetExportPresetAppleM4A)
        } else {
            audioExport = AVAssetExportSession.init(asset: asset, presetName: AVAssetExportPresetPassthrough)
        }
        
        audioExport?.outputURL = getAudioExportUrl()
        audioExport?.outputFileType = AVFileType.m4a
        
        return audioExport
    }
    
    private func setStartState() {
        reverb.loadFactoryPreset(.largeHall)
        
        eqNode.bands.first?.gain = -50
        
        eqNode.bands.first?.frequency = 300
        eqNode.bands.first?.filterType = .highPass
        eqNode.bands.first?.bypass = false
        
        eqNode.bands.last?.frequency = 2000
        eqNode.bands.last?.filterType = .lowPass
        eqNode.bands.last?.bypass = false
        
        pitch.bypass = true
        eqNode.bypass = true
        reverb.wetDryMix = 0
    }
}
