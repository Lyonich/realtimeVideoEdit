//
//  ViewController.swift
//  RealTimeVideoEdit
//
//  Created by Leonid Kibukevich on 02.10.2022.
//

import UIKit
import AVKit

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private let videoPickerController = UIImagePickerController()
    private let audioManager = AudioManager()
    
    private var videoPlayer: AVPlayer?
    
    @IBOutlet weak var pitchSlider: UISlider!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureVideoPickerController()
        
        showVideoPicker()
    }
    
    // MARK: - Private
    
    private func configureVideoPickerController() {
        videoPickerController.delegate = self
        videoPickerController.allowsEditing = true
        videoPickerController.sourceType = .photoLibrary
        videoPickerController.mediaTypes = [ "public.movie" ]
        videoPickerController.videoQuality = .typeHigh
    }
    
    private func showVideoPicker() {
        present(videoPickerController, animated: true)
    }
    
    private func createPlayerLayer(for player: AVPlayer?) {
        let playerLayer = AVPlayerLayer(player: videoPlayer)
        playerLayer.bounds = view.bounds
        playerLayer.position = view.center
        view.layer.insertSublayer(playerLayer, at: 0)
    }
    
    // MARK: - UIImagePickerControllerDelegate
    
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        
        guard let url = info[.mediaURL] as? URL else {
            return
        }
        
        let playerItem = AVPlayerItem(url: url)
        
        videoPlayer = AVPlayer(playerItem: playerItem)
        videoPlayer?.isMuted = true
        
        createPlayerLayer(for: videoPlayer)
        
        audioManager.prepareAudio(for: playerItem.asset) { [weak self] in
            self?.videoPlayer?.play()
            self?.audioManager.playAudio(with: UInt64((self?.videoPlayer?.currentTime().seconds) ?? 0))
        } failure: { error in
            print(error)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(restartVideo), name: .AVPlayerItemDidPlayToEndTime, object: videoPlayer?.currentItem)
    }
    
    @objc func restartVideo() {
        videoPlayer?.pause()
        videoPlayer?.currentItem?.seek(to: CMTime.zero, completionHandler: { [weak self] _ in
            self?.videoPlayer?.play()
            self?.audioManager.playAudio(with: UInt64((self?.videoPlayer?.currentTime().seconds) ?? 0))
        })
    }
    
    @IBAction func change(_ sender: UISlider) {
        if sender.value > 0.5 {
            audioManager.pitch.pitch = 1200 * Float(sender.value)
        }
        
        if sender.value < 0.5 {
            audioManager.pitch.pitch = -1200 * Float(1 - sender.value)
        }
        
        if sender.value == 0.5 {
            audioManager.pitch.pitch = 0
        }
    }
    
    @IBAction func pitchButtonAction(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        pitchSlider.isHidden = !sender.isSelected
        audioManager.pitch.bypass = !sender.isSelected
    }
    
    @IBAction func reverbButtonAction(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        
        if sender.isSelected {
            audioManager.reverb.wetDryMix = 100
        } else {
            audioManager.reverb.wetDryMix = 0
        }
    }
    
    @IBAction func eqButtonAction(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        
        audioManager.eqNode.bypass = !audioManager.eqNode.bypass
    }
}
