import Foundation
import Speech
import AVFoundation

/// Voice recording + live transcription using Apple SFSpeechRecognizer
@Observable @MainActor
final class SpeechService {
    // MARK: - State

    var isRecording = false
    var transcribedText = ""
    var isAuthorized = false
    var errorMessage: String?
    var currentAudioFileName: String?

    // MARK: - Private (lazy to avoid TCC crash in previews)

    private var _speechRecognizer: SFSpeechRecognizer?
    private var speechRecognizerLoaded = false
    private var speechRecognizer: SFSpeechRecognizer? {
        if !speechRecognizerLoaded {
            _speechRecognizer = SFSpeechRecognizer()
            speechRecognizerLoaded = true
        }
        return _speechRecognizer
    }
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var _audioEngine: AVAudioEngine?
    private var audioEngine: AVAudioEngine {
        if _audioEngine == nil { _audioEngine = AVAudioEngine() }
        return _audioEngine!
    }
    private var audioRecorder: AVAudioRecorder?

    // MARK: - Permissions

    func requestPermissions() async {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        let micStatus = await AVAudioApplication.requestRecordPermission()
        isAuthorized = speechStatus == .authorized && micStatus

        if !isAuthorized {
            errorMessage = "Microphone and speech recognition permissions are required."
        }
    }

    // MARK: - Recording

    func startRecording() async {
        if !isAuthorized {
            await requestPermissions()
            guard isAuthorized else { return }
        }

        stopRecording()

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest, let speechRecognizer, speechRecognizer.isAvailable else {
                errorMessage = "Speech recognition unavailable"
                return
            }
            recognitionRequest.shouldReportPartialResults = true
            recognitionRequest.addsPunctuation = true

            // Set up audio file recording
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileName = "voice_\(Int(Date().timeIntervalSince1970)).m4a"
            let audioURL = documentsPath.appendingPathComponent(fileName)
            currentAudioFileName = fileName

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.record()

            // Tap audio input for speech recognition
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()

            isRecording = true
            transcribedText = ""

            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let result {
                        self.transcribedText = result.bestTranscription.formattedString
                    }
                    if error != nil || result?.isFinal == true {
                        self.stopRecording()
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            stopRecording()
        }
    }

    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil

        audioRecorder?.stop()
        audioRecorder = nil

        isRecording = false
    }

    // MARK: - Audio Playback Helper

    static func audioURL(for fileName: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }
}
