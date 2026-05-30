import whisper

def transcribe_words(audio_path):
    model = whisper.load_model("base")
    result = model.transcribe(audio_path, word_timestamps=True)
    words = []
    for segment in result["segments"]:
        for w in segment["words"]:
            words.append({"word": w["word"], "start": w["start"], "end": w["end"]})
    return words
