from optimum.exporters.onnx import main_export

main_export(
    model_name_or_path="openai/whisper-tiny",
    output="whisper_tiny_onnx",
    task="automatic-speech-recognition",
    opset=14
)
